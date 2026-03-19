use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;

/// Detect Google Gemini Code Assist installation.
/// Checks VS Code extensions and gcloud config.
fn detect_gemini() -> Option<String> {
    // Check VS Code extension directory
    if let Some(home) = dirs::home_dir() {
        let extensions = home.join(".vscode").join("extensions");
        if extensions.exists() {
            if let Ok(entries) = std::fs::read_dir(&extensions) {
                for entry in entries.flatten() {
                    let name = entry.file_name();
                    let name_str = name.to_string_lossy();
                    if name_str.contains("google") && name_str.contains("gemini") {
                        return Some("Gemini".to_string());
                    }
                    if name_str.contains("google") && name_str.contains("cloud-code") {
                        return Some("Gemini".to_string());
                    }
                }
            }
        }
    }

    // Check gcloud config for gemini-related settings
    if let Some(home) = dirs::home_dir() {
        let gcloud = home.join(".config").join("gcloud");
        if gcloud.exists() {
            return None; // gcloud exists but we can't reliably detect Gemini usage
        }
    }

    None
}

pub fn get_latest_session_cost(_cfg: &SondeConfig) -> Option<f64> {
    // Gemini Code Assist doesn't expose local usage data.
    // Future: integrate with Google Cloud billing API
    None
}

pub fn render(_ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    if let Some(gcfg) = cfg.gemini.as_ref() {
        if gcfg.enabled == Some(false) {
            return None;
        }
    }

    let label = detect_gemini()?;
    Some(ansi::styled(&label, Some("fg:#a9b1d6")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn returns_none_when_disabled() {
        let mut cfg = SondeConfig::default();
        cfg.gemini = Some(crate::config::GeminiConfig {
            enabled: Some(false),
        });
        let ctx = Context::default();
        assert!(render(&ctx, &cfg).is_none());
    }

    #[test]
    fn get_cost_returns_none() {
        let cfg = SondeConfig::default();
        assert!(get_latest_session_cost(&cfg).is_none());
    }
}
