use serde::{Deserialize, Serialize};
use std::sync::{mpsc, OnceLock};
use std::time::Duration;

use crate::cache;
use crate::platform;

const USAGE_API_URL: &str = "https://api.anthropic.com/api/oauth/usage";
const CACHE_NAME: &str = "usage_limits";
const DEFAULT_TTL: u64 = 60;

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

    let response = ureq::AgentBuilder::new()
        .timeout(Duration::from_secs(5))
        .build()
        .get(USAGE_API_URL)
        .set("Authorization", &format!("Bearer {token}"))
        .set("anthropic-beta", "oauth-2025-04-20")
        .call()
        .map_err(|e| format!("HTTP request failed: {e}"))?;

    let data: UsageData = response
        .into_json()
        .map_err(|e| format!("Failed to parse response: {e}"))?;

    // Token is dropped here - never stored
    Ok(data)
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
