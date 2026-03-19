use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;
use crate::modules::codex_cost;
use crate::modules::cursor;

pub fn render(ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let claude_cost = ctx.cost.as_ref()?.total_cost_usd?;

    let codex = codex_cost::get_latest_session_cost(cfg).unwrap_or(0.0);

    let cursor = cursor::get_latest_session_cost(cfg).unwrap_or(0.0);

    let total = claude_cost + codex + cursor;
    let text = format!("Total: ${total:.2}");

    let style = if total >= 5.0 {
        Some("bold fg:#f7768e")
    } else if total >= 2.0 {
        Some("fg:#e0af68")
    } else {
        Some("fg:#a9b1d6")
    };

    Some(ansi::styled(&text, style))
}
