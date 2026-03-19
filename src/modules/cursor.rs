use serde::Deserialize;
use std::path::{Path, PathBuf};

use crate::ansi;
use crate::config::{self, SondeConfig};
use crate::context::Context;

#[derive(Debug, Deserialize)]
struct CursorUsage {
    model: Option<String>,
    input_tokens: Option<u64>,
    output_tokens: Option<u64>,
}

#[derive(Debug, Deserialize)]
#[serde(tag = "type")]
enum CursorEvent {
    #[serde(rename = "model_usage")]
    ModelUsage {
        model: Option<String>,
        input_tokens: Option<u64>,
        output_tokens: Option<u64>,
        #[allow(dead_code)]
        timestamp: Option<String>,
    },
    #[serde(other)]
    Other,
}

fn price_per_million(model: &str) -> (f64, f64) {
    match model {
        m if m.contains("claude-3.5-sonnet") || m.contains("claude-3-5-sonnet") => (3.00, 15.00),
        m if m.contains("claude-3-opus") || m.contains("claude-3.5-opus") => (15.00, 75.00),
        m if m.contains("claude-3-haiku") || m.contains("claude-3.5-haiku") => (0.25, 1.25),
        m if m.contains("gpt-4o") => (2.50, 10.00),
        m if m.contains("gpt-4-turbo") => (10.00, 30.00),
        m if m.contains("gpt-4") => (10.00, 30.00),
        m if m.contains("gpt-3.5") => (0.50, 1.50),
        m if m.contains("o1-mini") => (3.00, 12.00),
        m if m.contains("o1") => (15.00, 60.00),
        m if m.contains("gemini") => (1.25, 5.00),
        _ => (3.00, 15.00), // default to claude-3.5-sonnet pricing
    }
}

fn token_cost(input: u64, output: u64, model: &str) -> f64 {
    let (input_price, output_price) = price_per_million(model);
    (input as f64 / 1_000_000.0) * input_price + (output as f64 / 1_000_000.0) * output_price
}

fn cursor_data_dir(cfg: &SondeConfig) -> PathBuf {
    if let Some(ccfg) = cfg.cursor.as_ref() {
        if let Some(dir) = ccfg.sessions_dir.as_deref() {
            return config::expand_tilde(dir);
        }
    }

    if let Some(home) = dirs::home_dir() {
        home.join(".cursor")
    } else {
        PathBuf::from(".cursor")
    }
}

fn cost_from_usage_json(dir: &Path) -> Option<f64> {
    let usage_path = dir.join("usage.json");
    let content = match std::fs::read_to_string(&usage_path) {
        Ok(c) => c,
        Err(_) => return None,
    };

    if let Ok(entries) = serde_json::from_str::<Vec<CursorUsage>>(&content) {
        let mut total_cost = 0.0;
        for entry in &entries {
            let model = entry.model.as_deref().unwrap_or("claude-3.5-sonnet");
            let input = entry.input_tokens.unwrap_or(0);
            let output = entry.output_tokens.unwrap_or(0);
            total_cost += token_cost(input, output, model);
        }
        if total_cost > 0.0 {
            return Some(total_cost);
        }
    }

    if let Ok(entry) = serde_json::from_str::<CursorUsage>(&content) {
        let model = entry.model.as_deref().unwrap_or("claude-3.5-sonnet");
        let input = entry.input_tokens.unwrap_or(0);
        let output = entry.output_tokens.unwrap_or(0);
        let cost = token_cost(input, output, model);
        if cost > 0.0 {
            return Some(cost);
        }
    }

    None
}

/// Find the most recently modified .jsonl file, searching recursively.
fn find_newest_jsonl(dir: &Path) -> Option<PathBuf> {
    let entries = std::fs::read_dir(dir).ok()?;
    let mut best: Option<(PathBuf, std::time::SystemTime)> = None;

    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            if let Some(sub) = find_newest_jsonl(&path) {
                if let Some(mod_time) = sub.metadata().ok().and_then(|m| m.modified().ok()) {
                    if best.as_ref().is_none_or(|(_, t)| mod_time > *t) {
                        best = Some((sub, mod_time));
                    }
                }
            }
            continue;
        }
        if path.extension().and_then(|e| e.to_str()) != Some("jsonl") {
            continue;
        }
        if let Some(mod_time) = path.metadata().ok().and_then(|m| m.modified().ok()) {
            if best.as_ref().is_none_or(|(_, t)| mod_time > *t) {
                best = Some((path, mod_time));
            }
        }
    }

    best.map(|(p, _)| p)
}

/// Prefer a `sessions/` subdirectory if it exists, then search recursively.
fn latest_session(dir: &Path) -> Option<PathBuf> {
    let sessions_subdir = dir.join("sessions");
    let search_dir = if sessions_subdir.exists() {
        &sessions_subdir
    } else {
        dir
    };
    find_newest_jsonl(search_dir)
}

fn calculate_session_cost(path: &Path) -> Option<f64> {
    let content = std::fs::read_to_string(path).ok()?;
    let mut total_cost = 0.0;

    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }

        let event: CursorEvent = match serde_json::from_str(line) {
            Ok(e) => e,
            Err(_) => continue,
        };

        match event {
            CursorEvent::ModelUsage {
                model,
                input_tokens,
                output_tokens,
                ..
            } => {
                let model_name = model.as_deref().unwrap_or("claude-3.5-sonnet");
                let input = input_tokens.unwrap_or(0);
                let output = output_tokens.unwrap_or(0);
                total_cost += token_cost(input, output, model_name);
            }
            CursorEvent::Other => {}
        }
    }

    if total_cost > 0.0 {
        Some(total_cost)
    } else {
        None
    }
}

pub fn get_latest_session_cost(cfg: &SondeConfig) -> Option<f64> {
    let dir = cursor_data_dir(cfg);
    if !dir.exists() {
        return None;
    }

    if let Some(cost) = cost_from_usage_json(&dir) {
        return Some(cost);
    }

    let session = latest_session(&dir)?;
    calculate_session_cost(&session)
}

pub fn render(_ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    if let Some(ccfg) = cfg.cursor.as_ref() {
        if ccfg.enabled == Some(false) {
            return None;
        }
    }

    let dir = cursor_data_dir(cfg);
    if !dir.exists() {
        tracing::debug!("cursor: data dir does not exist: {}", dir.display());
        return None;
    }

    if let Some(cost) = cost_from_usage_json(&dir) {
        let text = format!("Cursor: ${cost:.2}");
        return Some(ansi::styled(&text, Some("fg:#a9b1d6")));
    }

    let session = match latest_session(&dir) {
        Some(s) => s,
        None => {
            tracing::debug!("cursor: no session files found");
            return None;
        }
    };

    let cost = calculate_session_cost(&session)?;

    let text = format!("Cursor: ${cost:.2}");
    Some(ansi::styled(&text, Some("fg:#a9b1d6")))
}
