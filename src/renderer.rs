use crate::config::{self, SondeConfig};
use crate::context::Context;
use crate::modules;

/// Parse a format line and render all $sonde.xxx tokens.
///
/// Format: "$sonde.model $sonde.cost some_literal_text $sonde.context_bar"
/// Each $sonde.xxx token is dispatched to the module registry.
/// Tokens that return None are silently omitted.
pub fn render_line(line: &str, ctx: &Context, cfg: &SondeConfig) -> String {
    let mut result = String::new();
    let mut chars = line.chars().peekable();

    while let Some(&ch) = chars.peek() {
        if ch == '$' {
            chars.next(); // consume $
                          // Read the module name
            let mut name = String::new();
            while let Some(&c) = chars.peek() {
                if c.is_alphanumeric() || c == '.' || c == '_' {
                    name.push(c);
                    chars.next();
                } else {
                    break;
                }
            }

            if !name.is_empty() {
                if let Some(rendered) = modules::render_module(&name, ctx, cfg) {
                    if !result.is_empty() && !result.ends_with(' ') {
                        result.push(' ');
                    }
                    result.push_str(&rendered);
                }
            }
        } else {
            if ch == ' ' {
                chars.next();
                if !result.is_empty() {
                    result.push(' ');
                }
            } else {
                result.push(ch);
                chars.next();
            }
        }
    }

    result.trim().to_string()
}

/// Render all configured lines.
pub fn render(ctx: &Context, cfg: &SondeConfig) -> String {
    let lines = cfg
        .lines
        .as_ref()
        .cloned()
        .unwrap_or_else(config::default_lines);

    let rendered: Vec<String> = lines
        .iter()
        .map(|line| render_line(line, ctx, cfg))
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
}
