use std::time::{SystemTime, UNIX_EPOCH};

use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;
use crate::promo;
use crate::usage_api;

/// Mascot state, determined by priority (first match wins).
#[derive(Debug, Clone, Copy, PartialEq)]
pub(crate) enum State {
    Idle,
    Runaway,
    Complete,
    Opus,
    Promo,
    Burn,
    Active,
    Early,
}

impl State {
    pub(crate) fn color(&self) -> &'static str {
        match self {
            State::Idle => "fg:#6b7280",
            State::Runaway => "fg:#f87171",
            State::Complete => "fg:#fb7185",
            State::Opus => "fg:#a78bfa",
            State::Promo => "fg:#22d3ee",
            State::Burn => "fg:#facc15",
            State::Active => "fg:#a3e635",
            State::Early => "fg:#4ade80",
        }
    }

    /// Compact icon frames for powerline segments (single character each).
    pub(crate) fn icon_frames(&self) -> &'static [&'static str] {
        match self {
            State::Idle => &["○", "○", "○", "◌", "◌", "○", "○", "○"],
            State::Early => &["●", "●", "◉", "●", "●", "●", "◉", "●"],
            State::Active => &["◆", "●", "◉", "●", "◆", "●", "◉", "●"],
            State::Burn => &["◈", "◆", "●", "◉", "◈", "◆", "●", "◉"],
            State::Opus => &["✦", "◆", "✦", "●", "✦", "◆", "✦", "●"],
            State::Promo => &["◉", "✦", "◉", "✦", "◉", "✦", "◉", "✦"],
            State::Complete => &["✧", "✦", "★", "✦", "✧", "✦", "★", "✦"],
            State::Runaway => &["●", "○", "●", "○", "●", "○", "●", "○"],
        }
    }
}

/// Detect mascot state from context and external APIs (priority order).
pub(crate) fn detect_state(ctx: &Context, cfg: &SondeConfig) -> State {
    let has_model = ctx.model.is_some();
    let has_cost = ctx.cost.is_some();
    let cost_usd = ctx
        .cost
        .as_ref()
        .and_then(|c| c.total_cost_usd)
        .unwrap_or(0.0);
    let context_pct = ctx
        .context_window
        .as_ref()
        .and_then(|c| c.used_percentage)
        .unwrap_or(0.0);
    let model_id = ctx
        .model
        .as_ref()
        .and_then(|m| m.id.as_deref())
        .unwrap_or("");

    // Priority 1: Idle — no active session
    if !has_model {
        // Priority 3: Complete — cost exists but model gone (rare edge)
        if has_cost {
            return State::Complete;
        }
        return State::Idle;
    }

    // Priority 2: Runaway — 5h utilization > 90%
    let ttl = cfg.usage_limits.as_ref().and_then(|c| c.ttl);
    if let Some(data) = usage_api::fetch_usage(ttl) {
        if let Some(util) = data.five_hour.as_ref().and_then(|w| w.utilization) {
            if util > 90.0 {
                return State::Runaway;
            }
        }
    }

    // Priority 4: Opus
    if model_id.to_lowercase().contains("opus") {
        return State::Opus;
    }

    // Priority 5: Promo
    let api_url = cfg.promo_badge.as_ref().and_then(|c| c.api_url.as_deref());
    let promo_ttl = cfg.promo_badge.as_ref().and_then(|c| c.poll_interval);
    let is_offpeak = promo::fetch_promo(api_url, promo_ttl)
        .and_then(|s| s.is_offpeak)
        .unwrap_or(false);
    if is_offpeak {
        return State::Promo;
    }

    // Priority 6: Burn
    if cost_usd >= 5.0 || context_pct >= 60.0 {
        return State::Burn;
    }

    // Priority 7: Active
    if cost_usd >= 1.0 {
        return State::Active;
    }

    // Priority 8: Early — session exists with cost < 1.0
    State::Early
}

