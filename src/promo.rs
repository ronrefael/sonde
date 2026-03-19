use serde::{Deserialize, Serialize};
use std::sync::{mpsc, OnceLock};
use std::time::Duration;

use crate::cache;

const DEFAULT_API_URL: &str = "https://promoclock.co/api/status";
const CACHE_NAME: &str = "promo_status";
const DEFAULT_TTL: u64 = 300;

/// Per-process memoization — avoids duplicate API calls when both
/// promo_badge and pacing request promo status in the same render cycle.
static PROMO_MEMO: OnceLock<Option<PromoStatus>> = OnceLock::new();

#[derive(Debug, Deserialize, Serialize, Clone, Default)]
pub struct PromoStatus {
    pub emoji: Option<String>,
    pub label: Option<String>,
    /// Off-peak flag — accepts both camelCase API and snake_case cache.
    #[serde(alias = "isOffPeak", alias = "is_offpeak")]
    pub is_offpeak: Option<bool>,
    /// ISO 8601 timestamp of next peak/off-peak transition.
    #[serde(alias = "nextChange")]
    pub next_change: Option<String>,
    /// Minutes until next transition.
    #[serde(alias = "minutesUntilChange")]
    pub minutes_until_change: Option<u64>,
    /// Limits multiplier (e.g. 2 for 2X).
    #[serde(alias = "limitsMultiplier")]
    pub limits_multiplier: Option<u32>,
}

/// Memoized per process — safe to call from multiple modules in one render.
pub fn fetch_promo(api_url: Option<&str>, ttl: Option<u64>) -> Option<PromoStatus> {
    PROMO_MEMO
        .get_or_init(|| fetch_promo_inner(api_url, ttl))
        .clone()
}

fn fetch_promo_inner(api_url: Option<&str>, ttl: Option<u64>) -> Option<PromoStatus> {
    let url = api_url.unwrap_or(DEFAULT_API_URL);
    let ttl = ttl.unwrap_or(DEFAULT_TTL);

    let cache_path = match cache::cache_path(CACHE_NAME) {
        Some(p) => p,
        None => return fetch_direct(url),
    };

    if let Some(data) = cache::read_cache::<PromoStatus>(&cache_path, false) {
        tracing::debug!("Promo status from cache");
        return Some(data);
    }

    let url_owned = url.to_string();
    let (tx, rx) = mpsc::channel();
    std::thread::spawn(move || {
        let _ = tx.send(fetch_from_api(&url_owned));
    });

    match rx.recv_timeout(Duration::from_secs(3)) {
        Ok(Ok(data)) => {
            cache::write_cache(&cache_path, &data, ttl, None);
            Some(data)
        }
        Ok(Err(e)) => {
            tracing::warn!("Promo API error: {e}");
            cache::read_cache::<PromoStatus>(&cache_path, true)
        }
        Err(_) => {
            tracing::warn!("Promo API timed out");
            cache::read_cache::<PromoStatus>(&cache_path, true)
        }
    }
}

fn fetch_direct(url: &str) -> Option<PromoStatus> {
    match fetch_from_api(url) {
        Ok(data) => Some(data),
        Err(e) => {
            tracing::warn!("Promo API error: {e}");
            None
        }
    }
}

fn fetch_from_api(url: &str) -> Result<PromoStatus, String> {
    let response = ureq::AgentBuilder::new()
        .timeout(Duration::from_secs(3))
        .build()
        .get(url)
        .call()
        .map_err(|e| format!("Promo API request failed: {e}"))?;

    response
        .into_json()
        .map_err(|e| format!("Failed to parse promo response: {e}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_promo_response() {
        let json = include_str!("../tests/fixtures/sample_promo_response.json");
        let status: PromoStatus = serde_json::from_str(json).unwrap();
        assert_eq!(status.label.as_deref(), Some("2X"));
        assert_eq!(status.is_offpeak, Some(true));
    }
}
