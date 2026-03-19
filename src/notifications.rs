use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

use crate::config::SondeConfig;

#[derive(Debug, Serialize, Deserialize, Default)]
struct WebhookState {
    /// Maps "threshold_key" → last epoch timestamp we fired
    last_fired: HashMap<String, u64>,
}

fn now_epoch() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

fn state_path() -> Option<PathBuf> {
    dirs::cache_dir().map(|d| d.join("sonde").join("webhook_state.json"))
}

fn load_state() -> WebhookState {
    let path = match state_path() {
        Some(p) => p,
        None => return WebhookState::default(),
    };
    let content = match std::fs::read_to_string(&path) {
        Ok(c) => c,
        Err(_) => return WebhookState::default(),
    };
    serde_json::from_str(&content).unwrap_or_default()
}

fn save_state(state: &WebhookState) {
    let path = match state_path() {
        Some(p) => p,
        None => return,
    };
    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    if let Ok(json) = serde_json::to_string(state) {
        let _ = std::fs::write(&path, json);
    }
}

fn is_rate_limited(state: &WebhookState, key: &str, rate_limit_secs: u64) -> bool {
    if let Some(&last) = state.last_fired.get(key) {
        now_epoch().saturating_sub(last) < rate_limit_secs
    } else {
        false
    }
}

/// Auto-detect webhook format from URL domain.
fn build_payload(webhook_url: &str, message: &str, level: &str) -> serde_json::Value {
    if webhook_url.contains("discord.com") || webhook_url.contains("discordapp.com") {
        // Discord webhook format
        serde_json::json!({
            "content": message,
            "embeds": [{
                "title": "sonde alert",
                "description": message,
                "color": if level == "critical" { 15158332 } else { 16750848 }
            }]
        })
    } else if webhook_url.contains("hooks.slack.com") {
        // Slack webhook format
        serde_json::json!({
            "text": message,
            "blocks": [{
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": format!("*sonde alert*\n{message}")
                }
            }]
        })
    } else {
        // Generic webhook
        serde_json::json!({
            "source": "sonde",
            "level": level,
            "message": message
        })
    }
}

/// Fire-and-forget webhook. Called after render if thresholds are crossed.
pub fn check_and_notify(cfg: &SondeConfig, five_hour_util: Option<f64>) {
    let ncfg = match cfg.notifications.as_ref() {
        Some(n) => n,
        None => return,
    };

    let webhook_url = match ncfg.webhook_url.as_deref() {
        Some(url) if !url.is_empty() => url,
        _ => return,
    };

    let util = match five_hour_util {
        Some(u) => u,
        None => return,
    };

    let rate_limit_secs = ncfg.rate_limit_minutes.unwrap_or(5) * 60;
    let thresholds = ncfg
        .thresholds
        .as_ref()
        .cloned()
        .unwrap_or_else(|| vec![80.0, 95.0]);

    let mut state = load_state();
    let url = webhook_url.to_string();

    for &threshold in &thresholds {
        if util < threshold {
            continue;
        }

        let key = format!("5h_{threshold}");
        if is_rate_limited(&state, &key, rate_limit_secs) {
            continue;
        }

        let level = if threshold >= 90.0 {
            "critical"
        } else {
            "warning"
        };
        let message = format!("5-hour usage at {util:.0}% (threshold: {threshold:.0}%)",);

        let payload = build_payload(&url, &message, level);

        state.last_fired.insert(key, now_epoch());

        // Fire-and-forget: spawn thread, 3s timeout
        // SECURITY: Never log full webhook URL (may contain tokens)
        let url_clone = url.clone();
        std::thread::spawn(move || {
            let result = ureq::AgentBuilder::new()
                .timeout(std::time::Duration::from_secs(3))
                .build()
                .post(&url_clone)
                .send_json(&payload);
            if let Err(e) = result {
                // Only log domain, not full URL (may contain tokens)
                let domain = url_clone.split('/').nth(2).unwrap_or("unknown");
                tracing::debug!("Webhook to {domain} failed: {e}");
            }
        });
    }

    save_state(&state);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rate_limiter_blocks_duplicates() {
        let mut state = WebhookState::default();
        let key = "5h_80";
        assert!(!is_rate_limited(&state, key, 300));

        state.last_fired.insert(key.to_string(), now_epoch());
        assert!(is_rate_limited(&state, key, 300));
    }

    #[test]
    fn rate_limiter_allows_after_expiry() {
        let mut state = WebhookState::default();
        let key = "5h_80";
        state.last_fired.insert(key.to_string(), now_epoch() - 400);
        assert!(!is_rate_limited(&state, key, 300));
    }

    #[test]
    fn slack_payload_format() {
        let payload = build_payload("https://hooks.slack.com/services/abc", "test", "warning");
        assert!(payload["text"].as_str().is_some());
        assert!(payload["blocks"].is_array());
    }

    #[test]
    fn discord_payload_format() {
        let payload = build_payload(
            "https://discord.com/api/webhooks/123/abc",
            "test",
            "critical",
        );
        assert!(payload["content"].as_str().is_some());
        assert!(payload["embeds"].is_array());
    }

    #[test]
    fn generic_payload_format() {
        let payload = build_payload("https://example.com/webhook", "test", "warning");
        assert_eq!(payload["source"].as_str(), Some("sonde"));
        assert_eq!(payload["level"].as_str(), Some("warning"));
    }
}
