use serde::{Deserialize, Serialize};
use std::sync::{mpsc, OnceLock};
use std::time::Duration;

use crate::cache;
use crate::platform;

const USAGE_API_URL: &str = "https://api.anthropic.com/api/oauth/usage";
const MESSAGES_API_URL: &str = "https://api.anthropic.com/v1/messages";
const CACHE_NAME: &str = "usage_limits";
const DEFAULT_TTL: u64 = 300; // 5 min — usage API aggressively rate-limits

/// Per-process memoization — avoids duplicate API calls when multiple
/// modules (usage_limits, pacing, model_suggestion) all request usage data
/// in the same render cycle.
static USAGE_MEMO: OnceLock<Option<UsageData>> = OnceLock::new();

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

/// Memoized per process — safe to call from multiple modules in one render.
pub fn fetch_usage(ttl: Option<u64>) -> Option<UsageData> {
    USAGE_MEMO.get_or_init(|| fetch_usage_inner(ttl)).clone()
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

    // Try the dedicated usage endpoint first
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
            return Ok(data);
        }
        Err(ureq::Error::Status(429, _)) => {
            tracing::debug!("Usage endpoint returned 429, falling back to Messages API headers");
        }
        Err(e) => {
            tracing::debug!("Usage endpoint failed: {e}, trying Messages API fallback");
        }
    }

    // Fallback: send a minimal Messages API request and read rate limit headers.
    // The response headers contain the same utilization data.
    fetch_from_messages_headers(&token, &agent)
}

/// Send a minimal Messages API request to extract rate limit headers.
/// Headers like `anthropic-ratelimit-unified-5h-utilization` contain
/// the same data as the usage endpoint.
fn fetch_from_messages_headers(token: &str, agent: &ureq::Agent) -> Result<UsageData, String> {
    let body = serde_json::json!({
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": 1,
        "messages": [{"role": "user", "content": "."}]
    });

    let result = agent
        .post(MESSAGES_API_URL)
        .set("x-api-key", token)
        .set("anthropic-version", "2023-06-01")
        .set("content-type", "application/json")
        .send_string(&body.to_string());

    match result {
        Ok(resp) => {
            // Success — parse headers from 200 response
            if let Some(data) = parse_rate_limit_headers(&resp) {
                tracing::debug!("Usage data from Messages API headers (200)");
                return Ok(data);
            }
            Err("No rate limit headers in Messages API 200 response".to_string())
        }
        Err(ureq::Error::Status(_, resp)) => {
            // Error response (400, 429, etc.) — headers are still present
            if let Some(data) = parse_rate_limit_headers(&resp) {
                tracing::debug!("Usage data from Messages API headers (error response)");
                return Ok(data);
            }
            Err(format!(
                "Messages API returned {} with no rate limit headers",
                resp.status()
            ))
        }
        Err(e) => Err(format!("Messages API request failed: {e}")),
    }
}

fn parse_rate_limit_headers(resp: &ureq::Response) -> Option<UsageData> {
    // Values are 0.0-1.0 decimals — multiply by 100 for percentage
    let five_hour_util = resp
        .header("anthropic-ratelimit-unified-5h-utilization")
        .and_then(|v| v.parse::<f64>().ok())
        .map(|v| v * 100.0);
    let seven_day_util = resp
        .header("anthropic-ratelimit-unified-7d-utilization")
        .and_then(|v| v.parse::<f64>().ok())
        .map(|v| v * 100.0);

    // Reset times are epoch seconds — convert to ISO 8601
    let five_hour_reset = resp
        .header("anthropic-ratelimit-unified-5h-reset")
        .and_then(|s| s.parse::<i64>().ok())
        .and_then(|epoch| chrono::DateTime::from_timestamp(epoch, 0).map(|dt| dt.to_rfc3339()));
    let seven_day_reset = resp
        .header("anthropic-ratelimit-unified-7d-reset")
        .and_then(|s| s.parse::<i64>().ok())
        .and_then(|epoch| chrono::DateTime::from_timestamp(epoch, 0).map(|dt| dt.to_rfc3339()));

    if five_hour_util.is_none() && seven_day_util.is_none() {
        return None;
    }

    Some(UsageData {
        five_hour: Some(UsageWindow {
            utilization: five_hour_util,
            resets_at: five_hour_reset,
        }),
        seven_day: Some(UsageWindow {
            utilization: seven_day_util,
            resets_at: seven_day_reset,
        }),
        extra_usage: None,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

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
}
