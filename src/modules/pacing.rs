use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;
use crate::promo;
use crate::usage_api;

/// 6-tier pacing assessment.
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
    pub fn emoji(&self) -> &'static str {
        match self {
            PaceTier::Comfortable => "🟢",
            PaceTier::OnTrack => "🔵",
            PaceTier::Elevated => "🟡",
            PaceTier::Hot => "🟠",
            PaceTier::Critical => "🔴",
            PaceTier::Runaway => "⛔",
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
}

/// Calculate pace ratio from utilization.
/// pace_ratio = actual_usage / max(expected_usage, 1)
/// where expected_usage = elapsed_fraction * 100
///
/// Since we don't have window start time from the API, we use
/// utilization directly as the pacing signal, adjusted for promo.
pub fn calculate_tier(utilization: f64, promo_active: bool) -> PaceTier {
    // Runaway is absolute, not relative
    if utilization > 90.0 {
        return PaceTier::Runaway;
    }

    // When promo is active, effective capacity doubles
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

pub fn render(_ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let pcfg = cfg.pacing.as_ref();

    if let Some(c) = pcfg {
        if c.enabled == Some(false) {
            return None;
        }
    }

    let ttl = cfg.usage_limits.as_ref().and_then(|c| c.ttl);
    let data = match usage_api::fetch_usage(ttl) {
        Some(d) => d,
        None => {
            tracing::debug!("pacing: no usage data available");
            return None;
        }
    };

    let utilization = data.five_hour.as_ref().and_then(|w| w.utilization)?;

    let promo_aware = pcfg.map(|c| c.promo_aware.unwrap_or(true)).unwrap_or(true);
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
    let text = format!("{} {}", tier.emoji(), tier.label());

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
        // 70% with promo -> effective 35% -> OnTrack
        assert_eq!(calculate_tier(70.0, true), PaceTier::OnTrack);
        // 70% without promo -> Elevated
        assert_eq!(calculate_tier(70.0, false), PaceTier::Elevated);
    }

    #[test]
    fn runaway_ignores_promo() {
        // 95% is Runaway regardless of promo
        assert_eq!(calculate_tier(95.0, true), PaceTier::Runaway);
    }
}
