mod ansi;
mod cache;
mod config;
mod context;
mod modules;
mod platform;
mod promo;
mod renderer;
mod session_scanner;
mod tui;
mod usage_api;

/// Write session data to cache so the Swift menu bar app can read authoritative
/// cost/context/model data instead of re-parsing transcripts.
fn write_session_cache(ctx: &context::Context) {
    let session_id = ctx.session_id.as_deref().unwrap_or("default");
    let cache_key = format!("session_{}", session_id);
    let cache_path = match cache::cache_path(&cache_key) {
        Some(p) => p,
        None => return,
    };

    let mut obj = serde_json::Map::new();

    if let Some(ref model) = ctx.model {
        if let Some(ref name) = model.display_name {
            obj.insert("model_name".into(), serde_json::Value::String(name.clone()));
        }
        if let Some(ref id) = model.id {
            obj.insert("model_id".into(), serde_json::Value::String(id.clone()));
        }
    }

    if let Some(ref cost) = ctx.cost {
        if let Some(usd) = cost.total_cost_usd {
            obj.insert("session_cost".into(), serde_json::json!(usd));
        }
        if let Some(ms) = cost.total_duration_ms {
            obj.insert("session_duration_ms".into(), serde_json::json!(ms));
        }
        if let Some(lines) = cost.total_lines_added {
            obj.insert("total_lines_added".into(), serde_json::json!(lines));
        }
        if let Some(lines) = cost.total_lines_removed {
            obj.insert("total_lines_removed".into(), serde_json::json!(lines));
        }
        if let Some(ms) = cost.total_api_duration_ms {
            obj.insert("total_api_duration_ms".into(), serde_json::json!(ms));
        }
    }

    if let Some(ref cw) = ctx.context_window {
        if let Some(pct) = cw.used_percentage {
            obj.insert("context_used_pct".into(), serde_json::json!(pct));
        }
        if let Some(size) = cw.context_window_size {
            obj.insert("context_window_size".into(), serde_json::json!(size));
        }
        if let Some(input) = cw.total_input_tokens {
            obj.insert("total_input_tokens".into(), serde_json::json!(input));
        }
        if let Some(output) = cw.total_output_tokens {
            obj.insert("total_output_tokens".into(), serde_json::json!(output));
        }
    }

    if let Some(ref version) = ctx.version {
        obj.insert("version".into(), serde_json::Value::String(version.clone()));
    }

    if let Some(ref agent) = ctx.agent {
        if let Some(ref name) = agent.name {
            obj.insert("agent_name".into(), serde_json::Value::String(name.clone()));
        }
    }

    if let Some(ref vim) = ctx.vim {
        if let Some(ref mode) = vim.mode {
            obj.insert("vim_mode".into(), serde_json::Value::String(mode.clone()));
        }
    }

    if let Some(ref session_id) = ctx.session_id {
        obj.insert(
            "session_id".into(),
            serde_json::Value::String(session_id.clone()),
        );
    }

    if let Some(ref cwd) = ctx.cwd {
        obj.insert("cwd".into(), serde_json::Value::String(cwd.clone()));
    }

    if let Some(ref wt) = ctx.worktree {
        if let Some(ref branch) = wt.branch {
            obj.insert(
                "git_branch".into(),
                serde_json::Value::String(branch.clone()),
            );
        }
    }

    obj.insert(
        "provider".into(),
        serde_json::Value::String("claude".to_string()),
    );

    // Write with 10-min TTL — sessions may be idle between statusline renders
    let data = serde_json::Value::Object(obj);
    cache::write_cache(&cache_path, &data, 600, None);

    // Also write legacy session_data.json — the Swift menu bar app reads this directly
    if let Some(legacy_path) = cache::cache_path("session_data") {
        cache::write_cache(&legacy_path, &data, 600, None);
    }
}

fn run_statusline() {
    let ctx = context::parse_stdin();
    write_session_cache(&ctx);
    let cfg = config::load();
    let output = renderer::render(&ctx, &cfg);
    if !output.is_empty() {
        println!("{output}");
    }
}

fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive(tracing::Level::WARN.into()),
        )
        .with_writer(std::io::stderr)
        .with_target(false)
        .init();

    let arg = std::env::args().nth(1);
    match arg.as_deref() {
        Some("tui") => {
            if let Err(e) = tui::run() {
                eprintln!("TUI error: {e}");
                std::process::exit(1);
            }
        }
        Some("version") | Some("--version") | Some("-V") => {
            println!("sonde {}", env!("CARGO_PKG_VERSION"));
        }
        _ => {
            run_statusline();
        }
    }
}
