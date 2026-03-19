use std::path::PathBuf;

/// SECURITY: Token must NOT be written to disk, cache, stdout, or stderr.
pub fn get_oauth_token() -> Option<String> {
    #[cfg(target_os = "macos")]
    {
        get_token_macos()
    }
    #[cfg(not(target_os = "macos"))]
    {
        get_token_linux()
    }
}

#[cfg(target_os = "macos")]
fn get_token_macos() -> Option<String> {
    let output = match std::process::Command::new("security")
        .args([
            "find-generic-password",
            "-s",
            "Claude Code-credentials",
            "-w",
        ])
        .output()
    {
        Ok(o) => o,
        Err(e) => {
            tracing::warn!("Failed to run security command: {e}");
            return None;
        }
    };

    if !output.status.success() {
        tracing::debug!("Keychain lookup returned non-zero status");
        return None;
    }

    let raw = String::from_utf8_lossy(&output.stdout).trim().to_string();
    extract_access_token(&raw)
}

#[cfg(not(target_os = "macos"))]
fn get_token_linux() -> Option<String> {
    if let Some(token) = get_token_from_file() {
        return Some(token);
    }

    let output = match std::process::Command::new("secret-tool")
        .args(["lookup", "service", "Claude Code-credentials"])
        .output()
    {
        Ok(o) => o,
        Err(e) => {
            tracing::debug!("secret-tool not available: {e}");
            return None;
        }
    };

    if !output.status.success() {
        tracing::debug!("secret-tool lookup returned non-zero status");
        return None;
    }

    let raw = String::from_utf8_lossy(&output.stdout).trim().to_string();
    extract_access_token(&raw)
}

#[allow(dead_code)]
fn get_token_from_file() -> Option<String> {
    let cred_path = credentials_file_path()?;
    let content = match std::fs::read_to_string(&cred_path) {
        Ok(c) => c,
        Err(e) => {
            tracing::debug!("Cannot read {}: {e}", cred_path.display());
            return None;
        }
    };
    extract_access_token(&content)
}

#[allow(dead_code)]
fn credentials_file_path() -> Option<PathBuf> {
    let home = dirs::home_dir()?;
    let path = home.join(".claude").join(".credentials.json");
    if path.exists() {
        Some(path)
    } else {
        None
    }
}

/// Shape: { "claudeAiOauth": { "accessToken": "..." } }
fn extract_access_token(json_str: &str) -> Option<String> {
    let value: serde_json::Value = match serde_json::from_str(json_str) {
        Ok(v) => v,
        Err(_) => {
            tracing::debug!("Credential data is not valid JSON");
            return None;
        }
    };

    value
        .get("claudeAiOauth")
        .and_then(|v| v.get("accessToken"))
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extract_token_from_json() {
        let json = r#"{"claudeAiOauth":{"accessToken":"tok_abc123"}}"#;
        assert_eq!(extract_access_token(json), Some("tok_abc123".to_string()));
    }

    #[test]
    fn extract_token_missing_field() {
        let json = r#"{"other":"data"}"#;
        assert_eq!(extract_access_token(json), None);
    }

    #[test]
    fn extract_token_invalid_json() {
        assert_eq!(extract_access_token("not json"), None);
    }
}
