use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Gauge, Paragraph},
    Frame,
};

use super::app::App;
use crate::modules::pacing::PaceTier;

// Color palette
const GREEN: Color = Color::Rgb(74, 222, 128);
const LIME: Color = Color::Rgb(163, 230, 53);
const YELLOW: Color = Color::Rgb(250, 204, 21);
const RED: Color = Color::Rgb(248, 113, 113);
const PURPLE: Color = Color::Rgb(167, 139, 250);
const CYAN: Color = Color::Rgb(34, 211, 238);
const TEXT: Color = Color::Rgb(212, 232, 220);
const MUTED: Color = Color::Rgb(122, 154, 136);
const BG: Color = Color::Rgb(20, 20, 30);

pub fn draw(frame: &mut Frame, app: &App) {
    let area = frame.area();

    // Background
    let bg_block = Block::default().style(Style::default().bg(BG));
    frame.render_widget(bg_block, area);

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Header
            Constraint::Length(4), // Mascot + Session
            Constraint::Length(3), // 5h usage bar
            Constraint::Length(3), // 7d usage bar
            Constraint::Length(3), // Pacing
            Constraint::Min(3),    // Sessions list
            Constraint::Length(1), // Footer
        ])
        .split(area);

    draw_header(frame, app, chunks[0]);
    draw_mascot_session(frame, app, chunks[1]);
    draw_usage_bar(frame, app, chunks[2], true);
    draw_usage_bar(frame, app, chunks[3], false);
    draw_pacing(frame, app, chunks[4]);
    draw_sessions(frame, app, chunks[5]);
    draw_footer(frame, chunks[6]);
}

fn draw_header(frame: &mut Frame, app: &App, area: Rect) {
    let mut spans = vec![
        Span::styled(
            " sonde ",
            Style::default().fg(GREEN).add_modifier(Modifier::BOLD),
        ),
        Span::styled(" dashboard ", Style::default().fg(MUTED)),
    ];

    if app.promo_active {
        let label = if app.promo_label.is_empty() {
            "PROMO".to_string()
        } else {
            app.promo_label.clone()
        };
        spans.push(Span::styled(
            format!(" {label} "),
            Style::default()
                .fg(BG)
                .bg(CYAN)
                .add_modifier(Modifier::BOLD),
        ));
    }

    let header = Paragraph::new(Line::from(spans)).block(
        Block::default()
            .borders(Borders::BOTTOM)
            .border_style(Style::default().fg(MUTED)),
    );
    frame.render_widget(header, area);
}

fn draw_mascot_session(frame: &mut Frame, app: &App, area: Rect) {
    let cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Length(4), Constraint::Min(20)])
        .split(area);

    // Mascot icon
    let icons = app.mascot_state.icon_frames();
    let idx = app.frame % icons.len();
    let icon = icons[idx];
    let mascot_color = hex_to_color(app.mascot_state.color());

    let mascot = Paragraph::new(vec![Line::from(Span::styled(
        format!(" {} ", icon),
        Style::default().fg(mascot_color),
    ))])
    .block(Block::default().borders(Borders::NONE));
    frame.render_widget(mascot, cols[0]);

    // Session info
    let model = app.model_name.as_deref().unwrap_or("No session");
    let cost_str = app
        .session_cost
        .map(|c| format!("${:.2}", c))
        .unwrap_or_else(|| "--".to_string());
    let ctx_str = app
        .context_pct
        .map(|p| format!("{:.0}%", p))
        .unwrap_or_else(|| "--".to_string());
    let cwd_str = app.cwd.as_deref().map(shorten_path).unwrap_or_default();

    let session = Paragraph::new(vec![
        Line::from(vec![
            Span::styled(
                model,
                Style::default().fg(PURPLE).add_modifier(Modifier::BOLD),
            ),
            Span::styled(format!("  cost: {cost_str}"), Style::default().fg(TEXT)),
        ]),
        Line::from(vec![
            Span::styled(format!("ctx: {ctx_str}"), Style::default().fg(MUTED)),
            Span::styled(format!("  {cwd_str}"), Style::default().fg(MUTED)),
        ]),
    ])
    .block(Block::default().borders(Borders::NONE));
    frame.render_widget(session, cols[1]);
}

fn draw_usage_bar(frame: &mut Frame, app: &App, area: Rect, is_five_hour: bool) {
    let (util, label, reset) = if is_five_hour {
        (app.five_hour_util, "5h", &app.five_hour_reset)
    } else {
        (app.seven_day_util, "7d", &app.seven_day_reset)
    };

    let pct = util.unwrap_or(0.0);
    let ratio = (pct / 100.0).clamp(0.0, 1.0);
    let color = usage_color(pct);

    let reset_label = reset
        .as_ref()
        .map(|r| format!(" resets {}", short_time(r)))
        .unwrap_or_default();

    let gauge = Gauge::default()
        .block(
            Block::default()
                .title(format!(" {label} usage: {pct:.0}%{reset_label} "))
                .title_style(Style::default().fg(TEXT))
                .borders(Borders::ALL)
                .border_style(Style::default().fg(MUTED)),
        )
        .gauge_style(Style::default().fg(color).bg(Color::Rgb(40, 40, 50)))
        .ratio(ratio);
    frame.render_widget(gauge, area);
}

