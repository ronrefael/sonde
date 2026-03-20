use std::io;

use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    prelude::CrosstermBackend,
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, Paragraph},
    Frame, Terminal,
};

use crate::ansi;
use crate::config;
use crate::themes;

const TEXT: Color = Color::Rgb(212, 232, 220);
const MUTED: Color = Color::Rgb(122, 154, 136);
const GREEN: Color = Color::Rgb(74, 222, 128);
const CYAN: Color = Color::Rgb(34, 211, 238);
const BG: Color = Color::Rgb(20, 20, 30);

#[derive(Clone, Copy, PartialEq)]
enum Panel {
    Themes,
    Modules,
}

struct ConfigState {
    panel: Panel,
    theme_idx: usize,
    module_idx: usize,
    modules: Vec<ModuleEntry>,
    theme_names: Vec<&'static str>,
}

#[derive(Clone)]
struct ModuleEntry {
    name: String,
    token: String,
    enabled: bool,
}

fn default_modules() -> Vec<ModuleEntry> {
    vec![
        ModuleEntry {
            name: "Model".into(),
            token: "$sonde.model".into(),
            enabled: true,
        },
        ModuleEntry {
            name: "Session Clock".into(),
            token: "$sonde.session_clock".into(),
            enabled: true,
        },
        ModuleEntry {
            name: "Context Bar".into(),
            token: "$sonde.context_bar".into(),
            enabled: true,
        },
        ModuleEntry {
            name: "Usage Limits".into(),
            token: "$sonde.usage_limits".into(),
            enabled: true,
        },
        ModuleEntry {
            name: "Pacing".into(),
            token: "$sonde.pacing".into(),
            enabled: true,
        },
        ModuleEntry {
            name: "Agent".into(),
            token: "$sonde.agent".into(),
            enabled: true,
        },
        ModuleEntry {
            name: "Worktree".into(),
            token: "$sonde.worktree".into(),
            enabled: true,
        },
        ModuleEntry {
            name: "Promo Badge".into(),
            token: "$sonde.promo_badge".into(),
            enabled: true,
        },
        ModuleEntry {
            name: "Context Window".into(),
            token: "$sonde.context_window".into(),
            enabled: false,
        },
        ModuleEntry {
            name: "Git Branch".into(),
            token: "$sonde.git_branch".into(),
            enabled: false,
        },
        ModuleEntry {
            name: "Active Sessions".into(),
            token: "$sonde.active_sessions".into(),
            enabled: false,
        },
        ModuleEntry {
            name: "Mascot Icon".into(),
            token: "$sonde.mascot_icon".into(),
            enabled: false,
        },
    ]
}

impl ConfigState {
    fn new() -> Self {
        Self {
            panel: Panel::Themes,
            theme_idx: 0,
            module_idx: 0,
            modules: default_modules(),
            theme_names: themes::ALL_THEME_NAMES.to_vec(),
        }
    }

    fn current_theme(&self) -> &'static str {
        self.theme_names[self.theme_idx]
    }

    fn generate_toml(&self) -> String {
        let theme = self.current_theme();
        let enabled_tokens: Vec<&str> = self
            .modules
            .iter()
            .filter(|m| m.enabled)
            .map(|m| m.token.as_str())
            .collect();

        // Split into lines: promo_badge on line 2 if enabled
        let (line1_tokens, line2_tokens): (Vec<&&str>, Vec<&&str>) = enabled_tokens
            .iter()
            .partition(|t| **t != "$sonde.promo_badge");

        let line1 = line1_tokens
            .iter()
            .map(|t| **t)
            .collect::<Vec<&str>>()
            .join(" ");
        let line2 = line2_tokens
            .iter()
            .map(|t| **t)
            .collect::<Vec<&str>>()
            .join(" ");

        let mut toml = format!("[sonde]\ntheme = \"{theme}\"\nlines = [\n");
        toml.push_str(&format!("  \"{line1}\",\n"));
        if !line2.is_empty() {
            toml.push_str(&format!("  \"{line2}\",\n"));
        }
        toml.push_str("]\n");
        toml
    }
}

