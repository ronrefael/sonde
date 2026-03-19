use crate::cache;
use crate::config;
use crate::platform;

struct Check {
    name: &'static str,
    passed: bool,
    detail: String,
}

fn check_claude_installed() -> Check {
    let binary = std::process::Command::new("which")
        .arg("claude")
        .output()
        .ok()
        .is_some_and(|o| o.status.success());

    let claude_dir = dirs::home_dir()
        .map(|h| h.join(".claude").exists())
        .unwrap_or(false);

    let passed = binary || claude_dir;
    let detail = if passed {
        format!(
            "binary: {}, ~/.claude: {}",
            if binary { "found" } else { "not found" },
            if claude_dir { "exists" } else { "missing" }
        )
    } else {
        "Claude Code not detected. Install from https://claude.ai/download".to_string()
    };

    Check {
        name: "Claude Code installed",
        passed,
        detail,
    }
}

fn check_oauth_token() -> Check {
    // SECURITY: Never print the token value
    let has_token = platform::get_oauth_token().is_some();
    Check {
        name: "OAuth token available",
        passed: has_token,
        detail: if has_token {
            "Token found in credential store".to_string()
        } else {
            "No token found. Sign in to Claude Code first".to_string()
        },
    }
}

fn check_usage_api() -> Check {
    let (tx, rx) = std::sync::mpsc::channel();
    std::thread::spawn(move || {
        let result = ureq::AgentBuilder::new()
            .timeout(std::time::Duration::from_secs(3))
            .build()
            .get("https://api.anthropic.com/api/oauth/usage")
            .call();
        let _ = tx
            .send(result.is_ok() || result.is_err_and(|e| !matches!(e, ureq::Error::Transport(_))));
    });
    let reachable = rx
        .recv_timeout(std::time::Duration::from_secs(4))
        .unwrap_or(false);
    Check {
        name: "Usage API reachable",
        passed: reachable,
        detail: if reachable {
            "api.anthropic.com responding".to_string()
        } else {
            "Cannot reach api.anthropic.com (network issue?)".to_string()
        },
    }
}

fn check_promo_api() -> Check {
    let (tx, rx) = std::sync::mpsc::channel();
    std::thread::spawn(move || {
        let result = ureq::AgentBuilder::new()
            .timeout(std::time::Duration::from_secs(3))
            .build()
            .get("https://promoclock.co/api/status")
            .call();
        let _ = tx.send(result.is_ok());
    });
    let reachable = rx
        .recv_timeout(std::time::Duration::from_secs(4))
        .unwrap_or(false);
    Check {
        name: "Promo API reachable",
        passed: reachable,
        detail: if reachable {
            "promoclock.co responding".to_string()
        } else {
            "Cannot reach promoclock.co (non-critical)".to_string()
        },
    }
}

fn check_config_found() -> Check {
    match config::discover_config_path() {
        Some(path) => Check {
            name: "Config file found",
            passed: true,
            detail: format!("{}", path.display()),
        },
        None => Check {
            name: "Config file found",
            passed: false,
            detail: "No sonde.toml found (using defaults)".to_string(),
        },
    }
}

fn check_config_valid() -> Check {
    match config::discover_config_path() {
        Some(path) => match std::fs::read_to_string(&path) {
            Ok(content) => match toml::from_str::<config::ConfigFile>(&content) {
                Ok(_) => Check {
                    name: "Config file valid",
                    passed: true,
                    detail: "TOML parses successfully".to_string(),
                },
                Err(e) => Check {
                    name: "Config file valid",
                    passed: false,
                    detail: format!("Parse error: {e}"),
                },
            },
            Err(e) => Check {
                name: "Config file valid",
                passed: false,
                detail: format!("Read error: {e}"),
            },
        },
        None => Check {
            name: "Config file valid",
            passed: true,
            detail: "No config file (defaults are valid)".to_string(),
        },
    }
}

