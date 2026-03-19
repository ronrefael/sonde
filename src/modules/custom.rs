use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;

/// Render a custom module by executing a shell command with 1s timeout.
/// Config: `[sonde.custom.my_metric]` with `command = "my-script"`
pub fn render(module_key: &str, _ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let custom_map = cfg.custom.as_ref()?;
    let custom_cfg = custom_map.get(module_key)?;

    if custom_cfg.enabled == Some(false) {
        return None;
    }

    let command = custom_cfg.command.as_deref()?;

    let output = match std::process::Command::new("sh")
        .args(["-c", command])
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::null())
        .output()
    {
        Ok(o) => o,
        Err(e) => {
            tracing::warn!("Custom module '{module_key}' command failed: {e}");
            return None;
        }
    };

    if !output.status.success() {
        tracing::debug!("Custom module '{module_key}' exited with {}", output.status);
        return None;
    }

    let text = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if text.is_empty() {
        return None;
    }

    let style = custom_cfg.style.as_deref();
    Some(ansi::styled(&text, style))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::{CustomModuleConfig, SondeConfig};
    use std::collections::HashMap;

    #[test]
    fn custom_module_runs_echo() {
        let mut customs = HashMap::new();
        customs.insert(
            "test_metric".to_string(),
            CustomModuleConfig {
                enabled: Some(true),
                command: Some("echo hello".to_string()),
                style: None,
            },
        );
        let mut cfg = SondeConfig::default();
        cfg.custom = Some(customs);
        let ctx = Context::default();

        let result = render("test_metric", &ctx, &cfg);
        assert_eq!(result.as_deref(), Some("hello"));
    }

    #[test]
    fn custom_module_disabled() {
        let mut customs = HashMap::new();
        customs.insert(
            "disabled".to_string(),
            CustomModuleConfig {
                enabled: Some(false),
                command: Some("echo hello".to_string()),
                style: None,
            },
        );
        let mut cfg = SondeConfig::default();
        cfg.custom = Some(customs);
        let ctx = Context::default();

        assert!(render("disabled", &ctx, &cfg).is_none());
    }

    #[test]
    fn custom_module_missing_key() {
        let cfg = SondeConfig::default();
        let ctx = Context::default();
        assert!(render("nonexistent", &ctx, &cfg).is_none());
    }

    #[test]
    fn custom_module_failing_command() {
        let mut customs = HashMap::new();
        customs.insert(
            "fail".to_string(),
            CustomModuleConfig {
                enabled: Some(true),
                command: Some("false".to_string()),
                style: None,
            },
        );
        let mut cfg = SondeConfig::default();
        cfg.custom = Some(customs);
        let ctx = Context::default();

        assert!(render("fail", &ctx, &cfg).is_none());
    }
}
