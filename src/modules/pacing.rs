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

pub fn render(_ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let pcfg = cfg.pacing.as_ref();

    if let Some(c) = pcfg {
        if c.enabled == Some(false) {
            return None;
        }
    }

    let (tier, remaining) = current_pacing(cfg)?;

    let text = format!("{} {:.0}%", tier.icon(), remaining);

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
}
