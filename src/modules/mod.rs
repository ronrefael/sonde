pub mod active_sessions;
pub mod agent_badge;
pub mod codex_cost;
pub mod combined_spend;
pub mod context_bar;
pub mod context_window;
pub mod copilot_cost;
pub mod cost;
pub mod cursor;
pub mod custom;
pub mod gemini_cost;
pub mod git_branch;
pub mod mascot;
pub mod model;
pub mod model_suggestion;
pub mod pacing;
pub mod promo_badge;
pub mod session_clock;
pub mod usage_limits;
pub mod windsurf_cost;
pub mod worktree;

use crate::config::SondeConfig;
use crate::context::Context;

pub fn render_module(name: &str, ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    match name {
        "sonde.model" => model::render(ctx, cfg),
        "sonde.cost" => cost::render(ctx, cfg),
        "sonde.context_bar" => context_bar::render(ctx, cfg),
        "sonde.context_window" => context_window::render(ctx, cfg),
        "sonde.usage_limits" => usage_limits::render(ctx, cfg),
        "sonde.promo_badge" => promo_badge::render(ctx, cfg),
        "sonde.pacing" => pacing::render(ctx, cfg),
        "sonde.codex_cost" => codex_cost::render(ctx, cfg),
        "sonde.session_clock" => session_clock::render(ctx, cfg),
        "sonde.git_branch" => git_branch::render(ctx, cfg),
        "sonde.active_sessions" => active_sessions::render(ctx, cfg),
        "sonde.model_suggestion" => model_suggestion::render(ctx, cfg),
        "sonde.combined_spend" => combined_spend::render(ctx, cfg),
        "sonde.cursor" => cursor::render(ctx, cfg),
        "sonde.mascot_icon" => mascot::render_icon(ctx, cfg),
        "sonde.agent" => agent_badge::render(ctx, cfg),
        "sonde.worktree" => worktree::render(ctx, cfg),
        "sonde.windsurf_cost" => windsurf_cost::render(ctx, cfg),
        "sonde.copilot_cost" => copilot_cost::render(ctx, cfg),
        "sonde.gemini_cost" => gemini_cost::render(ctx, cfg),
        other if other.starts_with("sonde.custom.") => {
            let key = &other["sonde.custom.".len()..];
            custom::render(key, ctx, cfg)
        }
        other => {
            tracing::debug!("Unknown module: {other}");
            None
        }
    }
}
