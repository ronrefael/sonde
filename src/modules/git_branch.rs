use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;

pub fn render(ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    // Prefer branch from context (already provided by Claude Code) over subprocess
    let branch = if let Some(ref wt) = ctx.worktree {
        wt.branch.clone()
    } else {
        None
    };

    let branch = branch.or_else(|| {
        let cwd = ctx.cwd.as_deref()?;
        let output = std::process::Command::new("git")
            .args(["rev-parse", "--abbrev-ref", "HEAD"])
            .current_dir(cwd)
            .output()
            .ok()?;
        if !output.status.success() {
            return None;
        }
        let b = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if b.is_empty() {
            None
        } else {
            Some(b)
        }
    })?;

    // Truncate long branch names for display
    let branch = if branch.chars().count() > 30 {
        format!("{}...", branch.chars().take(27).collect::<String>())
    } else {
        branch
    };

    let gcfg = cfg.git_branch.as_ref();
    let default_sym = if ansi::has_nerd_fonts() {
        "\u{f126} "
    } else {
        ""
    };
    let symbol = gcfg
        .and_then(|c| c.symbol.as_deref())
        .unwrap_or(default_sym);
    let style = gcfg.and_then(|c| c.style.as_deref());

    let text = format!("{symbol}{branch}");
    Some(ansi::styled(&text, style))
}