fn draw_pacing(frame: &mut Frame, app: &App, area: Rect) {
    let (label, color) = match app.pace_tier {
        Some(tier) => (tier.label(), tier_color(&tier)),
        None => ("Unknown", MUTED),
    };

    let pacing = Paragraph::new(Line::from(vec![
        Span::styled(" Pacing: ", Style::default().fg(MUTED)),
        Span::styled(
            label,
            Style::default().fg(color).add_modifier(Modifier::BOLD),
        ),
    ]))
    .block(
        Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(MUTED)),
    );
    frame.render_widget(pacing, area);
}

fn draw_sessions(frame: &mut Frame, app: &App, area: Rect) {
    let mut lines: Vec<Line> = Vec::new();

    // Show scanned JSONL sessions first (direct transcript parsing)
    for s in &app.scanned_sessions {
        let pct_color = usage_color(s.percentage as f64);
        let bar = context_bar(s.percentage);
        let used_k = s.used_tokens / 1000;
        let free_k = s.free_tokens / 1000;

        let elapsed = s
            .last_modified
            .elapsed()
            .map(|d| {
                let secs = d.as_secs();
                if secs < 60 {
                    format!("{}s ago", secs)
                } else {
                    format!("{}m ago", secs / 60)
                }
            })
            .unwrap_or_else(|_| "?".to_string());

        lines.push(Line::from(vec![
            Span::styled(
                format!(" {}", s.project_name),
                Style::default()
                    .fg(PURPLE)
                    .add_modifier(ratatui::style::Modifier::BOLD),
            ),
            Span::styled(format!("  {bar} ",), Style::default().fg(pct_color)),
            Span::styled(format!("{}%", s.percentage), Style::default().fg(pct_color)),
            Span::styled(
                format!("  {used_k}k/{free_k}k free",),
                Style::default().fg(TEXT),
            ),
            Span::styled(format!("  {elapsed}"), Style::default().fg(MUTED)),
        ]));
    }

    // Show cache-based sessions that aren't duplicated by scanned sessions
    for s in &app.sessions {
        let model = s.model_name.as_deref().unwrap_or("?");
        let cost = s
            .session_cost
            .map(|c| format!("${:.2}", c))
            .unwrap_or_else(|| "--".to_string());
        let path = s.cwd.as_deref().map(shorten_path).unwrap_or_default();

        lines.push(Line::from(vec![
            Span::styled(format!(" {model}"), Style::default().fg(PURPLE)),
            Span::styled(format!("  {cost}"), Style::default().fg(TEXT)),
            Span::styled(format!("  {path}"), Style::default().fg(MUTED)),
        ]));
    }

    if lines.is_empty() {
        lines.push(Line::from(Span::styled(
            " No active sessions",
            Style::default().fg(MUTED),
        )));
    }

    let sessions = Paragraph::new(lines).block(
        Block::default()
            .title(" Sessions ")
            .title_style(Style::default().fg(TEXT))
            .borders(Borders::ALL)
            .border_style(Style::default().fg(MUTED)),
    );
    frame.render_widget(sessions, area);
}

/// Build a compact progress bar for context usage.
fn context_bar(pct: u8) -> String {
    let filled = (pct as usize) / 5; // 20 chars wide
    let empty = 20usize.saturating_sub(filled);
    format!("[{}{}]", "█".repeat(filled), "░".repeat(empty))
}

fn draw_footer(frame: &mut Frame, area: Rect) {
    let footer = Paragraph::new(Line::from(vec![
        Span::styled(" q", Style::default().fg(GREEN)),
        Span::styled(" quit  ", Style::default().fg(MUTED)),
        Span::styled("r", Style::default().fg(GREEN)),
        Span::styled(" refresh", Style::default().fg(MUTED)),
    ]));
    frame.render_widget(footer, area);
}

/// Convert mascot hex color string like "fg:#6b7280" to ratatui Color::Rgb.
fn hex_to_color(s: &str) -> Color {
    let hex = s.trim_start_matches("fg:#");
    if hex.len() != 6 {
        return TEXT;
    }
    let r = u8::from_str_radix(&hex[0..2], 16).unwrap_or(200);
    let g = u8::from_str_radix(&hex[2..4], 16).unwrap_or(200);
    let b = u8::from_str_radix(&hex[4..6], 16).unwrap_or(200);
    Color::Rgb(r, g, b)
}

/// Color for usage percentage.
fn usage_color(pct: f64) -> Color {
    if pct < 40.0 {
        GREEN
    } else if pct < 70.0 {
        LIME
    } else if pct < 85.0 {
        YELLOW
    } else {
        RED
    }
}

/// Map PaceTier to a TUI color.
fn tier_color(tier: &PaceTier) -> Color {
    match tier {
        PaceTier::Comfortable => GREEN,
        PaceTier::OnTrack => LIME,
        PaceTier::Elevated => YELLOW,
        PaceTier::Hot => Color::Rgb(250, 179, 135),
        PaceTier::Critical => RED,
        PaceTier::Runaway => RED,
    }
}

/// Shorten a path for display.
fn shorten_path(path: &str) -> String {
    if let Some(home) = dirs::home_dir() {
        let home_str = home.to_string_lossy();
        if path.starts_with(home_str.as_ref()) {
            return format!("~{}", &path[home_str.len()..]);
        }
    }
    path.to_string()
}

/// Extract a short time from an ISO 8601 timestamp.
fn short_time(iso: &str) -> String {
    // Try to extract HH:MM from something like "2025-01-15T14:30:00Z"
    if let Some(t_pos) = iso.find('T') {
        let time_part = &iso[t_pos + 1..];
        if time_part.len() >= 5 {
            return time_part[..5].to_string();
        }
    }
    iso.to_string()
}
