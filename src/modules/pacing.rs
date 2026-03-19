use nu_ansi_term::Color;

use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;
use crate::promo;
use crate::usage_api;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum PaceTier {
    Comfortable,
    OnTrack,
    Elevated,
    Hot,
    Critical,
    Runaway,
}

impl PaceTier {
    pub fn icon(&self) -> &'static str {
        match self {
            PaceTier::Comfortable => "\u{f058}", //  check-circle
            PaceTier::OnTrack => "\u{f00c}",     //  check
            PaceTier::Elevated => "\u{f071}",    //  warning
            PaceTier::Hot => "\u{f06d}",         //  fire
            PaceTier::Critical => "\u{f06a}",    //  exclamation-circle
            PaceTier::Runaway => "\u{f05e}",     //  ban
        }
    }

    pub fn label(&self) -> &'static str {
        match self {
            PaceTier::Comfortable => "Comfortable",
            PaceTier::OnTrack => "On Track",
            PaceTier::Elevated => "Elevated",
            PaceTier::Hot => "Hot",
            PaceTier::Critical => "Critical",
            PaceTier::Runaway => "Runaway",
        }
    }

    pub fn style(&self) -> &'static str {
        match self {
            PaceTier::Comfortable => "green",
            PaceTier::OnTrack => "blue",
            PaceTier::Elevated => "yellow",
            PaceTier::Hot => "fg:#e0af68",
            PaceTier::Critical => "red",
            PaceTier::Runaway => "bold red",
        }
    }

    /// Powerline background color for this tier.
    pub fn powerline_bg(&self) -> Color {
        match self {
            PaceTier::Comfortable => Color::Rgb(166, 227, 161), // green
            PaceTier::OnTrack => Color::Rgb(137, 180, 250),     // blue
            PaceTier::Elevated => Color::Rgb(249, 226, 175),    // yellow
            PaceTier::Hot => Color::Rgb(250, 179, 135),         // peach
            PaceTier::Critical => Color::Rgb(243, 139, 168),    // red
            PaceTier::Runaway => Color::Rgb(243, 139, 168),     // red
        }
    }
}

pub fn calculate_tier(utilization: f64, promo_active: bool) -> PaceTier {
    // Runaway is absolute, not relative
    if utilization > 90.0 {
        return PaceTier::Runaway;
    }

    let effective = if promo_active {
        utilization / 2.0
    } else {
        utilization
    };

    if effective < 30.0 {
        PaceTier::Comfortable
    } else if effective < 60.0 {
        PaceTier::OnTrack
    } else if effective < 80.0 {
        PaceTier::Elevated
    } else if effective < 100.0 {
        PaceTier::Hot
    } else {
        PaceTier::Critical
    }
}

pub fn current_pacing(cfg: &SondeConfig) -> Option<(PaceTier, f64)> {
    let ttl = cfg.usage_limits.as_ref().and_then(|c| c.ttl);
    let data = usage_api::fetch_usage(ttl)?;
    let utilization = data.five_hour.as_ref().and_then(|w| w.utilization)?;

    let promo_aware = cfg
        .pacing
        .as_ref()
        .map(|c| c.promo_aware.unwrap_or(true))
        .unwrap_or(true);
    let promo_active = if promo_aware {
        let api_url = cfg.promo_badge.as_ref().and_then(|c| c.api_url.as_deref());
        let promo_ttl = cfg.promo_badge.as_ref().and_then(|c| c.poll_interval);
        promo::fetch_promo(api_url, promo_ttl)
            .and_then(|s| s.is_offpeak)
            .unwrap_or(false)
    } else {
        false
    };

    let tier = calculate_tier(utilization, promo_active);
    let remaining = (100.0 - utilization).max(0.0);
    Some((tier, remaining))
}

/// Predicts time until utilization hits 100%, based on current rate within the 5h window.
/// Returns formatted string like "~1h 23m" or None if not applicable.
pub fn predict_time_to_limit(utilization: f64, resets_at: Option<&str>) -> Option<String> {
    if utilization <= 10.0 {
        return None;
    }

    let resets_at = resets_at?;
    let reset_dt = chrono::DateTime::parse_from_rfc3339(resets_at)
        .ok()?
        .with_timezone(&chrono::Utc);
    let now = chrono::Utc::now();

    let window_secs = 5.0 * 3600.0; // 5 hours
    let remaining_secs = (reset_dt - now).num_seconds() as f64;
    if remaining_secs <= 0.0 {
        return None;
    }

    let elapsed_secs = window_secs - remaining_secs;
    if elapsed_secs <= 0.0 {
        return None;
    }

    // Rate: utilization percent per second
    let rate = utilization / elapsed_secs;
    if rate <= 0.0 {
        return None;
    }

    let remaining_util = 100.0 - utilization;
    if remaining_util <= 0.0 {
        return Some("now".to_string());
    }

    let secs_to_limit = remaining_util / rate;
    // If projected time exceeds remaining window, won't reach limit
    if secs_to_limit > remaining_secs {
        return None;
    }

    let hours = (secs_to_limit / 3600.0) as u64;
    let mins = ((secs_to_limit % 3600.0) / 60.0) as u64;

    if hours > 0 {
        Some(format!("~{hours}h {mins:02}m"))
    } else {
        Some(format!("~{mins}m"))
    }
}

