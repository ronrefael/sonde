use crate::config;
use crate::context;
use crate::platform;
use crate::renderer;

use std::path::PathBuf;

fn claude_settings_path() -> Option<PathBuf> {
    dirs::home_dir().map(|h| h.join(".claude").join("settings.json"))
}

fn merge_status_line(existing: &serde_json::Value) -> serde_json::Value {
    let mut obj = match existing {
        serde_json::Value::Object(m) => m.clone(),
        _ => serde_json::Map::new(),
    };

    let status_line = serde_json::json!({
        "command": "sonde"
    });
    obj.insert("statusLine".to_string(), status_line);

    serde_json::Value::Object(obj)
}

fn backup_path(original: &std::path::Path) -> PathBuf {
    let timestamp = chrono::Local::now().format("%Y%m%d%H%M%S");
    original.with_extension(format!("json.bak.{timestamp}"))
}

pub fn run(dry_run: bool) -> Result<(), Box<dyn std::error::Error>> {
    println!("\x1b[1msonde setup\x1b[0m\n");

    // Check 1: Claude Code installed
    let claude_dir = dirs::home_dir()
        .map(|h| h.join(".claude").exists())
        .unwrap_or(false);
    let binary = std::process::Command::new("which")
        .arg("claude")
        .output()
        .ok()
        .is_some_and(|o| o.status.success());

    if claude_dir || binary {
        println!("  \x1b[32m\u{2714}\x1b[0m Claude Code detected");
    } else {
        println!("  \x1b[33m\u{26a0}\x1b[0m Claude Code not detected (install first)");
    }

    // Check 2: OAuth token (NEVER print the token)
    let has_token = platform::get_oauth_token().is_some();
    if has_token {
        println!("  \x1b[32m\u{2714}\x1b[0m OAuth token found");
    } else {
        println!("  \x1b[33m\u{26a0}\x1b[0m No OAuth token (sign in to Claude Code first)");
    }

    // Check 3: Configure settings.json
    let settings_path = match claude_settings_path() {
        Some(p) => p,
        None => {
            println!("  \x1b[31m\u{2718}\x1b[0m Cannot determine home directory");
            return Ok(());
        }
    };

    let existing = if settings_path.exists() {
        match std::fs::read_to_string(&settings_path) {
            Ok(content) => match serde_json::from_str(&content) {
                Ok(v) => v,
                Err(e) => {
                    println!(
                        "  \x1b[31m\u{2718}\x1b[0m Cannot parse {}: {e}",
                        settings_path.display()
                    );
                    return Ok(());
                }
            },
            Err(e) => {
                println!(
                    "  \x1b[31m\u{2718}\x1b[0m Cannot read {}: {e}",
                    settings_path.display()
                );
                return Ok(());
            }
        }
    } else {
        serde_json::Value::Object(serde_json::Map::new())
    };

    // Check if already configured
    if existing
        .get("statusLine")
        .and_then(|v| v.get("command"))
        .and_then(|v| v.as_str())
        == Some("sonde")
    {
        println!("  \x1b[32m\u{2714}\x1b[0m statusLine already configured");
    } else if dry_run {
        println!(
            "  \x1b[36m\u{2139}\x1b[0m Would add statusLine to {}",
            settings_path.display()
        );
    } else {
        let merged = merge_status_line(&existing);

        // Validate JSON round-trip
        let json_str = serde_json::to_string_pretty(&merged)?;
        let _: serde_json::Value = serde_json::from_str(&json_str)?;

        // Backup existing file
        if settings_path.exists() {
            let backup = backup_path(&settings_path);
            std::fs::copy(&settings_path, &backup)?;
            println!("  \x1b[36m\u{2139}\x1b[0m Backup: {}", backup.display());
        }

        // Atomic write: .tmp then rename
        if let Some(parent) = settings_path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let tmp = settings_path.with_extension("json.tmp");
        std::fs::write(&tmp, &json_str)?;
        std::fs::rename(&tmp, &settings_path)?;

        println!(
            "  \x1b[32m\u{2714}\x1b[0m statusLine configured in {}",
            settings_path.display()
        );
    }

    // Preview with mock context
    println!("\n\x1b[1mPreview:\x1b[0m");
    let mock_ctx = context::parse_str(
        r#"{"model":{"display_name":"Opus"},"cost":{"total_cost_usd":1.23},"context_window":{"used_percentage":42.0}}"#,
    );
    let cfg = config::load();
    let output = renderer::render(&mock_ctx, &cfg);
    println!("  {output}");

    println!(
        "\n\x1b[32mSetup complete!\x1b[0m Run Claude Code and sonde will appear in the statusline."
    );
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn merge_into_empty_object() {
        let empty = serde_json::json!({});
        let merged = merge_status_line(&empty);
        assert_eq!(merged["statusLine"]["command"].as_str(), Some("sonde"));
    }

    #[test]
    fn merge_preserves_existing_keys() {
        let existing = serde_json::json!({"foo": "bar"});
        let merged = merge_status_line(&existing);
        assert_eq!(merged["foo"].as_str(), Some("bar"));
        assert_eq!(merged["statusLine"]["command"].as_str(), Some("sonde"));
    }

    #[test]
    fn merge_overwrites_existing_status_line() {
        let existing = serde_json::json!({"statusLine": {"command": "old"}});
        let merged = merge_status_line(&existing);
        assert_eq!(merged["statusLine"]["command"].as_str(), Some("sonde"));
    }

    #[test]
    fn backup_filename_generation() {
        let path = PathBuf::from("/tmp/settings.json");
        let backup = backup_path(&path);
        let backup_str = backup.to_string_lossy();
        assert!(backup_str.starts_with("/tmp/settings.json.bak."));
        assert!(backup_str.len() > "/tmp/settings.json.bak.".len());
    }

    #[test]
    fn preview_renders_without_panic() {
        let ctx = context::parse_str(
            r#"{"model":{"display_name":"Opus"},"cost":{"total_cost_usd":1.23}}"#,
        );
        let cfg = config::SondeConfig::default();
        let output = renderer::render(&ctx, &cfg);
        assert!(!output.is_empty());
    }
}
