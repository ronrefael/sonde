use serde::Deserialize;
use std::collections::HashMap;
use std::path::{Path, PathBuf};

/// Top-level TOML config file structure.
#[derive(Debug, Deserialize, Default)]
pub struct ConfigFile {
    pub sonde: Option<SondeConfig>,
}

/// The [sonde] section.
#[allow(dead_code)]
#[derive(Debug, Deserialize, Default, Clone)]
pub struct SondeConfig {
    pub lines: Option<Vec<String>>,

    #[serde(rename = "model")]
    pub model: Option<ModuleConfig>,
    #[serde(rename = "cost")]
    pub cost: Option<ModuleConfig>,
    #[serde(rename = "context_bar")]
    pub context_bar: Option<ContextBarConfig>,
    #[serde(rename = "context_window")]
    pub context_window: Option<ModuleConfig>,
    #[serde(rename = "usage_limits")]
    pub usage_limits: Option<UsageLimitsConfig>,
    #[serde(rename = "promo_badge")]
    pub promo_badge: Option<PromoBadgeConfig>,
    #[serde(rename = "pacing")]
    pub pacing: Option<PacingConfig>,
    #[serde(rename = "codex")]
    pub codex: Option<CodexConfig>,
    #[serde(rename = "session_clock")]
    pub session_clock: Option<ModuleConfig>,
    #[serde(rename = "git_branch")]
    pub git_branch: Option<ModuleConfig>,
    #[serde(rename = "active_sessions")]
    pub active_sessions: Option<ModuleConfig>,
    #[serde(rename = "model_suggestion")]
    pub model_suggestion: Option<ModuleConfig>,
    #[serde(rename = "combined_spend")]
    pub combined_spend: Option<ModuleConfig>,

    /// Catch-all for unknown module configs.
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
    pub badge_format: Option<String>,
    pub style: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize, Default, Clone)]
pub struct PacingConfig {
    pub enabled: Option<bool>,
    pub style: Option<String>,
    pub promo_aware: Option<bool>,
}

#[derive(Debug, Deserialize, Default, Clone)]
pub struct CodexConfig {
    pub enabled: Option<bool>,
    pub sessions_dir: Option<String>,
}

/// Default lines if none configured.
pub fn default_lines() -> Vec<String> {
    vec![
        "$sonde.model $sonde.cost $sonde.context_bar $sonde.usage_limits".to_string(),
        "$sonde.promo_badge $sonde.pacing".to_string(),
    ]
}

/// Discovery order for config files:
/// 1. $SONDE_CONFIG env var
/// 2. ./sonde.toml (project-local)
/// 3. ~/.config/sonde/sonde.toml (XDG)
/// 4. ~/.sonde.toml (home fallback)
pub fn discover_config_path() -> Option<PathBuf> {
    // 1. Environment variable
    if let Ok(path) = std::env::var("SONDE_CONFIG") {
        let p = PathBuf::from(path);
        if p.exists() {
            return Some(p);
        }
    }

    // 2. Project-local
    let local = PathBuf::from("sonde.toml");
    if local.exists() {
        return Some(local);
    }

    // 3. XDG config
    if let Some(config_dir) = dirs::config_dir() {
        let xdg = config_dir.join("sonde").join("sonde.toml");
        if xdg.exists() {
            return Some(xdg);
        }
    }

    // 4. Home fallback
    if let Some(home) = dirs::home_dir() {
        let home_cfg = home.join(".sonde.toml");
        if home_cfg.exists() {
            return Some(home_cfg);
        }
    }

    None
}

/// Load config from a path. Returns default on any error.
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

/// Discover and load config. Returns default if no config file found.
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
        assert_eq!(cfg.context_bar.as_ref().unwrap().width, Some(10));
    }

    #[test]
    fn empty_config_is_default() {
        let file: ConfigFile = toml::from_str("").unwrap();
        assert!(file.sonde.is_none());
    }
}
