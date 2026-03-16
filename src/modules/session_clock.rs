use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;

/// Displays elapsed session time based on cost.total_duration_ms.
pub fn render(ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let duration_ms = ctx.cost.as_ref()?.total_duration_ms?;

    let secs = duration_ms / 1000;
    let mins = secs / 60;
    let hours = mins / 60;

    let text = if hours > 0 {
        format!("{}h{:02}m", hours, mins % 60)
    } else if mins > 0 {
        format!("{}m{:02}s", mins, secs % 60)
    } else {
        format!("{}s", secs)
    };

    let style = cfg.session_clock.as_ref().and_then(|c| c.style.as_deref());
    Some(ansi::styled(&text, style))
}
