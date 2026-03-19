// Forward-compatible context: all Option<T>, no deny_unknown_fields.

use serde::Deserialize;
use std::io::{self, Read};

#[allow(dead_code)]
#[derive(Debug, Deserialize, Default)]
pub struct Context {
    pub cwd: Option<String>,
    pub session_id: Option<String>,
    pub transcript_path: Option<String>,
    pub version: Option<String>,
    pub exceeds_200k_tokens: Option<bool>,
    pub model: Option<Model>,
    pub workspace: Option<Workspace>,
    pub output_style: Option<OutputStyle>,
    pub cost: Option<Cost>,
    pub context_window: Option<ContextWindow>,
    pub vim: Option<Vim>,
    pub agent: Option<Agent>,
    pub worktree: Option<Worktree>,
}

#[derive(Debug, Deserialize, Default)]
pub struct Model {
    pub id: Option<String>,
    pub display_name: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize, Default)]
pub struct Workspace {
    pub current_dir: Option<String>,
    pub project_dir: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize, Default)]
pub struct OutputStyle {
    pub name: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize, Default)]
pub struct Cost {
    pub total_cost_usd: Option<f64>,
    pub total_duration_ms: Option<u64>,
    pub total_api_duration_ms: Option<u64>,
    pub total_lines_added: Option<u64>,
    pub total_lines_removed: Option<u64>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize, Default)]
pub struct ContextWindow {
    pub total_input_tokens: Option<u64>,
    pub total_output_tokens: Option<u64>,
    pub context_window_size: Option<u64>,
    pub used_percentage: Option<f64>,
    pub remaining_percentage: Option<f64>,
    pub current_usage: Option<CurrentUsage>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize, Default)]
pub struct CurrentUsage {
    pub input_tokens: Option<u64>,
    pub output_tokens: Option<u64>,
    pub cache_creation_input_tokens: Option<u64>,
    pub cache_read_input_tokens: Option<u64>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize, Default)]
pub struct Vim {
    pub mode: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize, Default)]
pub struct Agent {
    pub name: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize, Default)]
pub struct Worktree {
    pub name: Option<String>,
    pub path: Option<String>,
    pub branch: Option<String>,
    pub original_cwd: Option<String>,
    pub original_branch: Option<String>,
}

pub fn parse_stdin() -> Context {
    let mut input = String::new();
    match io::stdin().read_to_string(&mut input) {
        Ok(_) => {}
        Err(e) => {
            tracing::warn!("Failed to read stdin: {e}");
            return Context::default();
        }
    }

    let input = input.trim();
    if input.is_empty() {
        tracing::debug!("Empty stdin, using default context");
        return Context::default();
    }

    match serde_json::from_str(input) {
        Ok(ctx) => ctx,
        Err(e) => {
            tracing::warn!("Failed to parse stdin JSON: {e}");
            Context::default()
        }
    }
}

#[allow(dead_code)]
pub fn parse_str(input: &str) -> Context {
    match serde_json::from_str(input) {
        Ok(ctx) => ctx,
        Err(e) => {
            tracing::warn!("Failed to parse context JSON: {e}");
            Context::default()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_full_input() {
        let json = include_str!("../tests/fixtures/sample_input_full.json");
        let ctx = parse_str(json);
        assert_eq!(
            ctx.model.as_ref().unwrap().display_name.as_deref(),
            Some("Opus")
        );
        assert!((ctx.cost.as_ref().unwrap().total_cost_usd.unwrap() - 1.23).abs() < f64::EPSILON);
        assert!(
            (ctx.context_window
                .as_ref()
                .unwrap()
                .used_percentage
                .unwrap()
                - 42.0)
                .abs()
                < f64::EPSILON
        );
    }

    #[test]
    fn parse_minimal_input() {
        let json = r#"{"model":{"display_name":"Haiku"},"cost":{"total_cost_usd":0.01}}"#;
        let ctx = parse_str(json);
        assert_eq!(
            ctx.model.as_ref().unwrap().display_name.as_deref(),
            Some("Haiku")
        );
        assert!(ctx.context_window.is_none());
    }

    #[test]
    fn parse_empty_input() {
        let ctx = parse_str("{}");
        assert!(ctx.model.is_none());
        assert!(ctx.cost.is_none());
    }

    #[test]
    fn unknown_fields_ignored() {
        let json = r#"{"model":{"display_name":"Opus"},"some_future_field":42}"#;
        let ctx = parse_str(json);
        assert_eq!(
            ctx.model.as_ref().unwrap().display_name.as_deref(),
            Some("Opus")
        );
    }
}