/// Compact single-character animated icon — fits in a powerline segment.
/// Cycles through state-specific symbols at the configured frame rate.
pub fn render_icon(ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    if cfg.mascot.as_ref().and_then(|m| m.enabled) == Some(false) {
        return None;
    }

    let state = detect_state(ctx, cfg);
    let color = state.color();
    let icons = state.icon_frames();

    let frame_ms = cfg.mascot.as_ref().and_then(|c| c.frame_ms).unwrap_or(250);

    let frame = (SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
        / frame_ms as u128) as usize;
    let idx = frame % icons.len();

    Some(ansi::styled(icons[idx], Some(color)))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context;

    #[test]
    fn idle_state_for_empty_context() {
        let ctx = Context::default();
        let cfg = SondeConfig::default();
        let state = detect_state(&ctx, &cfg);
        assert_eq!(state, State::Idle);
    }

    #[test]
    fn early_or_promo_state_for_low_cost() {
        let ctx = context::parse_str(
            r#"{"model":{"id":"claude-sonnet","display_name":"Sonnet"},"cost":{"total_cost_usd":0.5}}"#,
        );
        let cfg = SondeConfig::default();
        let state = detect_state(&ctx, &cfg);
        // May be Promo if promo cache is populated (CI/local), otherwise Early
        assert!(
            state == State::Early || state == State::Promo,
            "Expected Early or Promo, got {:?}",
            state
        );
    }

    #[test]
    fn active_or_promo_state_for_medium_cost() {
        let ctx = context::parse_str(
            r#"{"model":{"id":"claude-sonnet","display_name":"Sonnet"},"cost":{"total_cost_usd":2.0}}"#,
        );
        let cfg = SondeConfig::default();
        let state = detect_state(&ctx, &cfg);
        assert!(
            state == State::Active || state == State::Promo,
            "Expected Active or Promo, got {:?}",
            state
        );
    }

    #[test]
    fn burn_or_promo_state_for_high_cost() {
        let ctx = context::parse_str(
            r#"{"model":{"id":"claude-sonnet","display_name":"Sonnet"},"cost":{"total_cost_usd":6.0}}"#,
        );
        let cfg = SondeConfig::default();
        let state = detect_state(&ctx, &cfg);
        assert!(
            state == State::Burn || state == State::Promo,
            "Expected Burn or Promo, got {:?}",
            state
        );
    }

    #[test]
    fn opus_state_for_opus_model() {
        // Opus has higher priority than Promo, so it always wins
        let ctx = context::parse_str(
            r#"{"model":{"id":"claude-opus-4","display_name":"Opus"},"cost":{"total_cost_usd":0.5}}"#,
        );
        let cfg = SondeConfig::default();
        let state = detect_state(&ctx, &cfg);
        assert_eq!(state, State::Opus);
    }

    #[test]
    fn complete_state_for_cost_no_model() {
        let ctx = context::parse_str(r#"{"cost":{"total_cost_usd":1.0}}"#);
        let cfg = SondeConfig::default();
        let state = detect_state(&ctx, &cfg);
        assert_eq!(state, State::Complete);
    }

    #[test]
    fn render_icon_returns_something() {
        let ctx = Context::default();
        let cfg = SondeConfig::default();
        let result = render_icon(&ctx, &cfg);
        assert!(result.is_some());
    }

    #[test]
    fn all_states_have_icon_frames() {
        let states = [
            State::Idle,
            State::Runaway,
            State::Complete,
            State::Opus,
            State::Promo,
            State::Burn,
            State::Active,
            State::Early,
        ];
        for state in states {
            let frames = state.icon_frames();
            assert!(
                frames.len() >= 4,
                "State {:?} should have at least 4 icon frames",
                state
            );
        }
    }

    #[test]
    fn disabled_returns_none() {
        let ctx = Context::default();
        let cfg = SondeConfig {
            mascot: Some(crate::config::MascotConfig {
                enabled: Some(false),
                frame_ms: None,
            }),
            ..SondeConfig::default()
        };
        assert!(render_icon(&ctx, &cfg).is_none());
    }
}
