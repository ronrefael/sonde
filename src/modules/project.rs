use crate::ansi;
use crate::config::SondeConfig;
use crate::context::Context;

pub fn render(ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    let pcfg = cfg.project.as_ref();

    if let Some(c) = pcfg {
        if c.enabled == Some(false) {
            return None;
        }
    }

    // Try workspace.project_dir first, then fall back to cwd
    let name = match ctx.workspace.as_ref().and_then(|w| w.project_dir.as_deref()) {
        Some(dir) => extract_last_component(dir),
        None => match ctx.cwd.as_deref() {
            Some(dir) => extract_last_component(dir),
            None => {
                tracing::warn!("project: no workspace or cwd available");
                return None;
            }
        },
    };

    match name {
        Some(n) => {
            let default_sym = if ansi::has_nerd_fonts() { "\u{f07b} " } else { "" };
            let symbol = pcfg.and_then(|c| c.symbol.as_deref()).unwrap_or(default_sym);
            let style = pcfg.and_then(|c| c.style.as_deref());
            let text = if symbol.is_empty() {
                n.to_string()
            } else {
                format!("{symbol}{n}")
            };
            Some(ansi::styled(&text, style))
        }
        None => {
            tracing::warn!("project: could not extract project name from path");
            None
        }
    }
}

fn extract_last_component(path: &str) -> Option<&str> {
    std::path::Path::new(path)
        .file_name()
        .and_then(|s| s.to_str())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::SondeConfig;
    use crate::context::parse_str;

    #[test]
    fn renders_project_from_workspace() {
        let ctx = parse_str(
            r#"{"workspace":{"project_dir":"/Users/dev/projects/my-app"},"cwd":"/tmp"}"#,
        );
        let cfg = SondeConfig::default();
        let result = render(&ctx, &cfg);
        let text = result.unwrap();
        assert!(text.contains("my-app"));
    }

    #[test]
    fn falls_back_to_cwd() {
        let ctx = parse_str(r#"{"cwd":"/home/user/code/sonde"}"#);
        let cfg = SondeConfig::default();
        let result = render(&ctx, &cfg);
        let text = result.unwrap();
        assert!(text.contains("sonde"));
    }

    #[test]
    fn returns_none_when_no_data() {
        let ctx = parse_str(r#"{}"#);
        let cfg = SondeConfig::default();
        let result = render(&ctx, &cfg);
        assert!(result.is_none());
    }

    #[test]
    fn prefers_workspace_over_cwd() {
        let ctx = parse_str(
            r#"{"workspace":{"project_dir":"/a/b/workspace-proj"},"cwd":"/x/y/cwd-proj"}"#,
        );
        let cfg = SondeConfig::default();
        let result = render(&ctx, &cfg);
        let text = result.unwrap();
        assert!(text.contains("workspace-proj"));
    }

    #[test]
    fn extract_last_component_works() {
        assert_eq!(extract_last_component("/foo/bar/baz"), Some("baz"));
        assert_eq!(extract_last_component("/"), None);
        assert_eq!(extract_last_component("single"), Some("single"));
    }
}
