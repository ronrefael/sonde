use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;

/// Displays the active agent name (e.g., "security-reviewer").
pub fn render(ctx: &Context, _cfg: &SondeConfig) -> Option<String> {
    let name = ctx.agent.as_ref()?.name.as_deref()?;
    Some(ansi::styled(&format!("⚙ {name}"), Some("fg:#c0a0ff")))
}
