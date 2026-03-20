// Detection only — cost tracking coming in a future release
use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;

/// Detect GitHub Copilot installation and show subscription tier.
/// Future: read usage from `gh api /copilot/usage` if PAT available.
fn detect_copilot() -> Option<String> {
    // Check VS Code extension directory
    if let Some(home) = dirs::home_dir() {
        let extensions = home.join(".vscode").join("extensions");
        if extensions.exists() {
            if let Ok(entries) = std::fs::read_dir(&extensions) {
                for entry in entries.flatten() {
                    let name = entry.file_name();
                    let name_str = name.to_string_lossy();
                    if name_str.starts_with("github.copilot-") {
                        return Some("Copilot".to_string());
                    }
                }
            }
        }
    }

    // Check gh CLI for copilot extension
    if let Ok(output) = std::process::Command::new("gh")
        .args(["extension", "list"])
        .output()
    {
        if output.status.success() {
            let stdout = String::from_utf8_lossy(&output.stdout);
            if stdout.contains("copilot") {
                return Some("Copilot".to_string());
            }
        }
    }

    None
}

pub fn get_latest_session_cost(_cfg: &SondeConfig) -> Option<f64> {
    // Copilot doesn't expose local usage data directly.
    // Future: use `gh api /copilot/usage` with PAT from `gh auth token`
    None
}

pub fn render(_ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    if let Some(ccfg) = cfg.copilot.as_ref() {
        if ccfg.enabled == Some(false) {
            return None;
        }
    }

    let label = detect_copilot()?;
    Some(ansi::styled(&label, Some("fg:#a9b1d6")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn returns_none_when_disabled() {
        let mut cfg = SondeConfig::default();
        cfg.copilot = Some(crate::config::CopilotConfig {
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
