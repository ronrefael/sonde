use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;
use crate::promo;

pub fn render(_ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let pcfg = cfg.promo_badge.as_ref();

    // Check if disabled
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

    let emoji = status.emoji.as_deref().unwrap_or("");
    let label = status.label.as_deref().unwrap_or("");

    let fmt = pcfg
        .and_then(|c| c.badge_format.as_deref())
        .unwrap_or("{emoji}{label}");

    let text = fmt.replace("{emoji}", emoji).replace("{label}", label);

    if text.trim().is_empty() {
        return None;
    }

    let is_offpeak = status.is_offpeak.unwrap_or(false);
    let style_str = if is_offpeak {
        pcfg.and_then(|c| c.style.as_deref())
    } else {
        Some("dim")
    };

    Some(ansi::styled(&text, style_str))
}
