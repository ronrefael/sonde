use nu_ansi_term::{Color, Style};
use unicode_width::UnicodeWidthStr;

/// Parse a style string like "bold cyan", "fg:#7dcfff", "bold fg:#f7768e".
pub fn parse_style(style_str: &str) -> Style {
    let mut style = Style::new();

    for token in style_str.split_whitespace() {
        match token {
            "bold" => style = style.bold(),
            "italic" => style = style.italic(),
            "underline" => style = style.underline(),
            "dimmed" | "dim" => style = style.dimmed(),
            "strikethrough" => style = style.strikethrough(),
            "blink" => style = style.blink(),
            "hidden" => style = style.hidden(),
            "reverse" => style = style.reverse(),
            // Named colors
            "black" => style = style.fg(Color::Black),
            "red" => style = style.fg(Color::Red),
            "green" => style = style.fg(Color::Green),
            "yellow" => style = style.fg(Color::Yellow),
            "blue" => style = style.fg(Color::Blue),
            "purple" | "magenta" => style = style.fg(Color::Purple),
            "cyan" => style = style.fg(Color::Cyan),
            "white" => style = style.fg(Color::White),
            // Hex colors: fg:#rrggbb or just #rrggbb
            s if s.starts_with("fg:#") => {
                if let Some(color) = parse_hex(&s[4..]) {
                    style = style.fg(color);
                }
            }
            s if s.starts_with("bg:#") => {
                if let Some(color) = parse_hex(&s[4..]) {
                    style = style.on(color);
                }
            }
            s if s.starts_with('#') => {
                if let Some(color) = parse_hex(&s[1..]) {
                    style = style.fg(color);
                }
            }
            _ => {
                tracing::debug!("Unknown style token: {token}");
            }
        }
    }

    style
}

fn parse_hex(hex: &str) -> Option<Color> {
    if hex.len() != 6 {
        return None;
    }
    let r = u8::from_str_radix(&hex[0..2], 16).ok()?;
    let g = u8::from_str_radix(&hex[2..4], 16).ok()?;
    let b = u8::from_str_radix(&hex[4..6], 16).ok()?;
    Some(Color::Rgb(r, g, b))
}

pub fn styled(text: &str, style_str: Option<&str>) -> String {
    match style_str {
        Some(s) if !s.is_empty() => {
            let style = parse_style(s);
            style.paint(text).to_string()
        }
        _ => text.to_string(),
    }
}

/// Returns the style string for the highest threshold crossed, or the default.
pub fn threshold_style<'a>(
    value: f64,
    warn_threshold: Option<f64>,
    warn_style: Option<&'a str>,
    critical_threshold: Option<f64>,
    critical_style: Option<&'a str>,
    default_style: Option<&'a str>,
) -> Option<&'a str> {
    if let (Some(ct), Some(cs)) = (critical_threshold, critical_style) {
        if value >= ct {
            return Some(cs);
        }
    }
    if let (Some(wt), Some(ws)) = (warn_threshold, warn_style) {
        if value >= wt {
            return Some(ws);
        }
    }
    default_style
}

/// Only handles CSI sequences (ESC [ ... letter) — sufficient for nu-ansi-term output.
pub fn strip_ansi(s: &str) -> String {
    let mut result = String::new();
    let mut chars = s.chars().peekable();
    while let Some(ch) = chars.next() {
        if ch == '\x1b' {
            if chars.peek() == Some(&'[') {
                chars.next();
                while let Some(&c) = chars.peek() {
                    chars.next();
                    if c.is_ascii_alphabetic() {
                        break;
                    }
                }
            }
        } else {
            result.push(ch);
        }
    }
    result
}

pub struct PowerlineSegment {
    pub text: String,
    pub fg: Color,
    pub bg: Color,
}

pub fn display_width(text: &str) -> usize {
    UnicodeWidthStr::width(text)
}

/// Each segment = 1 pad + text + 1 pad + 1 arrow separator.
pub fn powerline_width(segments: &[PowerlineSegment]) -> usize {
    if segments.is_empty() {
        return 0;
    }
    let content: usize = segments.iter().map(|s| display_width(&s.text) + 2).sum();
    content + segments.len()
}

pub fn render_powerline(segments: &[PowerlineSegment]) -> String {
    if segments.is_empty() {
        return String::new();
    }

    let mut out = String::new();

    for (i, seg) in segments.iter().enumerate() {
        let body = Style::new()
            .fg(seg.fg)
            .on(seg.bg)
            .paint(format!(" {} ", seg.text));
        out.push_str(&body.to_string());

        // Arrow: current bg → next bg creates the angled transition effect
        if i + 1 < segments.len() {
            let arrow = Style::new()
                .fg(seg.bg)
                .on(segments[i + 1].bg)
                .paint("\u{e0b0}");
            out.push_str(&arrow.to_string());
        } else {
            let arrow = Style::new().fg(seg.bg).paint("\u{e0b0}");
            out.push_str(&arrow.to_string());
        }
    }

    out
}

/// Backward-compat wrapper — returns Catppuccin Mocha colors.
#[allow(dead_code)]
pub fn default_powerline_colors(module_name: &str) -> (Color, Color) {
    powerline_colors_for_theme("catppuccin-mocha", module_name)
}

/// Returns powerline (fg, bg) for a named theme palette.
pub fn powerline_colors_for_theme(theme: &str, module_name: &str) -> (Color, Color) {
    let palette = crate::themes::get_palette(theme);
    crate::themes::powerline_colors(palette, module_name)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_bold_cyan() {
        let style = parse_style("bold cyan");
        assert!(style.is_bold);
        let painted = style.paint("test").to_string();
        assert!(painted.contains("test"));
    }

    #[test]
    fn parse_hex_color() {
        let color = parse_hex("7dcfff").unwrap();
        assert!(matches!(color, Color::Rgb(125, 207, 255)));
    }

    #[test]
    fn threshold_picks_critical() {
        let s = threshold_style(
            85.0,
            Some(60.0),
            Some("yellow"),
            Some(80.0),
            Some("red"),
            Some("green"),
        );
        assert_eq!(s, Some("red"));
    }

    #[test]
    fn threshold_picks_warn() {
        let s = threshold_style(
            65.0,
            Some(60.0),
            Some("yellow"),
            Some(80.0),
            Some("red"),
            Some("green"),
        );
        assert_eq!(s, Some("yellow"));
    }

    #[test]
    fn threshold_picks_default() {
        let s = threshold_style(
            30.0,
            Some(60.0),
            Some("yellow"),
            Some(80.0),
            Some("red"),
            Some("green"),
        );
        assert_eq!(s, Some("green"));
    }

    #[test]
    fn strip_ansi_removes_codes() {
        let styled = "\x1b[1;36m Opus\x1b[0m";
        assert_eq!(strip_ansi(styled), " Opus");
    }

    #[test]
    fn strip_ansi_plain_passthrough() {
        assert_eq!(strip_ansi("hello world"), "hello world");
    }

    #[test]
    fn powerline_renders_segments() {
        let segs = vec![
            PowerlineSegment {
                text: "A".to_string(),
                fg: Color::Black,
                bg: Color::Red,
            },
            PowerlineSegment {
                text: "B".to_string(),
                fg: Color::Black,
                bg: Color::Blue,
            },
        ];
        let result = render_powerline(&segs);
        assert!(result.contains('A'));
        assert!(result.contains('B'));
        assert!(result.contains('\u{e0b0}'));
    }
}
