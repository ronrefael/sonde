use serde::{Deserialize, Serialize};
use std::sync::mpsc;
use std::time::Duration;

use crate::cache;
use crate::platform;

const USAGE_API_URL: &str = "https://api.anthropic.com/api/oauth/usage";
const CACHE_NAME: &str = "usage_limits";
const DEFAULT_TTL: u64 = 300; // 5 min — usage API aggressively rate-limits

// SAFETY: Sonde must never spend the user's tokens to read rate-limit data.
// The previous Messages-API "ping" fallback (POST /v1/messages with a 1-token
// Haiku prompt) was removed. When the dedicated OAuth usage endpoint is
// unavailable (429, network, or absent), prefer Claude Code's stdin
// `rate_limits` field (see `Context::rate_limits`) or return stale cache.
// Never send a billed request to discover usage.

#[derive(Debug, Deserialize, Serialize, Clone, Default)]
pub struct UsageData {
    pub five_hour: Option<UsageWindow>,
    pub seven_day: Option<UsageWindow>,
    pub extra_usage: Option<ExtraUsage>,
}

#[derive(Debug, Deserialize, Serialize, Clone, Default)]
pub struct UsageWindow {
    pub utilization: Option<f64>,
    pub resets_at: Option<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone, Default)]
pub struct ExtraUsage {
    pub is_enabled: Option<bool>,
    pub monthly_limit: Option<f64>,
    pub used_credits: Option<f64>,
    pub utilization: Option<f64>,
}

/// Fetch usage data.
///
/// Statusline renders re-exec the binary every cycle, so process-local
/// memoization (previously a dead `OnceLock`) is meaningless. The on-disk
/// cache at `~/Library/Caches/sonde/usage_limits.json` is the deduplication
/// mechanism, and it is keyed to the 5h window reset to prevent staleness
/// across resets.
pub fn fetch_usage(ttl: Option<u64>) -> Option<UsageData> {
    fetch_usage_inner(ttl)
}

/// Preferred entry point for modules: takes a `Context` and a TTL, returns
/// usage data from stdin `rate_limits` when present, else falls back to the
/// (cached) OAuth endpoint. Never bills the user.
pub fn fetch_for(ctx: &crate::context::Context, ttl: Option<u64>) -> Option<UsageData> {
    if let Some(rl) = ctx.rate_limits.as_ref() {
        return Some(from_stdin_rate_limits(rl));
    }
    fetch_usage(ttl)
}

/// Build a `UsageData` from a Claude Code statusline stdin `rate_limits`
/// field. Lets the statusline use the harness-provided values (free, no
/// HTTP call) instead of polling Anthropic's OAuth endpoint.
pub fn from_stdin_rate_limits(rl: &crate::context::RateLimits) -> UsageData {
    let pct = |w: &Option<crate::context::RateLimitWindow>| -> Option<f64> {
        w.as_ref().and_then(|w| w.used_percentage)
    };
    let reset = |w: &Option<crate::context::RateLimitWindow>| -> Option<String> {
        w.as_ref()
            .and_then(|w| w.resets_at)
            .and_then(|epoch| chrono::DateTime::from_timestamp(epoch, 0).map(|dt| dt.to_rfc3339()))
    };
    UsageData {
        five_hour: Some(UsageWindow {
            utilization: pct(&rl.five_hour),
            resets_at: reset(&rl.five_hour),
        }),
        seven_day: Some(UsageWindow {
            utilization: pct(&rl.seven_day),
            resets_at: reset(&rl.seven_day),
        }),
        extra_usage: None,
    }
}

fn fetch_usage_inner(ttl: Option<u64>) -> Option<UsageData> {
    let ttl = ttl.unwrap_or(DEFAULT_TTL);
    let cache_path = match cache::cache_path(CACHE_NAME) {
        Some(p) => p,
        None => {
            tracing::debug!("Cannot determine cache path");
            return fetch_api_direct();
        }
    };

    if let Some(data) = cache::read_cache::<UsageData>(&cache_path, false) {
        tracing::debug!("Usage data from cache (fresh)");
        return Some(data);
    }

    let (tx, rx) = mpsc::channel();
    std::thread::spawn(move || {
        let result = fetch_from_api();
        let _ = tx.send(result);
    });

    match rx.recv_timeout(Duration::from_secs(5)) {
        Ok(Ok(data)) => {
            let resets_at_epoch = data
                .five_hour
                .as_ref()
                .and_then(|w| w.resets_at.as_ref())
                .and_then(|s| chrono::DateTime::parse_from_rfc3339(s).ok())
                .map(|dt| dt.timestamp() as u64);

            cache::write_cache(&cache_path, &data, ttl, resets_at_epoch);
            Some(data)
        }
        Ok(Err(e)) => {
            tracing::warn!("Usage API error: {e}");
            cache::read_cache::<UsageData>(&cache_path, true)
        }
        Err(_) => {
            tracing::warn!("Usage API timed out");
            cache::read_cache::<UsageData>(&cache_path, true)
        }
    }
}

