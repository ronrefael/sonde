use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;

pub fn render(ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let cw = match &ctx.context_window {
        Some(cw) => cw,
        None => {
            tracing::warn!("context_bar: no context_window data");
            return None;
        }
    };

    let pct = match cw.used_percentage {
        Some(p) => p,
        None => {
            tracing::warn!("context_bar: no used_percentage");
            return None;
        }
    };

    let bcfg = cfg.context_bar.as_ref();
    let width = bcfg.and_then(|c| c.width).unwrap_or(10) as usize;

    let filled = ((pct / 100.0) * width as f64).round() as usize;
    let filled = filled.min(width);
    let empty = width - filled;

    let icon = if ansi::has_nerd_fonts() { "\u{f1c0} " } else { "" };
    let bar = format!("{icon}[{}{}] {:.0}%", "━".repeat(filled), "╌".repeat(empty), pct);

    let style = bcfg.and_then(|c| {
        ansi::threshold_style(
            pct,
            c.warn_threshold,
            c.warn_style.as_deref(),
            c.critical_threshold,
            c.critical_style.as_deref(),
            c.style.as_deref(),
        )
    });

    Some(ansi::styled(&bar, style))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context;

    #[test]
    fn render_bar_42_percent() {
        let ctx = context::parse_str(
            r#"{"context_window":{"used_percentage":42.0,"context_window_size":200000}}"#,
        );
        let cfg = SondeConfig::default();
        let result = render(&ctx, &cfg).unwrap();
        assert!(result.contains("42%"));
        assert!(result.contains('['));
        assert!(result.contains(']'));
    }

    #[test]
    fn render_bar_empty() {
        let ctx = context::parse_str(r#"{"context_window":{"used_percentage":0.0}}"#);
        let cfg = SondeConfig::default();
        let result = render(&ctx, &cfg).unwrap();
        assert!(result.contains("0%"));
    }

    #[test]
    fn render_no_data() {
        let ctx = context::parse_str(r#"{}"#);
        let cfg = SondeConfig::default();
        assert!(render(&ctx, &cfg).is_none());
    }
}
