mod ansi;
mod cache;
mod config;
mod context;
mod modules;
mod platform;
mod promo;
mod renderer;
mod usage_api;

/// Write session data to cache so the Swift menu bar app can read authoritative
/// cost/context/model data instead of re-parsing transcripts.
fn write_session_cache(ctx: &context::Context) {
    let cache_path = match cache::cache_path("session_data") {
        Some(p) => p,
        None => return,
    };

    // Build a JSON object with the data the Swift app needs
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

    if let Some(ref session_id) = ctx.session_id {
        obj.insert(
            "session_id".into(),
            serde_json::Value::String(session_id.clone()),
        );
    }

    if let Some(ref cwd) = ctx.cwd {
        obj.insert("cwd".into(), serde_json::Value::String(cwd.clone()));
    }

    // Write with short TTL — this refreshes on every statusline render
    let data = serde_json::Value::Object(obj);
    cache::write_cache(&cache_path, &data, 30, None);
}

fn main() {
    // Initialize tracing to stderr (never stdout)
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive(tracing::Level::WARN.into()),
        )
        .with_writer(std::io::stderr)
        .with_target(false)
        .init();

    // Parse stdin JSON
    let ctx = context::parse_stdin();

    // Write session data cache for the Swift menu bar app
    write_session_cache(&ctx);

    // Load config
    let cfg = config::load();

    // Render and print to stdout
    let output = renderer::render(&ctx, &cfg);
    if !output.is_empty() {
        println!("{output}");
    }
}
