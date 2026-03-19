use crate::ansi;
use crate::config::{self, SondeConfig};
use crate::context::Context;
use crate::modules;

/// Format: "$sonde.model $sonde.cost some_literal_text $sonde.context_bar"
pub fn render_line(line: &str, ctx: &Context, cfg: &SondeConfig) -> String {
    let mut result = String::new();
    let mut chars = line.chars().peekable();

    while let Some(&ch) = chars.peek() {
        if ch == '$' {
            if let Some(name) = consume_token_name(&mut chars) {
                if let Some(rendered) = modules::render_module(&name, ctx, cfg) {
                    if !result.is_empty() && !result.ends_with(' ') {
                        result.push(' ');
                    }
                    result.push_str(&rendered);
                }
            }
        } else if ch == ' ' {
            chars.next();
            if !result.is_empty() {
                result.push(' ');
            }
        } else {
            result.push(ch);
            chars.next();
        }
    }

    result.trim().to_string()
}

/// Consume a `$sonde.xxx` token name from a peekable char iterator.
/// Advances past the `$` and all following alphanumeric/dot/underscore chars.
fn consume_token_name(chars: &mut std::iter::Peekable<std::str::Chars>) -> Option<String> {
    chars.next(); // consume '$'
    let mut name = String::new();
    while let Some(&c) = chars.peek() {
        if c.is_alphanumeric() || c == '.' || c == '_' {
            name.push(c);
            chars.next();
        } else {
            break;
        }
    }
    if name.is_empty() {
        None
    } else {
        Some(name)
    }
}

fn extract_module_names(line: &str) -> Vec<String> {
    let mut names = Vec::new();
    let mut chars = line.chars().peekable();

    while let Some(&ch) = chars.peek() {
        if ch == '$' {
            if let Some(name) = consume_token_name(&mut chars) {
                names.push(name);
            }
        } else {
            chars.next();
        }
    }

    names
}

fn module_priority(name: &str) -> u8 {
    match name {
        "sonde.model" => 1,
        "sonde.cost" => 1,
        "sonde.context_bar" => 2,
        "sonde.usage_limits" => 2,
        "sonde.promo_badge" => 3,
        "sonde.pacing" => 3,
        "sonde.git_branch" => 4,
        "sonde.session_clock" => 4,
        "sonde.codex_cost" => 4,
        "sonde.combined_spend" => 4,
        "sonde.active_sessions" => 5,
        "sonde.model_suggestion" => 5,
        "sonde.context_window" => 5,
        "sonde.agent" => 2,
        "sonde.worktree" => 3,
        "sonde.mascot_icon" => 0, // highest priority — always visible
        "sonde.windsurf_cost" => 4,
        "sonde.copilot_cost" => 4,
        "sonde.gemini_cost" => 4,
        _ => 6,
    }
}

fn abbreviate(text: &str) -> String {
    let mut result = String::new();
    let mut depth = 0;
    for ch in text.chars() {
        match ch {
            '(' => depth += 1,
            ')' => {
                if depth > 0 {
                    depth -= 1;
                }
            }
            _ if depth == 0 => result.push(ch),
            _ => {}
        }
    }
    let mut result = result.trim().to_string();
    while result.contains("  ") {
        result = result.replace("  ", " ");
    }

    result
        .replace("Comfortable", "OK")
        .replace("On Track", "OK")
        .replace("Elevated", "Warn")
        .replace("Critical", "Crit")
        .replace("Runaway", "Over")
        .replace("Off-peak limits active", "2X")
}

struct Candidate {
    name: String,
    text: String,
    priority: u8,
}