fn check_cache_writable() -> Check {
    let cache_dir = match cache::cache_dir() {
        Some(d) => d,
        None => {
            return Check {
                name: "Cache directory writable",
                passed: false,
                detail: "Cannot determine cache directory".to_string(),
            }
        }
    };

    if let Err(e) = std::fs::create_dir_all(&cache_dir) {
        return Check {
            name: "Cache directory writable",
            passed: false,
            detail: format!("Cannot create {}: {e}", cache_dir.display()),
        };
    }

    let test_file = cache_dir.join(".doctor_test");
    match std::fs::write(&test_file, "test") {
        Ok(_) => {
            let _ = std::fs::remove_file(&test_file);
            Check {
                name: "Cache directory writable",
                passed: true,
                detail: format!("{}", cache_dir.display()),
            }
        }
        Err(e) => Check {
            name: "Cache directory writable",
            passed: false,
            detail: format!("Cannot write to {}: {e}", cache_dir.display()),
        },
    }
}

fn check_terminal_colors() -> Check {
    let term = std::env::var("TERM").unwrap_or_default();
    let colorterm = std::env::var("COLORTERM").unwrap_or_default();
    let supports_color =
        colorterm.contains("truecolor") || colorterm.contains("24bit") || term.contains("256color");
    Check {
        name: "Terminal colors",
        passed: supports_color,
        detail: format!("TERM={term} COLORTERM={colorterm}"),
    }
}

fn check_nerd_font() -> Check {
    Check {
        name: "Nerd Font glyphs",
        passed: true,
        detail: "Test glyph: \u{e0b0} (powerline arrow). If you see a box/?, install a Nerd Font"
            .to_string(),
    }
}

fn format_check(check: &Check) -> String {
    let icon = if check.passed { "\u{2714}" } else { "\u{2718}" };
    let color = if check.passed { "32" } else { "31" };
    format!(
        "\x1b[{color}m{icon}\x1b[0m {}: {}",
        check.name, check.detail
    )
}

pub fn run() -> i32 {
    println!("\x1b[1msonde doctor\x1b[0m\n");

    let checks = vec![
        check_claude_installed(),
        check_oauth_token(),
        check_usage_api(),
        check_promo_api(),
        check_config_found(),
        check_config_valid(),
        check_cache_writable(),
        check_terminal_colors(),
        check_nerd_font(),
    ];

    for check in &checks {
        println!("  {}", format_check(check));
    }

    let critical_checks = [
        "Claude Code installed",
        "OAuth token available",
        "Cache directory writable",
    ];
    let all_critical_pass = checks
        .iter()
        .filter(|c| critical_checks.contains(&c.name))
        .all(|c| c.passed);

    let passed = checks.iter().filter(|c| c.passed).count();
    let total = checks.len();
    println!("\n  {passed}/{total} checks passed");

    if all_critical_pass {
        0
    } else {
        1
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn format_check_pass() {
        let c = Check {
            name: "Test",
            passed: true,
            detail: "OK".to_string(),
        };
        let output = format_check(&c);
        assert!(output.contains("Test"));
        assert!(output.contains("OK"));
        assert!(output.contains("\u{2714}"));
    }

    #[test]
    fn format_check_fail() {
        let c = Check {
            name: "Test",
            passed: false,
            detail: "FAIL".to_string(),
        };
        let output = format_check(&c);
        assert!(output.contains("\u{2718}"));
    }

    #[test]
    fn config_valid_with_good_toml() {
        let c = check_config_valid();
        // Should not crash regardless of whether config exists
        assert!(!c.name.is_empty());
    }

    #[test]
    fn cache_writable_check() {
        let c = check_cache_writable();
        // On a dev machine, cache should be writable
        assert!(c.passed);
    }

    #[test]
    fn nerd_font_always_passes() {
        let c = check_nerd_font();
        assert!(c.passed);
    }
}
