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
    /// Added in Claude Code v2.1.80 (2026-03-19). Pro/Max only; populated after
    /// the first API response in a session. Preferred over the OAuth usage
    /// endpoint — free, no HTTP, no risk of triggering billed fallbacks.
    pub rate_limits: Option<RateLimits>,
    /// Added in Claude Code v2.1.105 (2026-04-13).
    pub effort: Option<Effort>,
    /// Added in Claude Code v2.1.105.
    pub thinking: Option<Thinking>,
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
    /// Added in Claude Code v2.1.97 (2026-04-08).
    pub git_worktree: Option<String>,
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

/// Rate-limit data Claude Code provides on stdin since v2.1.80.
/// See <https://code.claude.com/docs/en/statusline>.
#[derive(Debug, Deserialize, Default, Clone)]
pub struct RateLimits {
    pub five_hour: Option<RateLimitWindow>,
    pub seven_day: Option<RateLimitWindow>,
}

#[derive(Debug, Deserialize, Default, Clone, Copy)]
pub struct RateLimitWindow {
    /// 0–100 percent of the window consumed.
    pub used_percentage: Option<f64>,
    /// Unix epoch seconds.
    pub resets_at: Option<i64>,
}

/// Added in v2.1.105: `low | medium | high | xhigh | max`.
#[allow(dead_code)]
#[derive(Debug, Deserialize, Default, Clone)]
pub struct Effort {
    pub level: Option<String>,
}

/// Added in v2.1.105.
#[allow(dead_code)]
#[derive(Debug, Deserialize, Default, Clone)]
pub struct Thinking {
    pub enabled: Option<bool>,
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

    #[test]
    fn rate_limits_full() {
        let json = r#"{
            "rate_limits": {
                "five_hour":  {"used_percentage": 42.5, "resets_at": 1717000000},
                "seven_day":  {"used_percentage": 12.0, "resets_at": 1717500000}
            }
        }"#;
        let ctx = parse_str(json);
        let rl = ctx.rate_limits.as_ref().expect("rate_limits parsed");
        assert_eq!(rl.five_hour.unwrap().used_percentage, Some(42.5));
        assert_eq!(rl.five_hour.unwrap().resets_at, Some(1717000000));
        assert_eq!(rl.seven_day.unwrap().used_percentage, Some(12.0));
    }

    #[test]
    fn rate_limits_partial() {
        let json = r#"{"rate_limits":{"five_hour":{"used_percentage":7.0}}}"#;
        let ctx = parse_str(json);
        let rl = ctx.rate_limits.as_ref().unwrap();
        assert_eq!(rl.five_hour.unwrap().used_percentage, Some(7.0));
        assert!(rl.five_hour.unwrap().resets_at.is_none());
        assert!(rl.seven_day.is_none());
    }

    #[test]
    fn rate_limits_missing() {
        let ctx = parse_str(r#"{"model":{"display_name":"Opus"}}"#);
        assert!(ctx.rate_limits.is_none());
    }

    #[test]
    fn rate_limits_malformed_field_does_not_panic() {
        // `used_percentage` as a string instead of number → entire `rate_limits`
        // becomes None (serde returns an error on the whole field), but parser
        // returns a default `Context` rather than crashing.
        let json = r#"{"rate_limits":{"five_hour":{"used_percentage":"bogus"}}}"#;
        let ctx = parse_str(json);
        // Either rate_limits is None or window has None — both acceptable.
        // Critical assertion: we returned a Context, no panic.
        let _ = ctx.rate_limits;
    }

    #[test]
    fn workspace_git_worktree_field() {
        let json = r#"{"workspace":{"current_dir":"/x","git_worktree":"feature-foo"}}"#;
        let ctx = parse_str(json);
        assert_eq!(
            ctx.workspace.as_ref().unwrap().git_worktree.as_deref(),
            Some("feature-foo")
        );
    }

    #[test]
    fn effort_and_thinking_fields() {
        let json = r#"{"effort":{"level":"xhigh"},"thinking":{"enabled":true}}"#;
        let ctx = parse_str(json);
        assert_eq!(ctx.effort.as_ref().unwrap().level.as_deref(), Some("xhigh"));
        assert_eq!(ctx.thinking.as_ref().unwrap().enabled, Some(true));
    }

    #[test]
    fn context_window_current_semantics_v2_1_128() {
        // After v2.1.128 (2026-05-04) token counts are CURRENT-CONTEXT, not
        // cumulative. Sonde just deserializes the numbers it's given — this
        // test pins the expected shape so future schema drift fails fast.
        let json = r#"{
            "context_window": {
                "total_input_tokens": 12000,
                "total_output_tokens": 800,
                "context_window_size": 200000,
                "used_percentage": 6.4,
                "current_usage": {
                    "input_tokens": 12000,
                    "output_tokens": 800,
                    "cache_creation_input_tokens": 0,
                    "cache_read_input_tokens": 0
                }
            }
        }"#;
        let ctx = parse_str(json);
        let cw = ctx.context_window.as_ref().unwrap();
        assert_eq!(cw.total_input_tokens, Some(12000));
        assert_eq!(cw.used_percentage, Some(6.4));
        assert_eq!(cw.context_window_size, Some(200000));
    }
}