pub fn render(_ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let pcfg = cfg.pacing.as_ref();

    if let Some(c) = pcfg {
        if c.enabled == Some(false) {
            return None;
        }
    }

    let (tier, remaining) = current_pacing(cfg)?;

    let show_prediction = pcfg.and_then(|c| c.show_prediction).unwrap_or(true);

    let mut text = format!("{} {:.0}%", tier.icon(), remaining);

    if show_prediction {
        let ttl = cfg.usage_limits.as_ref().and_then(|c| c.ttl);
        if let Some(data) = usage_api::fetch_usage(ttl) {
            let util = data.five_hour.as_ref().and_then(|w| w.utilization);
            let resets = data.five_hour.as_ref().and_then(|w| w.resets_at.as_deref());
            if let (Some(u), Some(r)) = (util, resets) {
                if let Some(prediction) = predict_time_to_limit(u, Some(r)) {
                    text.push_str(&format!(" ({prediction})"));
                }
            }
        }
    }

    Some(ansi::styled(&text, Some(tier.style())))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tier_comfortable() {
        assert_eq!(calculate_tier(20.0, false), PaceTier::Comfortable);
    }

    #[test]
    fn tier_on_track() {
        assert_eq!(calculate_tier(45.0, false), PaceTier::OnTrack);
    }

    #[test]
    fn tier_elevated() {
        assert_eq!(calculate_tier(70.0, false), PaceTier::Elevated);
    }

    #[test]
    fn tier_hot() {
        assert_eq!(calculate_tier(85.0, false), PaceTier::Hot);
    }

    #[test]
    fn tier_runaway() {
        assert_eq!(calculate_tier(95.0, false), PaceTier::Runaway);
    }

    #[test]
    fn promo_halves_effective() {
        assert_eq!(calculate_tier(70.0, true), PaceTier::OnTrack);
        assert_eq!(calculate_tier(70.0, false), PaceTier::Elevated);
    }

    #[test]
    fn runaway_ignores_promo() {
        assert_eq!(calculate_tier(95.0, true), PaceTier::Runaway);
    }

    #[test]
    fn predict_low_util_returns_none() {
        assert_eq!(
            predict_time_to_limit(5.0, Some("2026-03-19T20:00:00+00:00")),
            None
        );
    }

    #[test]
    fn predict_no_reset_returns_none() {
        assert_eq!(predict_time_to_limit(50.0, None), None);
    }

    #[test]
    fn predict_high_util_returns_some() {
        // 50% used with 2.5h remaining in window → rate projects to 100% at exactly when window ends
        // At 50% in 2.5h, rate = 50/9000 = 0.00556%/s, remaining = 50%, time = 50/0.00556 = 9000s = 2.5h
        // Since secs_to_limit == remaining_secs, it won't reach (> check). Let's use higher util.
        // 70% used with 2h remaining → elapsed = 3h = 10800s, rate = 70/10800 = 0.00648%/s
        // remaining_util = 30, secs_to_limit = 30/0.00648 = 4629s ≈ 1h17m < 7200s remaining → should return
        let reset = (chrono::Utc::now() + chrono::Duration::hours(2)).to_rfc3339();
        let result = predict_time_to_limit(70.0, Some(&reset));
        assert!(result.is_some());
        let text = result.unwrap();
        assert!(text.starts_with('~'));
    }

    #[test]
    fn predict_wont_reach_limit() {
        // 11% used with only 10min elapsed (4h50m remaining) → rate would project to 330% in 5h
        // but we need a case where it WON'T reach. Use: 11% with 4h59m remaining (1 min elapsed)
        // rate = 11/60 = 0.183%/s, remaining = 89%, time = 89/0.183 = 486s = 8.1m
        // 8.1m < 299min remaining, so it WOULD still project. Let's use a truly slow rate:
        // 11% with 5min remaining → elapsed = 4h55m = 17700s, rate = 11/17700 = 0.000621%/s
        // remaining_util = 89, secs = 89/0.000621 = 143,318s = ~39.8h >> 300s remaining → None
        let reset = (chrono::Utc::now() + chrono::Duration::minutes(5)).to_rfc3339();
        let result = predict_time_to_limit(11.0, Some(&reset));
        assert!(result.is_none());
    }
}
