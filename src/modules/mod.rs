pub mod active_sessions;
pub mod agent_badge;
pub mod context_bar;
pub mod context_window;
pub mod custom;
pub mod git_branch;
pub mod mascot;
pub mod model;
pub mod model_suggestion;
pub mod pacing;
pub mod project;
pub mod promo_badge;
pub mod session_clock;
pub mod usage_5h;
pub mod usage_7d;
pub mod usage_limits;
pub mod worktree;

use crate::config::SondeConfig;
use crate::context::Context;

pub fn render_module(name: &str, ctx: &Context, cfg: &SondeConfig) -> Option<String> {
    match name {
        "sonde.model" => model::render(ctx, cfg),
        "sonde.context_bar" => context_bar::render(ctx, cfg),
        "sonde.context_window" => context_window::render(ctx, cfg),
        "sonde.usage_limits" => usage_limits::render(ctx, cfg),
        "sonde.promo_badge" => promo_badge::render(ctx, cfg),
        "sonde.pacing" => pacing::render(ctx, cfg),
        "sonde.session_clock" => session_clock::render(ctx, cfg),
        "sonde.git_branch" => git_branch::render(ctx, cfg),
        "sonde.active_sessions" => active_sessions::render(ctx, cfg),
        "sonde.model_suggestion" => model_suggestion::render(ctx, cfg),
        "sonde.mascot_icon" => mascot::render_icon(ctx, cfg),
        "sonde.agent" => agent_badge::render(ctx, cfg),
        "sonde.worktree" => worktree::render(ctx, cfg),
        "sonde.project" => project::render(ctx, cfg),
        "sonde.usage_5h" => usage_5h::render(ctx, cfg),
        "sonde.usage_7d" => usage_7d::render(ctx, cfg),
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
