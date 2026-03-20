use serde::Deserialize;
use std::collections::HashMap;
use std::path::{Path, PathBuf};

#[derive(Debug, Deserialize, Default)]
pub struct ConfigFile {
    pub sonde: Option<SondeConfig>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize, Default, Clone)]
pub struct SondeConfig {
    pub theme: Option<String>,
    pub lines: Option<Vec<String>>,

    pub model: Option<ModuleConfig>,
    pub cost: Option<ModuleConfig>,
    pub context_bar: Option<ContextBarConfig>,
    pub context_window: Option<ModuleConfig>,
    pub usage_limits: Option<UsageLimitsConfig>,
    pub promo_badge: Option<PromoBadgeConfig>,
    pub pacing: Option<PacingConfig>,
    pub codex: Option<CodexConfig>,
    pub session_clock: Option<ModuleConfig>,
    pub git_branch: Option<ModuleConfig>,
    pub active_sessions: Option<ModuleConfig>,
    pub model_suggestion: Option<ModuleConfig>,
    pub combined_spend: Option<ModuleConfig>,
    pub cursor: Option<CursorConfig>,
    pub mascot: Option<MascotConfig>,
    pub windsurf: Option<WindsurfConfig>,
    pub notifications: Option<NotificationsConfig>,
    pub accounts: Option<HashMap<String, AccountConfig>>,
    pub copilot: Option<CopilotConfig>,
    pub gemini: Option<GeminiConfig>,
    pub custom: Option<HashMap<String, CustomModuleConfig>>,

    #[serde(flatten)]
    pub extra: Option<HashMap<String, toml::Value>>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize, Default, Clone)]
pub struct ModuleConfig {
    pub enabled: Option<bool>,
    pub symbol: Option<String>,
    pub style: Option<String>,
    pub warn_threshold: Option<f64>,
    pub warn_style: Option<String>,
    pub critical_threshold: Option<f64>,
    pub critical_style: Option<String>,
    pub format: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize, Default, Clone)]
pub struct ContextBarConfig {
    pub enabled: Option<bool>,
    pub width: Option<u32>,
    pub style: Option<String>,
    pub warn_threshold: Option<f64>,
    pub warn_style: Option<String>,
    pub critical_threshold: Option<f64>,
    pub critical_style: Option<String>,
}

#[derive(Debug, Deserialize, Default, Clone)]
pub struct UsageLimitsConfig {
    pub enabled: Option<bool>,
    pub five_hour_format: Option<String>,
    pub seven_day_format: Option<String>,
    pub separator: Option<String>,
    pub warn_threshold: Option<f64>,
    pub warn_style: Option<String>,
    pub critical_threshold: Option<f64>,
    pub critical_style: Option<String>,
    pub ttl: Option<u64>,
    pub style: Option<String>,
}

#[derive(Debug, Deserialize, Default, Clone)]
pub struct PromoBadgeConfig {
    pub enabled: Option<bool>,
    pub api_url: Option<String>,
    pub poll_interval: Option<u64>,
    #[allow(dead_code)]
    pub badge_format: Option<String>,
    pub style: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize, Default, Clone)]
pub struct PacingConfig {
    pub enabled: Option<bool>,
    pub style: Option<String>,
    pub promo_aware: Option<bool>,
    pub show_prediction: Option<bool>,
}

#[derive(Debug, Deserialize, Default, Clone)]
pub struct CodexConfig {
    pub enabled: Option<bool>,
    pub sessions_dir: Option<String>,
}

#[derive(Debug, Deserialize, Default, Clone)]
pub struct CursorConfig {
    pub enabled: Option<bool>,
    pub sessions_dir: Option<String>,
}

#[derive(Debug, Deserialize, Default, Clone)]
pub struct MascotConfig {
    pub enabled: Option<bool>,
    pub frame_ms: Option<u64>,
}

#[derive(Debug, Deserialize, Default, Clone)]
pub struct WindsurfConfig {
    pub enabled: Option<bool>,
    pub sessions_dir: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize, Default, Clone)]
pub struct AccountConfig {
    pub name: Option<String>,
    pub credential_service: Option<String>,
    pub api_url: Option<String>,
}

