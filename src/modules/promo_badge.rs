use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;
use crate::promo;

fn nerd_icon(emoji: &str) -> &str {
    match emoji {
        "🟢" => "\u{f0e7}", //  bolt
        "🔴" => "\u{f00d}", //  times
        "🟡" => "\u{f017}", //  clock
        _ => emoji,
    }
}

fn format_countdown(minutes: u64) -> String {
    let hours = minutes / 60;
    let mins = minutes % 60;
    if hours > 0 {
        format!("{hours}h{mins:02}m")
    } else {
        format!("{mins}m")
    }
}

pub fn render(_ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let pcfg = cfg.promo_badge.as_ref();

    if let Some(c) = pcfg {
        if c.enabled == Some(false) {
            return None;
        }
    }

    let api_url = pcfg.and_then(|c| c.api_url.as_deref());
    let ttl = pcfg.and_then(|c| c.poll_interval);

    let status = match promo::fetch_promo(api_url, ttl) {
        Some(s) => s,
        None => {
            tracing::debug!("promo_badge: no promo data available");
            return None;
        }
    };

    let is_offpeak = status.is_offpeak.unwrap_or(false);
    let emoji = status.emoji.as_deref().unwrap_or("");
    let icon = nerd_icon(emoji);
    let label = status.label.as_deref().unwrap_or("");

    let countdown = status
        .minutes_until_change
        .map(format_countdown)
        .unwrap_or_default();

    let text = if is_offpeak {
        if countdown.is_empty() {
            format!("{icon} {label}")
        } else {
            format!("{icon} {label} \u{f017} {countdown} left")
        }
    } else {
        if countdown.is_empty() {
            return None;
        }
        format!("{icon} Off-peak in {countdown}")
    };

    if text.trim().is_empty() {
        return None;
    }

    let style_str = if is_offpeak {
        pcfg.and_then(|c| c.style.as_deref())
    } else {
        Some("dim")
    };

    Some(ansi::styled(&text, style_str))
}
