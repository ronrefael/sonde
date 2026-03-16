# sonde — Claude Code Instructions

## What this project is

sonde: precision instrumentation that continuously measures AI usage and reports
conditions in real-time. Rust statusline binary (Phase 1), macOS menu bar app
in Swift (Phase 2).

## Non-negotiable code patterns

- Module interface: `pub fn render(ctx: &Context, cfg: &SondeConfig) -> Option<String>`
- All config structs: `#[derive(Debug, Deserialize, Default)]`, all fields `pub Option<T>`
- Context struct: all `Option<T>`, NO `deny_unknown_fields` (forward-compatible)
- Disabled flag -> silent `None` (no warning)
- Missing data -> explicit `match` + `tracing::warn!` + `None`
- Never use `?` operator where a warning is needed -- use explicit `match`
- stdout owned ONLY by `main.rs`; all diagnostics via `tracing::*` to stderr
- OAuth token: NEVER written to disk, cache, stdout, or stderr

## Adding a new module (2 files max)

1. Create `src/modules/{name}.rs` with `pub fn render(ctx: &Context, cfg: &SondeConfig) -> Option<String>`
2. Add match arm in `src/modules/mod.rs`

## File ownership rules

- stdin reading: `src/context.rs` ONLY
- stdout writing: `src/main.rs` ONLY
- HTTP calls: `src/usage_api.rs` ONLY (OAuth) and `src/promo.rs` ONLY (PromoClock)
- Credential access: `src/platform.rs` ONLY
- Cache I/O: `src/cache.rs` ONLY
- Config parsing: `src/config.rs` ONLY
- ANSI styling: `src/ansi.rs` ONLY

## Key APIs

### Claude Code OAuth usage endpoint
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer {token}
anthropic-beta: oauth-2025-04-20

### PromoClock API
GET https://promoclock.co/api/status

### Credential locations
- macOS: `security find-generic-password -s "Claude Code-credentials" -w`
- Linux: `~/.claude/.credentials.json`
- Linux fallback: `secret-tool lookup service "Claude Code-credentials"`

## Testing

- `echo '{"model":{"display_name":"Opus"}}' | cargo run` to test
- Test fixtures in `tests/fixtures/`
- Mock HTTP calls in tests -- never hit real APIs
- Use `rstest` for parameterized tests
- Use `assert_cmd` for CLI integration tests
