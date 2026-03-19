use serde::Deserialize;
use std::path::{Path, PathBuf};

use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;

/// Cursor usage JSON structure (from ~/.cursor/usage.json).
#[derive(Debug, Deserialize)]
struct CursorUsage {
    model: Option<String>,
    input_tokens: Option<u64>,
    output_tokens: Option<u64>,
}

/// Cursor JSONL event types (session logs).
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

/// Simple pricing table for Cursor models (per 1M tokens).
fn price_per_million(model: &str) -> (f64, f64) {
    // (input_price, output_price) per 1M tokens
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

fn data_dir(cfg: &SondeConfig) -> PathBuf {
    if let Some(ccfg) = cfg.cursor.as_ref() {
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
        home.join(".cursor")
    } else {
        PathBuf::from(".cursor")
    }
}

/// Try to read cost from a usage.json file.
fn cost_from_usage_json(dir: &Path) -> Option<f64> {
    let usage_path = dir.join("usage.json");
    let content = match std::fs::read_to_string(&usage_path) {
        Ok(c) => c,
        Err(_) => return None,
    };

    // Try as array of usage entries
    if let Ok(entries) = serde_json::from_str::<Vec<CursorUsage>>(&content) {
        let mut total_cost = 0.0;
        for entry in &entries {
            let model = entry.model.as_deref().unwrap_or("claude-3.5-sonnet");
            let input = entry.input_tokens.unwrap_or(0);
            let output = entry.output_tokens.unwrap_or(0);
            let (input_price, output_price) = price_per_million(model);
            total_cost += (input as f64 / 1_000_000.0) * input_price;
            total_cost += (output as f64 / 1_000_000.0) * output_price;
        }
        if total_cost > 0.0 {
            return Some(total_cost);
        }
    }

    // Try as single usage entry
    if let Ok(entry) = serde_json::from_str::<CursorUsage>(&content) {
        let model = entry.model.as_deref().unwrap_or("claude-3.5-sonnet");
        let input = entry.input_tokens.unwrap_or(0);
        let output = entry.output_tokens.unwrap_or(0);
        let (input_price, output_price) = price_per_million(model);
        let mut total_cost = 0.0;
        total_cost += (input as f64 / 1_000_000.0) * input_price;
        total_cost += (output as f64 / 1_000_000.0) * output_price;
        if total_cost > 0.0 {
            return Some(total_cost);
        }
    }

    None
}

/// Find the most recently modified JSONL session file.
fn latest_session(dir: &Path) -> Option<PathBuf> {
    let sessions_dir = dir.join("sessions");
    let search_dir = if sessions_dir.exists() {
        &sessions_dir
    } else {
        dir
    };

    let entries = std::fs::read_dir(search_dir).ok()?;
    let mut best: Option<(PathBuf, std::time::SystemTime)> = None;

    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) != Some("jsonl") {
            if path.is_dir() {
                if let Some(sub) = latest_session_recursive(&path) {
                    let mod_time = match sub.metadata().ok().and_then(|m| m.modified().ok()) {
                        Some(t) => t,
                        None => continue,
                    };
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

fn latest_session_recursive(dir: &Path) -> Option<PathBuf> {
    let entries = std::fs::read_dir(dir).ok()?;
    let mut best: Option<(PathBuf, std::time::SystemTime)> = None;

    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) != Some("jsonl") {
            if path.is_dir() {
                if let Some(sub) = latest_session_recursive(&path) {
                    let mod_time = match sub.metadata().ok().and_then(|m| m.modified().ok()) {
                        Some(t) => t,
                        None => continue,
                    };
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

/// Calculate cost from a Cursor JSONL session file.
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
                let (input_price, output_price) = price_per_million(model_name);
                total_cost += (input as f64 / 1_000_000.0) * input_price;
                total_cost += (output as f64 / 1_000_000.0) * output_price;
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

/// Public helper for combined_spend module.
pub fn get_latest_session_cost(cfg: &SondeConfig) -> Option<f64> {
    let dir = data_dir(cfg);
    if !dir.exists() {
        return None;
    }

    // Try usage.json first
    if let Some(cost) = cost_from_usage_json(&dir) {
        return Some(cost);
    }

    // Fall back to JSONL session logs
    let session = latest_session(&dir)?;
    calculate_session_cost(&session)
}

pub fn render(_ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    if let Some(ccfg) = cfg.cursor.as_ref() {
        if ccfg.enabled == Some(false) {
            return None;
        }
    }

    let dir = data_dir(cfg);
    if !dir.exists() {
        tracing::debug!("cursor: data dir does not exist: {}", dir.display());
        return None;
    }

    // Try usage.json first
    if let Some(cost) = cost_from_usage_json(&dir) {
        let text = format!("Cursor: ${cost:.2}");
        return Some(ansi::styled(&text, Some("fg:#a9b1d6")));
    }

    // Fall back to JSONL session logs
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
