mod ansi;
mod cache;
mod config;
mod context;
mod modules;
mod platform;
mod promo;
mod renderer;
mod usage_api;

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

    // Load config
    let cfg = config::load();

    // Render and print to stdout
    let output = renderer::render(&ctx, &cfg);
    if !output.is_empty() {
        println!("{output}");
    }
}
