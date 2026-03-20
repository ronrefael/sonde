mod ansi;
mod cache;
mod config;
mod context;
mod doctor;
mod history;
mod modules;
mod notifications;
mod platform;
mod promo;
mod renderer;
mod session_scanner;
mod setup;
mod themes;
mod themes_preview;
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

    // Write the real project_dir so Swift can use it directly (avoids path decode ambiguity)
    if let Some(ref ws) = ctx.workspace {
        if let Some(ref dir) = ws.project_dir {
            obj.insert("project_dir".into(), serde_json::Value::String(dir.clone()));
        }
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

    // Record usage history — fetch_usage is memoized per process via OnceLock,
    // so this reuses the render cycle's data without an extra API call
    let ttl = cfg.usage_limits.as_ref().and_then(|c| c.ttl);
    let five_hour_util =
        usage_api::fetch_usage(ttl).and_then(|d| d.five_hour.and_then(|w| w.utilization));
    let seven_day_util =
        usage_api::fetch_usage(ttl).and_then(|d| d.seven_day.and_then(|w| w.utilization));
    let session_cost = ctx.cost.as_ref().and_then(|c| c.total_cost_usd);
    history::record(five_hour_util, seven_day_util, session_cost);

    // Webhook notifications (fire-and-forget)
    notifications::check_and_notify(&cfg, five_hour_util);
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

    match std::env::args().nth(1).as_deref() {
        Some("tui") => {
            if let Err(e) = tui::run() {
                eprintln!("TUI error: {e}");
                std::process::exit(1);
            }
        }
        Some("version") | Some("--version") | Some("-V") => {
            println!("sonde {}", env!("CARGO_PKG_VERSION"));
        }
        Some("doctor") | Some("--doctor") => {
            let code = doctor::run();
            std::process::exit(code);
        }
        Some("themes") | Some("--themes") => {
            themes_preview::run();
        }
        Some("configure") | Some("--configure") => {
            if let Err(e) = tui::configurator::run() {
                eprintln!("Configurator error: {e}");
                std::process::exit(1);
            }
        }
        Some("setup") | Some("--setup") => {
            let dry_run = std::env::args().any(|a| a == "--dry-run");
            if let Err(e) = setup::run(dry_run) {
                eprintln!("Setup error: {e}");
                std::process::exit(1);
            }
        }
        _ => {
            run_statusline();
        }
    }
}
