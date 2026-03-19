use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;

pub fn render(ctx: &Context, _cfg: &SondeConfig) -> Option<String> {
    let wt = ctx.worktree.as_ref()?;
    let name = wt.name.as_deref()?;
    Some(ansi::styled(&format!("⎇ {name}"), Some("fg:#f0a050")))
}