#[derive(Debug, Deserialize, Default, Clone)]
pub struct CopilotConfig {
    pub enabled: Option<bool>,
}

#[derive(Debug, Deserialize, Default, Clone)]
pub struct GeminiConfig {
    pub enabled: Option<bool>,
}

#[derive(Debug, Deserialize, Default, Clone)]
pub struct CustomModuleConfig {
    pub enabled: Option<bool>,
    pub command: Option<String>,
    pub style: Option<String>,
}

#[derive(Debug, Deserialize, Default, Clone)]
pub struct NotificationsConfig {
    pub webhook_url: Option<String>,
    pub thresholds: Option<Vec<f64>>,
    pub rate_limit_minutes: Option<u64>,
}

pub fn default_lines() -> Vec<String> {
    vec![
        "$sonde.model $sonde.session_clock $sonde.context_bar $sonde.usage_limits $sonde.pacing"
            .to_string(),
        "$sonde.promo_badge".to_string(),
    ]
}

pub fn default_powerline_lines() -> Vec<String> {
    vec![
        "$sonde.model $sonde.session_clock $sonde.context_bar $sonde.usage_limits $sonde.pacing $sonde.agent $sonde.worktree".to_string(),
        "$sonde.promo_badge".to_string(),
    ]
}

/// Expand a leading `~` to the user's home directory.
pub fn expand_tilde(path: &str) -> PathBuf {
    if path.starts_with('~') {
        if let Some(home) = dirs::home_dir() {
            return home.join(&path[2..]);
        }
    }
    PathBuf::from(path)
}

/// Discovery order: $SONDE_CONFIG, ./sonde.toml, platform config dir,
/// ~/.config/sonde/sonde.toml, ~/.sonde.toml.
pub fn discover_config_path() -> Option<PathBuf> {
    if let Ok(path) = std::env::var("SONDE_CONFIG") {
        let p = PathBuf::from(path);
        if p.exists() {
            return Some(p);
        }
    }

    let local = PathBuf::from("sonde.toml");
    if local.exists() {
        return Some(local);
    }

    if let Some(config_dir) = dirs::config_dir() {
        let xdg = config_dir.join("sonde").join("sonde.toml");
        if xdg.exists() {
            return Some(xdg);
        }
    }

    // On macOS, dirs::config_dir() returns ~/Library/Application Support,
    // so we also check ~/.config/ for users who prefer XDG layout.
    if let Some(home) = dirs::home_dir() {
        let dotconfig = home.join(".config").join("sonde").join("sonde.toml");
        if dotconfig.exists() {
            return Some(dotconfig);
        }
    }

    if let Some(home) = dirs::home_dir() {
        let home_cfg = home.join(".sonde.toml");
        if home_cfg.exists() {
            return Some(home_cfg);
        }
    }

    None
}

pub fn load_config(path: &Path) -> SondeConfig {
    match std::fs::read_to_string(path) {
        Ok(content) => match toml::from_str::<ConfigFile>(&content) {
            Ok(file) => file.sonde.unwrap_or_default(),
            Err(e) => {
                tracing::warn!("Failed to parse config {}: {e}", path.display());
                SondeConfig::default()
            }
        },
        Err(e) => {
            tracing::warn!("Failed to read config {}: {e}", path.display());
            SondeConfig::default()
        }
    }
}

pub fn load() -> SondeConfig {
    match discover_config_path() {
        Some(path) => {
            tracing::debug!("Loading config from {}", path.display());
            load_config(&path)
        }
        None => {
            tracing::debug!("No config file found, using defaults");
            SondeConfig::default()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_default_config() {
        let toml_str = include_str!("../sonde.toml");
        let file: ConfigFile = toml::from_str(toml_str).unwrap();
        let cfg = file.sonde.unwrap();
        assert_eq!(cfg.lines.as_ref().unwrap().len(), 2);
        assert_eq!(cfg.theme.as_deref(), Some("catppuccin-mocha"));
    }

    #[test]
    fn empty_config_is_default() {
        let file: ConfigFile = toml::from_str("").unwrap();
        assert!(file.sonde.is_none());
    }
}
