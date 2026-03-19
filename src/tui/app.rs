use std::collections::HashMap;

use crate::cache;
use crate::config::SondeConfig;
use crate::modules::mascot;
use crate::modules::pacing::{self, PaceTier};
use crate::promo;
use crate::session_scanner::{self, ScannedSession};
use crate::usage_api;

#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct SessionInfo {
    pub model_name: Option<String>,
    pub session_cost: Option<f64>,
    pub cwd: Option<String>,
    pub session_id: Option<String>,
}

#[allow(dead_code)]
pub struct App {
    pub frame: usize,
    pub should_quit: bool,
    pub five_hour_util: Option<f64>,
    pub five_hour_reset: Option<String>,
    pub seven_day_util: Option<f64>,
    pub seven_day_reset: Option<String>,
    pub promo_active: bool,
    pub promo_label: String,
    pub model_name: Option<String>,
    pub session_cost: Option<f64>,
    pub context_pct: Option<f64>,
    pub cwd: Option<String>,
    pub usage_history: Vec<u64>,
    pub mascot_state: mascot::State,
    pub pace_tier: Option<PaceTier>,
    pub sessions: Vec<SessionInfo>,
    pub scanned_sessions: Vec<ScannedSession>,
    pub alert_tracker: HashMap<String, Vec<u8>>,
    pub cfg: SondeConfig,
}

impl App {
    pub fn new(cfg: SondeConfig) -> Self {
        Self {
            frame: 0,
            should_quit: false,
            five_hour_util: None,
            five_hour_reset: None,
            seven_day_util: None,
            seven_day_reset: None,
            promo_active: false,
            promo_label: String::new(),
            model_name: None,
            session_cost: None,
            context_pct: None,
            cwd: None,
            usage_history: Vec::new(),
            mascot_state: mascot::State::Idle,
            pace_tier: None,
            sessions: Vec::new(),
            scanned_sessions: Vec::new(),
            alert_tracker: HashMap::new(),
            cfg,
        }
    }

    pub fn tick(&mut self) {
        self.frame = self.frame.wrapping_add(1);
        self.read_session_cache();

        // 20 ticks × 250ms = 5s — balance freshness vs disk I/O
        if self.frame.is_multiple_of(20) {
            self.scanned_sessions = session_scanner::scan_sessions();
            self.check_alerts();
            self.load_usage_history();
        }
    }

    fn load_usage_history(&mut self) {
        let history = crate::history::read_history();
        self.usage_history = history
            .iter()
            .filter_map(|e| e.five_hour_util.map(|u| u.round() as u64))
            .collect();
    }

    pub fn poll(&mut self) {
        let ttl = self.cfg.usage_limits.as_ref().and_then(|c| c.ttl);
        if let Some(data) = usage_api::fetch_usage(ttl) {
            if let Some(ref w) = data.five_hour {
                self.five_hour_util = w.utilization;
                self.five_hour_reset = w.resets_at.clone();
            }
            if let Some(ref w) = data.seven_day {
                self.seven_day_util = w.utilization;
                self.seven_day_reset = w.resets_at.clone();
            }
        }

        let api_url = self
            .cfg
            .promo_badge
            .as_ref()
            .and_then(|c| c.api_url.as_deref());
        let promo_ttl = self.cfg.promo_badge.as_ref().and_then(|c| c.poll_interval);
        if let Some(status) = promo::fetch_promo(api_url, promo_ttl) {
            self.promo_active = status.is_offpeak.unwrap_or(false);
            self.promo_label = status.label.unwrap_or_default();
        }

        if let Some((tier, _)) = pacing::current_pacing(&self.cfg) {
            self.pace_tier = Some(tier);
        }

        // TUI has no stdin context — detect state from API data alone
        let ctx = crate::context::Context::default();
        self.mascot_state = mascot::detect_state(&ctx, &self.cfg);
    }

    fn check_alerts(&mut self) {
        for session in &self.scanned_sessions {
            let alerted = self.alert_tracker.entry(session.id.clone()).or_default();

            for threshold in [75u8, 90u8] {
                if session.percentage >= threshold && !alerted.contains(&threshold) {
                    alerted.push(threshold);
                    trigger_alert(&session.project_name, threshold);
                }
            }
        }
    }

    fn read_session_cache(&mut self) {
        let cache_dir = match cache::cache_dir() {
            Some(d) => d,
            None => return,
        };

        let mut sessions = Vec::new();
        let entries = match std::fs::read_dir(&cache_dir) {
            Ok(e) => e,
            Err(_) => return,
        };

        for entry in entries.flatten() {
            let name = entry.file_name();
            let name_str = name.to_string_lossy();
            if !name_str.starts_with("session_data") || !name_str.ends_with(".json") {
                continue;
            }

            let content = match std::fs::read_to_string(entry.path()) {
                Ok(c) => c,
                Err(_) => continue,
            };

            let envelope: serde_json::Value = match serde_json::from_str(&content) {
                Ok(v) => v,
                Err(_) => continue,
            };

            let data = &envelope["data"];
            if data.is_null() {
                continue;
            }

            let info = SessionInfo {
                model_name: data["model_name"].as_str().map(String::from),
                session_cost: data["session_cost"].as_f64(),
                cwd: data["cwd"].as_str().map(String::from),
                session_id: data["session_id"].as_str().map(String::from),
            };

            if sessions.is_empty() {
                self.model_name = info.model_name.clone();
                self.session_cost = info.session_cost;
                self.cwd = info.cwd.clone();
                self.context_pct = data["context_used_pct"].as_f64();
            }

            sessions.push(info);
        }

        self.sessions = sessions;
    }
}

/// Uses macOS-specific APIs (afplay, osascript, say). No-ops on other platforms.
fn trigger_alert(project_name: &str, threshold: u8) {
    #[cfg(target_os = "macos")]
    {
        let sound = if threshold >= 90 {
            "/System/Library/Sounds/Sosumi.aiff"
        } else {
            "/System/Library/Sounds/Glass.aiff"
        };
        let _ = std::process::Command::new("afplay").arg(sound).spawn();

        let message = if threshold >= 90 {
            format!("{} — Context almost full!", project_name)
        } else {
            format!("{} — Save context soon!", project_name)
        };
        let script = format!(
            r#"display notification "{}" with title "sonde" sound name "Glass""#,
            message
        );
        let _ = std::process::Command::new("osascript")
            .args(["-e", &script])
            .spawn();

        if threshold >= 90 {
            let _ = std::process::Command::new("say")
                .arg("Claude context almost full")
                .spawn();
        }
    }

    #[cfg(not(target_os = "macos"))]
    {
        let _ = (project_name, threshold);
    }
}
