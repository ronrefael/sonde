use serde::Deserialize;
use std::path::{Path, PathBuf};

use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;

/// Codex JSONL event types.
#[derive(Debug, Deserialize)]
#[serde(tag = "type")]
enum CodexEvent {
    #[serde(rename = "turn_context")]
    TurnContext {
        model: Option<String>,
        #[allow(dead_code)]
        timestamp: Option<String>,
    },
    #[serde(rename = "event_msg")]
    EventMsg {
        payload: Option<EventPayload>,
        #[allow(dead_code)]
        timestamp: Option<String>,
    },
    #[serde(other)]
    Other,
}

#[derive(Debug, Deserialize)]
struct EventPayload {
    #[serde(rename = "type")]
    event_type: Option<String>,
    input_tokens: Option<u64>,
    #[allow(dead_code)]
    cached_input_tokens: Option<u64>,
    output_tokens: Option<u64>,
    #[allow(dead_code)]
    total_tokens: Option<u64>,
}

/// Simple pricing table for Codex models (per 1M tokens).
fn price_per_million(model: &str) -> (f64, f64) {
    // (input_price, output_price) per 1M tokens
    match model {
        m if m.contains("gpt-4o") => (2.50, 10.00),
        m if m.contains("gpt-4") => (10.00, 30.00),
        m if m.contains("gpt-5") => (2.50, 10.00), // estimated
        m if m.contains("o3") => (2.00, 8.00),
        m if m.contains("o4-mini") => (1.10, 4.40),
        _ => (2.50, 10.00), // default to gpt-5 pricing
    }
}

fn sessions_dir(cfg: &SondeConfig) -> PathBuf {
    if let Some(ccfg) = cfg.codex.as_ref() {
        if let Some(dir) = ccfg.sessions_dir.as_deref() {
            let expanded = if dir.starts_with('~') {
                if let Some(home) = dirs::home_dir() {
                    home.join(&dir[2..])
                } else {
                    PathBuf::from(dir)
                }
            } else {
                PathBuf::from(dir)
            };
            return expanded;
        }
    }

    // Default
    if let Some(home) = dirs::home_dir() {
        home.join(".codex").join("sessions")
    } else {
        PathBuf::from(".codex/sessions")
    }
}

/// Calculate total cost from a Codex JSONL session file.
fn calculate_session_cost(path: &Path) -> Option<f64> {
    let content = std::fs::read_to_string(path).ok()?;
    let mut model = String::from("gpt-5");
    let mut prev_input: u64 = 0;
    let mut prev_output: u64 = 0;
    let mut total_cost = 0.0;

    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }

        let event: CodexEvent = match serde_json::from_str(line) {
            Ok(e) => e,
            Err(_) => continue,
        };

        match event {
            CodexEvent::TurnContext { model: Some(m), .. } => {
                model = m;
            }
            CodexEvent::EventMsg {
                payload: Some(ref p),
                ..
            } if p.event_type.as_deref() == Some("token_count") => {
                let curr_input = p.input_tokens.unwrap_or(0);
                let curr_output = p.output_tokens.unwrap_or(0);

                let delta_input = curr_input.saturating_sub(prev_input);
                let delta_output = curr_output.saturating_sub(prev_output);

                let (input_price, output_price) = price_per_million(&model);
                total_cost += (delta_input as f64 / 1_000_000.0) * input_price;
                total_cost += (delta_output as f64 / 1_000_000.0) * output_price;

                prev_input = curr_input;
                prev_output = curr_output;
            }
            _ => {}
        }
    }

    if total_cost > 0.0 {
        Some(total_cost)
    } else {
        None
    }
}

/// Find the most recently modified session file.
fn latest_session(dir: &Path) -> Option<PathBuf> {
    let entries = std::fs::read_dir(dir).ok()?;
    let mut best: Option<(PathBuf, std::time::SystemTime)> = None;

    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) != Some("jsonl") {
            // Check subdirectories
            if path.is_dir() {
                if let Some(sub) = latest_session(&path) {
                    let mod_time = sub.metadata().ok()?.modified().ok()?;
                    if best.as_ref().map(|(_, t)| mod_time > *t).unwrap_or(true) {
                        best = Some((sub, mod_time));
                    }
                }
            }
            continue;
        }
        if let Ok(meta) = path.metadata() {
            if let Ok(mod_time) = meta.modified() {
                if best.as_ref().map(|(_, t)| mod_time > *t).unwrap_or(true) {
                    best = Some((path, mod_time));
                }
            }
        }
    }

    best.map(|(p, _)| p)
}

/// Public helper for combined_spend module.
pub fn get_latest_session_cost(cfg: &SondeConfig) -> Option<f64> {
    let dir = sessions_dir(cfg);
    if !dir.exists() {
        return None;
    }
    let session = latest_session(&dir)?;
    calculate_session_cost(&session)
}

pub fn render(_ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    if let Some(ccfg) = cfg.codex.as_ref() {
        if ccfg.enabled == Some(false) {
            return None;
        }
    }

    let dir = sessions_dir(cfg);
    if !dir.exists() {
        tracing::debug!("codex_cost: sessions dir does not exist: {}", dir.display());
        return None;
    }

    let session = match latest_session(&dir) {
        Some(s) => s,
        None => {
            tracing::debug!("codex_cost: no session files found");
            return None;
        }
    };

    let cost = calculate_session_cost(&session)?;

    let text = format!("Codex: ${cost:.2}");
    Some(ansi::styled(&text, Some("fg:#a9b1d6")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_codex_session() {
        let path =
            Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/sample_codex_session.jsonl");
        let cost = calculate_session_cost(&path);
        assert!(cost.is_some());
        let c = cost.unwrap();
        // Should be > 0 from the fixture data
        assert!(c > 0.0);
    }
}
