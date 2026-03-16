use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;

pub fn render(ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let cw = match &ctx.context_window {
        Some(cw) => cw,
        None => {
            tracing::warn!("context_window: no context_window data");
            return None;
        }
    };

    let total_in = cw.total_input_tokens.unwrap_or(0);
    let total_out = cw.total_output_tokens.unwrap_or(0);
    let total = total_in + total_out;
    let size = cw.context_window_size.unwrap_or(200_000);

    let text = format!("{}k/{}k", total / 1000, size / 1000);

    let pct = cw.used_percentage.unwrap_or(0.0);
    let cwcfg = cfg.context_window.as_ref();
    let style = cwcfg.and_then(|c| {
        ansi::threshold_style(
            pct,
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
    fn render_context_window() {
        let ctx = context::parse_str(
            r#"{"context_window":{"total_input_tokens":15000,"total_output_tokens":5000,"context_window_size":200000,"used_percentage":10.0}}"#,
        );
        let cfg = SondeConfig::default();
        let result = render(&ctx, &cfg).unwrap();
        assert!(result.contains("20k/200k"));
    }
}
