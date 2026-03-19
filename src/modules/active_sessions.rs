use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;

pub fn render(_ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let output = std::process::Command::new("pgrep")
        .args(["-f", "claude"])
        .output()
        .ok()?;

    let count = if output.status.success() {
        String::from_utf8_lossy(&output.stdout).lines().count()
    } else {
        0
    };

    if count <= 1 {
        return None;
    }

    let style = cfg
        .active_sessions
        .as_ref()
        .and_then(|c| c.style.as_deref());
    let text = format!("{count} sessions");
    Some(ansi::styled(&text, style))
}
