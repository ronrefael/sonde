use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;

pub fn render(ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let cwd = ctx.cwd.as_deref()?;

    let output = std::process::Command::new("git")
        .args(["rev-parse", "--abbrev-ref", "HEAD"])
        .current_dir(cwd)
        .output()
        .ok()?;

    if !output.status.success() {
        return None;
    }

    let branch = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if branch.is_empty() {
        return None;
    }

    let gcfg = cfg.git_branch.as_ref();
    let symbol = gcfg.and_then(|c| c.symbol.as_deref()).unwrap_or("\u{e0a0} ");
    let style = gcfg.and_then(|c| c.style.as_deref());

    let text = format!("{symbol}{branch}");
    Some(ansi::styled(&text, style))
}