/// Detect terminal width dynamically.
/// Priority: stderr (correct pane width in split terminals) → COLUMNS → /dev/tty → fallback.
fn get_terminal_width() -> usize {
    #[cfg(unix)]
    {
        use std::os::unix::io::{AsRawFd, BorrowedFd};

        // 1. stderr — most accurate for split panes, Claude Code leaves it connected to the pane PTY
        let stderr_fd = unsafe { BorrowedFd::borrow_raw(2) };
        if let Some((terminal_size::Width(w), _)) = terminal_size::terminal_size_of(stderr_fd) {
            return w as usize;
        }

        // 2. COLUMNS env var (shell sets this per-pane)
        if let Ok(cols) = std::env::var("COLUMNS") {
            if let Ok(w) = cols.parse::<usize>() {
                if w > 0 {
                    return w;
                }
            }
        }

        // 3. /dev/tty — last resort, may return full window width (wrong for split panes)
        if let Ok(tty) = std::fs::File::open("/dev/tty") {
            let fd = unsafe { BorrowedFd::borrow_raw(tty.as_raw_fd()) };
            if let Some((terminal_size::Width(w), _)) = terminal_size::terminal_size_of(fd) {
                return w as usize;
            }
        }
    }

    #[cfg(not(unix))]
    {
        if let Ok(cols) = std::env::var("COLUMNS") {
            if let Ok(w) = cols.parse::<usize>() {
                if w > 0 {
                    return w;
                }
            }
        }
    }

    // 4. Fallback
    80
}

fn usable_width() -> usize {
    let w = get_terminal_width();
    w.saturating_sub(2)
}

fn build_powerline_segments(
    candidates: &[Candidate],
    cfg: &SondeConfig,
    theme: &str,
) -> Vec<ansi::PowerlineSegment> {
    candidates
        .iter()
        .map(|c| {
            let (fg, bg) = if c.name == "sonde.pacing" {
                let palette = crate::themes::get_palette(theme);
                match modules::pacing::current_pacing(cfg) {
                    Some((tier, _)) => (palette.base, tier.powerline_bg()),
                    None => ansi::powerline_colors_for_theme(theme, &c.name),
                }
            } else {
                ansi::powerline_colors_for_theme(theme, &c.name)
            };
            ansi::PowerlineSegment {
                text: c.text.clone(),
                fg,
                bg,
            }
        })
        .collect()
}

/// Render a format line in powerline style with auto-compact.
fn render_line_powerline(line: &str, ctx: &Context, cfg: &SondeConfig, theme: &str) -> String {
    let module_names = extract_module_names(line);
    let mut candidates: Vec<Candidate> = Vec::new();

    for name in &module_names {
        if let Some(rendered) = modules::render_module(name, ctx, cfg) {
            let text = ansi::strip_ansi(&rendered);
            if text.trim().is_empty() {
                continue;
            }
            candidates.push(Candidate {
                name: name.clone(),
                text,
                priority: module_priority(name),
            });
        }
    }

    if candidates.is_empty() {
        return String::new();
    }

    let term_width = usable_width();
    let segments = build_powerline_segments(&candidates, cfg, theme);
    let current_width = ansi::powerline_width(&segments);

    if current_width <= term_width {
        return ansi::render_powerline(&segments);
    }

    // Phase 1: Abbreviate all text first (cheapest compaction)
    for c in &mut candidates {
        c.text = abbreviate(&c.text);
    }

    let segments = build_powerline_segments(&candidates, cfg, theme);
    if ansi::powerline_width(&segments) <= term_width {
        return ansi::render_powerline(&segments);
    }

    // Phase 2: Drop lowest-priority segments until it fits
    loop {
        let segments = build_powerline_segments(&candidates, cfg, theme);
        if ansi::powerline_width(&segments) <= term_width || candidates.len() <= 1 {
            return ansi::render_powerline(&segments);
        }

        // Find the highest priority number (= lowest importance) and remove last such entry
        let Some(max_pri) = candidates.iter().map(|c| c.priority).max() else {
            return ansi::render_powerline(&build_powerline_segments(&candidates, cfg, theme));
        };
        if let Some(pos) = candidates.iter().rposition(|c| c.priority == max_pri) {
            candidates.remove(pos);
        }
    }
}

