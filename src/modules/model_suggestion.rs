use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;
use crate::usage_api;

/// Suggests switching models at threshold crossings.
pub fn render(ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let model_name = ctx.model.as_ref()?.display_name.as_deref()?;

    // Only suggest for expensive models
    let is_expensive = matches!(
        model_name.to_lowercase().as_str(),
        "opus" | "opus 4" | "opus 4.6"
    );
    if !is_expensive {
        return None;
    }

    let ttl = cfg.usage_limits.as_ref().and_then(|c| c.ttl);
    let data = usage_api::fetch_usage(ttl)?;
    let utilization = data.five_hour.as_ref()?.utilization?;

    // Only suggest when usage is elevated
    if utilization < 60.0 {
        return None;
    }

    let suggestion = if utilization >= 80.0 {
        "Switch to Haiku for routine tasks"
    } else {
        "Consider Sonnet for lower-cost work"
    };

    Some(ansi::styled(suggestion, Some("italic yellow")))
}
