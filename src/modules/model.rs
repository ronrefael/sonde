use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;

pub fn render(ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let model = match &ctx.model {
        Some(m) => m,
        None => {
            tracing::warn!("model: no model data in context");
            return None;
        }
    };

    let name = model
        .display_name
        .as_deref()
        .or(model.id.as_deref())
        .unwrap_or("unknown");

    let mcfg = cfg.model.as_ref();
    let symbol = mcfg.and_then(|c| c.symbol.as_deref()).unwrap_or("");
    let style = mcfg.and_then(|c| c.style.as_deref());

    // Append context size indicator for large context models,
    // but only if the display name doesn't already include context info
    let display = if name.to_lowercase().contains("opus") && !name.contains("context") && !name.contains("1M") {
        if let Some(ref cw) = ctx.context_window {
            if let Some(size) = cw.context_window_size {
                if size >= 1_000_000 {
                    format!("{name} (1M)")
                } else {
                    name.to_string()
                }
            } else {
                name.to_string()
            }
        } else {
            name.to_string()
        }
    } else {
        name.to_string()
    };

    let text = format!("{symbol}{display}");
    Some(ansi::styled(&text, style))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context;

    #[test]
    fn render_model_name() {
        let ctx = context::parse_str(r#"{"model":{"display_name":"Opus","id":"claude-opus-4-6"}}"#);
        let cfg = SondeConfig::default();
        let result = render(&ctx, &cfg).unwrap();
        assert!(result.contains("Opus"));
    }

    #[test]
    fn render_fallback_to_id() {
        let ctx = context::parse_str(r#"{"model":{"id":"claude-opus-4-6"}}"#);
        let cfg = SondeConfig::default();
        let result = render(&ctx, &cfg).unwrap();
        assert!(result.contains("claude-opus-4-6"));
    }

    #[test]
    fn render_no_model() {
        let ctx = context::parse_str(r#"{}"#);
        let cfg = SondeConfig::default();
        assert!(render(&ctx, &cfg).is_none());
    }
}
