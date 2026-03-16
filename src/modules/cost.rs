use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;

pub fn render(ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let cost = match &ctx.cost {
        Some(c) => c,
        None => {
            tracing::warn!("cost: no cost data in context");
            return None;
        }
    };

    let usd = match cost.total_cost_usd {
        Some(v) => v,
        None => {
            tracing::warn!("cost: no total_cost_usd");
            return None;
        }
    };

    let ccfg = cfg.cost.as_ref();
    let symbol = ccfg.and_then(|c| c.symbol.as_deref()).unwrap_or("$ ");

    let text = if usd < 0.01 {
        format!("{symbol}{usd:.3}")
    } else {
        format!("{symbol}{usd:.2}")
    };

    let style = ccfg.and_then(|c| {
        ansi::threshold_style(
            usd,
            c.warn_threshold,
            c.warn_style.as_deref(),
            c.critical_threshold,
            c.critical_style.as_deref(),
            c.style.as_deref(),
        )
    });

    Some(ansi::styled(&text, style))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context;

    #[test]
    fn render_cost() {
        let ctx = context::parse_str(r#"{"cost":{"total_cost_usd":1.23}}"#);
        let cfg = SondeConfig::default();
        let result = render(&ctx, &cfg).unwrap();
        assert!(result.contains("1.23"));
    }

    #[test]
    fn render_small_cost() {
        let ctx = context::parse_str(r#"{"cost":{"total_cost_usd":0.003}}"#);
        let cfg = SondeConfig::default();
        let result = render(&ctx, &cfg).unwrap();
        assert!(result.contains("0.003"));
    }

    #[test]
    fn render_no_cost() {
        let ctx = context::parse_str(r#"{}"#);
        let cfg = SondeConfig::default();
        assert!(render(&ctx, &cfg).is_none());
    }
}