pub fn render(ctx: &Context, cfg: &SondeConfig) -> String {
    let theme = cfg.theme.as_deref().unwrap_or("powerline");
    let is_powerline = theme != "plain";

    let lines = cfg.lines.as_ref().cloned().unwrap_or_else(|| {
        if is_powerline {
            config::default_powerline_lines()
        } else {
            config::default_lines()
        }
    });

    let rendered: Vec<String> = lines
        .iter()
        .map(|line| {
            if is_powerline {
                render_line_powerline(line, ctx, cfg, theme)
            } else {
                render_line(line, ctx, cfg)
            }
        })
        .filter(|line| !line.is_empty())
        .collect();

    rendered.join("\n")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context;

    #[test]
    fn render_model_and_cost() {
        let ctx = context::parse_str(
            r#"{"model":{"display_name":"Opus"},"cost":{"total_cost_usd":1.23}}"#,
        );
        let cfg = SondeConfig::default();
        let line = render_line("$sonde.model $sonde.cost", &ctx, &cfg);
        assert!(line.contains("Opus"));
        assert!(line.contains("1.23"));
    }

    #[test]
    fn missing_module_silently_omitted() {
        let ctx = context::parse_str(r#"{"model":{"display_name":"Opus"}}"#);
        let cfg = SondeConfig::default();
        let line = render_line("$sonde.model $sonde.cost", &ctx, &cfg);
        assert!(line.contains("Opus"));
        assert!(!line.contains("cost"));
    }

    #[test]
    fn unknown_module_silently_omitted() {
        let ctx = context::parse_str(r#"{"model":{"display_name":"Opus"}}"#);
        let cfg = SondeConfig::default();
        let line = render_line("$sonde.model $sonde.nonexistent", &ctx, &cfg);
        assert!(line.contains("Opus"));
    }

    #[test]
    fn extract_modules_from_line() {
        let names = extract_module_names("$sonde.model $sonde.cost $sonde.pacing");
        assert_eq!(names, vec!["sonde.model", "sonde.cost", "sonde.pacing"]);
    }

    #[test]
    fn powerline_renders_segments() {
        let ctx = context::parse_str(
            r#"{"model":{"display_name":"Opus"},"cost":{"total_cost_usd":0.53}}"#,
        );
        let mut cfg = SondeConfig::default();
        cfg.theme = Some("powerline".to_string());
        let output = render(&ctx, &cfg);
        let plain = ansi::strip_ansi(&output);
        assert!(plain.contains("Opus"));
        assert!(output.contains('\u{e0b0}'));
    }

    #[test]
    fn plain_theme_unchanged() {
        let ctx = context::parse_str(
            r#"{"model":{"display_name":"Opus"},"cost":{"total_cost_usd":1.23}}"#,
        );
        let mut cfg = SondeConfig::default();
        cfg.theme = Some("plain".to_string());
        let output = render(&ctx, &cfg);
        assert!(!output.contains('\u{e0b0}'));
    }

    #[test]
    fn abbreviate_removes_parens() {
        assert_eq!(abbreviate("5h 18% (3h13m)"), "5h 18%");
        assert_eq!(
            abbreviate("5h 18% (3h13m) 7d 44% (76h13m)"),
            "5h 18% 7d 44%"
        );
    }

    #[test]
    fn abbreviate_shortens_labels() {
        assert_eq!(abbreviate("🟢 Comfortable"), "🟢 OK");
        assert_eq!(abbreviate("🔴 Critical"), "🔴 Crit");
    }

    #[test]
    fn module_priorities_correct() {
        assert!(module_priority("sonde.model") < module_priority("sonde.pacing"));
        assert!(module_priority("sonde.cost") < module_priority("sonde.git_branch"));
        assert!(module_priority("sonde.context_bar") < module_priority("sonde.active_sessions"));
    }
}
