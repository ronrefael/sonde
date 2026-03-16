use nu_ansi_term::{Color, Style};

/// Parse a style string like "bold cyan", "fg:#7dcfff", "bold fg:#f7768e" into a Style.
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

/// Apply a style string to text. Returns unstyled text if style is empty/None.
pub fn styled(text: &str, style_str: Option<&str>) -> String {
    match style_str {
        Some(s) if !s.is_empty() => {
            let style = parse_style(s);
            style.paint(text).to_string()
        }
        _ => text.to_string(),
    }
}

/// Pick style based on threshold values.
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
}