fn fetch_api_direct() -> Option<UsageData> {
    match fetch_from_api() {
        Ok(data) => Some(data),
        Err(e) => {
            tracing::warn!("Usage API error (no cache): {e}");
            None
        }
    }
}

fn fetch_from_api() -> Result<UsageData, String> {
    let token = platform::get_oauth_token().ok_or("No OAuth token available")?;

    let agent = ureq::AgentBuilder::new()
        .timeout(Duration::from_secs(5))
        .build();

    // Only the dedicated OAuth usage endpoint is allowed. It does not consume
    // tokens. If it fails (429, network, missing scopes) we must not fall back
    // to anything that bills the user — return an error so the caller serves
    // stale cache or omits the segment.
    match agent
        .get(USAGE_API_URL)
        .set("Authorization", &format!("Bearer {token}"))
        .set("anthropic-beta", "oauth-2025-04-20")
        .call()
    {
        Ok(response) => {
            let data: UsageData = response
                .into_json()
                .map_err(|e| format!("Failed to parse usage response: {e}"))?;
            tracing::debug!("Usage data from dedicated endpoint");
            Ok(data)
        }
        Err(ureq::Error::Status(429, _)) => {
            Err("Usage endpoint rate-limited (429); using stdin or cached data".into())
        }
        Err(e) => Err(format!("Usage endpoint failed: {e}")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context;

    #[test]
    fn parse_usage_response() {
        let json = include_str!("../tests/fixtures/sample_usage_api_response.json");
        let data: UsageData = serde_json::from_str(json).unwrap();
        assert!(
            (data.five_hour.as_ref().unwrap().utilization.unwrap() - 42.0).abs() < f64::EPSILON
        );
        assert!(
            (data.seven_day.as_ref().unwrap().utilization.unwrap() - 67.0).abs() < f64::EPSILON
        );
        assert!(data.extra_usage.as_ref().unwrap().is_enabled.unwrap());
    }

    #[test]
    fn from_stdin_rate_limits_maps_fields() {
        let rl = context::RateLimits {
            five_hour: Some(context::RateLimitWindow {
                used_percentage: Some(42.0),
                resets_at: Some(1717000000),
            }),
            seven_day: Some(context::RateLimitWindow {
                used_percentage: Some(7.5),
                resets_at: None,
            }),
        };
        let data = from_stdin_rate_limits(&rl);
        assert_eq!(data.five_hour.as_ref().unwrap().utilization, Some(42.0));
        assert!(data
            .five_hour
            .as_ref()
            .unwrap()
            .resets_at
            .as_deref()
            .map(|s| s.contains('T'))
            .unwrap_or(false));
        assert_eq!(data.seven_day.as_ref().unwrap().utilization, Some(7.5));
        assert!(data.seven_day.as_ref().unwrap().resets_at.is_none());
    }

    #[test]
    fn fetch_for_prefers_stdin_over_api() {
        // If ctx has rate_limits, fetch_for must return that data without
        // touching the network or filesystem.
        let ctx = context::Context {
            rate_limits: Some(context::RateLimits {
                five_hour: Some(context::RateLimitWindow {
                    used_percentage: Some(33.3),
                    resets_at: Some(1717000000),
                }),
                seven_day: None,
            }),
            ..Default::default()
        };
        let data = fetch_for(&ctx, Some(60)).expect("stdin path returned data");
        assert_eq!(data.five_hour.unwrap().utilization, Some(33.3));
    }

    /// SAFETY guard. The previous Messages-API "ping" fallback was a billed
    /// POST to read rate-limit headers. This test fails if any future change
    /// re-introduces such a path.
    ///
    /// We look for the exact production patterns (a `POST` to a `messages`
    /// path, or a constant named like the old URL) without false-matching the
    /// test's own assertion strings.
    #[test]
    fn no_billed_messages_api_calls_in_source() {
        let src = include_str!("usage_api.rs");
        // Strip line comments and the test module so we only scan production code.
        let mut prod = String::new();
        let mut in_tests = false;
        for line in src.lines() {
            if line.trim_start().starts_with("#[cfg(test)]") {
                in_tests = true;
            }
            if in_tests {
                continue;
            }
            // Drop // comments so the SAFETY note doesn't trip the guard.
            let no_comment = line.split("//").next().unwrap_or("");
            prod.push_str(no_comment);
            prod.push('\n');
        }
        // Concatenated to avoid the assertion text being grepped by the test.
        let messages_path = concat!("/v1/", "messages");
        assert!(
            !prod.contains(messages_path),
            "production code must not reference the Anthropic Messages endpoint to read rate limits"
        );
        let url_const = concat!("MESSAGES", "_API_URL");
        assert!(
            !prod.contains(url_const),
            "production code must not define a Messages API URL constant"
        );
    }
}