fn draw(frame: &mut Frame, state: &ConfigState) {
    let area = frame.area();
    let bg = Block::default().style(Style::default().bg(BG));
    frame.render_widget(bg, area);

    let main_layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Header
            Constraint::Min(10),   // Main content
            Constraint::Length(5), // Preview
            Constraint::Length(1), // Footer
        ])
        .split(area);

    // Header
    let header = Paragraph::new(Line::from(vec![
        Span::styled(
            " sonde configure ",
            Style::default().fg(GREEN).add_modifier(Modifier::BOLD),
        ),
        Span::styled("— select theme and modules", Style::default().fg(MUTED)),
    ]))
    .block(
        Block::default()
            .borders(Borders::BOTTOM)
            .border_style(Style::default().fg(MUTED)),
    );
    frame.render_widget(header, main_layout[0]);

    // 3-column layout
    let cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(30),
            Constraint::Percentage(40),
            Constraint::Percentage(30),
        ])
        .split(main_layout[1]);

    draw_theme_list(frame, state, cols[0]);
    draw_module_list(frame, state, cols[1]);
    draw_toml_preview(frame, state, cols[2]);

    // Live powerline preview
    draw_powerline_preview(frame, state, main_layout[2]);

    // Footer
    let footer = Paragraph::new(Line::from(vec![
        Span::styled(" Tab", Style::default().fg(GREEN)),
        Span::styled(" switch  ", Style::default().fg(MUTED)),
        Span::styled("↑↓", Style::default().fg(GREEN)),
        Span::styled(" navigate  ", Style::default().fg(MUTED)),
        Span::styled("Space", Style::default().fg(GREEN)),
        Span::styled(" toggle  ", Style::default().fg(MUTED)),
        Span::styled("Enter", Style::default().fg(GREEN)),
        Span::styled(" save  ", Style::default().fg(MUTED)),
        Span::styled("Esc", Style::default().fg(GREEN)),
        Span::styled(" quit", Style::default().fg(MUTED)),
    ]));
    frame.render_widget(footer, main_layout[3]);
}

fn draw_theme_list(frame: &mut Frame, state: &ConfigState, area: Rect) {
    let items: Vec<ListItem> = state
        .theme_names
        .iter()
        .enumerate()
        .map(|(i, name)| {
            let style = if i == state.theme_idx {
                if state.panel == Panel::Themes {
                    Style::default().fg(CYAN).add_modifier(Modifier::BOLD)
                } else {
                    Style::default().fg(GREEN)
                }
            } else {
                Style::default().fg(TEXT)
            };
            let prefix = if i == state.theme_idx { "> " } else { "  " };
            ListItem::new(Line::from(Span::styled(format!("{prefix}{name}"), style)))
        })
        .collect();

    let border_color = if state.panel == Panel::Themes {
        CYAN
    } else {
        MUTED
    };
    let list = List::new(items).block(
        Block::default()
            .title(" Themes ")
            .title_style(Style::default().fg(TEXT))
            .borders(Borders::ALL)
            .border_style(Style::default().fg(border_color)),
    );
    frame.render_widget(list, area);
}

fn draw_module_list(frame: &mut Frame, state: &ConfigState, area: Rect) {
    let items: Vec<ListItem> = state
        .modules
        .iter()
        .enumerate()
        .map(|(i, m)| {
            let check = if m.enabled { "[x]" } else { "[ ]" };
            let style = if i == state.module_idx && state.panel == Panel::Modules {
                Style::default().fg(CYAN).add_modifier(Modifier::BOLD)
            } else if m.enabled {
                Style::default().fg(GREEN)
            } else {
                Style::default().fg(MUTED)
            };
            ListItem::new(Line::from(Span::styled(
                format!(" {check} {}", m.name),
                style,
            )))
        })
        .collect();

    let border_color = if state.panel == Panel::Modules {
        CYAN
    } else {
        MUTED
    };
    let list = List::new(items).block(
        Block::default()
            .title(" Modules ")
            .title_style(Style::default().fg(TEXT))
            .borders(Borders::ALL)
            .border_style(Style::default().fg(border_color)),
    );
    frame.render_widget(list, area);
}

fn draw_toml_preview(frame: &mut Frame, state: &ConfigState, area: Rect) {
    let toml = state.generate_toml();
    let paragraph = Paragraph::new(toml)
        .style(Style::default().fg(MUTED))
        .block(
            Block::default()
                .title(" Generated TOML ")
                .title_style(Style::default().fg(TEXT))
                .borders(Borders::ALL)
                .border_style(Style::default().fg(MUTED)),
        );
    frame.render_widget(paragraph, area);
}

fn draw_powerline_preview(frame: &mut Frame, state: &ConfigState, area: Rect) {
    let theme = state.current_theme();
    let palette = themes::get_palette(theme);

    let mock_data = [
        ("sonde.model", "Opus"),
        ("sonde.context_bar", "[━━━━╌╌╌╌╌╌] 42%"),
        ("sonde.usage_limits", "5h 42%"),
        ("sonde.pacing", "Elevated 38%"),
    ];

    let segments: Vec<ansi::PowerlineSegment> = mock_data
        .iter()
        .filter(|&&(module, _)| {
            state
                .modules
                .iter()
                .any(|m| m.token == format!("${module}") && m.enabled)
        })
        .map(|&(module, text)| {
            let (fg, bg) = themes::powerline_colors(palette, module);
            ansi::PowerlineSegment {
                text: text.to_string(),
                fg,
                bg,
            }
        })
        .collect();

    let rendered = if segments.is_empty() {
        "  (no modules selected)".to_string()
    } else {
        format!("  {}", ansi::render_powerline(&segments))
    };

    let preview = Paragraph::new(rendered).block(
        Block::default()
            .title(format!(" Preview: {theme} "))
            .title_style(Style::default().fg(TEXT))
            .borders(Borders::ALL)
            .border_style(Style::default().fg(MUTED)),
    );
    frame.render_widget(preview, area);
}

fn save_config(state: &ConfigState) -> Result<(), Box<dyn std::error::Error>> {
    let toml_content = state.generate_toml();

    // Validate TOML round-trip
    let _: toml::Value = toml::from_str(&toml_content)?;

    // Find or create config path
    let config_path = config::discover_config_path().unwrap_or_else(|| {
        dirs::config_dir()
            .unwrap_or_else(|| dirs::home_dir().unwrap_or_default().join(".config"))
            .join("sonde")
            .join("sonde.toml")
    });

    // Backup existing config
    if config_path.exists() {
        let timestamp = chrono::Local::now().format("%Y%m%d%H%M%S");
        let backup = config_path.with_extension(format!("toml.bak.{timestamp}"));
        std::fs::copy(&config_path, &backup)?;
    }

    if let Some(parent) = config_path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    std::fs::write(&config_path, &toml_content)?;
    Ok(())
}

pub fn run() -> Result<(), Box<dyn std::error::Error>> {
    let original_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |panic_info| {
        let _ = disable_raw_mode();
        let _ = execute!(io::stdout(), LeaveAlternateScreen);
        original_hook(panic_info);
    }));

    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut state = ConfigState::new();

    loop {
        terminal.draw(|f| draw(f, &state))?;

        if let Event::Key(key) = event::read()? {
            if key.kind != KeyEventKind::Press {
                continue;
            }
            match key.code {
                KeyCode::Esc | KeyCode::Char('q') => break,
                KeyCode::Tab => {
                    state.panel = match state.panel {
                        Panel::Themes => Panel::Modules,
                        Panel::Modules => Panel::Themes,
                    };
                }
                KeyCode::Up => match state.panel {
                    Panel::Themes => {
                        if state.theme_idx > 0 {
                            state.theme_idx -= 1;
                        }
                    }
                    Panel::Modules => {
                        if state.module_idx > 0 {
                            state.module_idx -= 1;
                        }
                    }
                },
                KeyCode::Down => match state.panel {
                    Panel::Themes => {
                        if state.theme_idx + 1 < state.theme_names.len() {
                            state.theme_idx += 1;
                        }
                    }
                    Panel::Modules => {
                        if state.module_idx + 1 < state.modules.len() {
                            state.module_idx += 1;
                        }
                    }
                },
                KeyCode::Char(' ') => {
                    if state.panel == Panel::Modules {
                        state.modules[state.module_idx].enabled =
                            !state.modules[state.module_idx].enabled;
                    }
                }
                KeyCode::Enter => {
                    disable_raw_mode()?;
                    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
                    terminal.show_cursor()?;

                    match save_config(&state) {
                        Ok(()) => println!("Config saved!"),
                        Err(e) => eprintln!("Failed to save config: {e}"),
                    }
                    return Ok(());
                }
                _ => {}
            }
        }
    }

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn toml_generation_roundtrips() {
        let state = ConfigState::new();
        let toml = state.generate_toml();
        let parsed: toml::Value = toml::from_str(&toml).unwrap();
        assert!(parsed.get("sonde").is_some());
    }

    #[test]
    fn toml_includes_theme() {
        let mut state = ConfigState::new();
        state.theme_idx = 1; // dracula
        let toml = state.generate_toml();
        assert!(toml.contains("dracula"));
    }

    #[test]
    fn disabled_modules_excluded_from_lines() {
        let mut state = ConfigState::new();
        for m in &mut state.modules {
            m.enabled = false;
        }
        let toml = state.generate_toml();
        assert!(!toml.contains("$sonde.model"));
    }
}
