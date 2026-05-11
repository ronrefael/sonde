# Changelog

All notable changes to sonde will be documented in this file.

## [1.0.0] — 2026-03-21

### Added
- **macOS menu bar app** — native SwiftUI dashboard with usage rings, pacing tier, time-to-limit, active sessions, 7-day chart, context bar, and promo badge
- **7 dashboard themes** — Liquid Glass, System (light/dark), Sonde, Terminal, Cyberpunk, Synthwave, Solar Flare
- **2X promo detection** — tracks Claude Code's capacity promotions via PromoClock API, adjusts pacing predictions automatically
- **Guided onboarding** — 7-step setup wizard (Claude Code check, auth, statusline, font install, theme picker)
- **Nerd Font bundled** — one-click install during onboarding and in Settings
- **App icon** — pixel-art mascot with dark rounded background
- **DMG installer** — drag-to-Applications install experience
- **Terminal statusline** — Rust-powered, renders in <50ms, 10+ configurable modules
- **6 terminal palettes** — catppuccin-mocha, terminal, cyberpunk, synthwave, solarflare, sonde (matches `src/themes.rs`)
- **Nerd Font auto-detection** — icons disabled automatically if terminal font doesn't support them
- **Homebrew tap** — `brew install ronrefael/tap/sonde`
- **GitHub Actions release workflow** — automated DMG + binary builds on tag push
- **`sonde setup`** — auto-configures Claude Code statusline integration
- **`sonde doctor`** — 9 diagnostic checks
- **`sonde themes`** — preview all terminal palettes
- **Duplicate instance prevention** — kills other running Sonde instances on launch
- **Configurable menu bar** — toggle promo status, timer, choose from 7 timer modes
- **Settings panel** — theme picker, timer mode, refresh interval, Nerd Font install

## [Unreleased] — fix/p0-security-install-trust

### Security
- **Removed billed Messages-API "ping" fallback.** Previously, when Anthropic's
  OAuth `/api/oauth/usage` endpoint returned 429, Sonde sent a real `POST
  /v1/messages` (Haiku, 1 token) just to read rate-limit response headers —
  charging the user money to discover their own usage. Both the Rust statusline
  and the Swift menu bar app shared this pattern; both are now removed. On a
  usage-endpoint failure Sonde now serves cached data or omits the segment.
- **Project-local `sonde.toml` is now sandboxed.** A `sonde.toml` discovered in
  the current working directory (e.g. via `cd` into a freshly cloned repository)
  can no longer declare `[sonde.custom.*]` shell commands or
  `[sonde.notifications].webhook_url`. Both fields run code or send data on
  every statusline render. Sonde strips them by default for cwd-discovered
  configs and emits a warning. Users who trust a repository can opt back in
  with `SONDE_TRUST_LOCAL_CUSTOM=1` (must be set in the shell environment, not
  the config itself). Configs from `$SONDE_CONFIG`, XDG, or `~` are unaffected.
- **Removed the 5-minute OAuth token cache in `CredentialProvider.swift`.** The
  token is now fetched from the macOS Keychain on every request and dropped
  immediately. Aligns with CLAUDE.md's "token must NOT be cached" rule and
  closes the long-lived heap-recovery window.

### Correctness
- **Onboarding now writes the real Claude Code statusline key.** The wizard
  used to write `env.CLAUDE_CODE_STATUSLINE=1`, which Claude Code ignores.
  Users who finished the wizard had a statusline that never ran, and the
  wizard reported success. Now writes `statusLine.command` (matching the
  Rust `sonde setup` path) with a timestamped `.bak` of the previous
  `~/.claude/settings.json`.
- **`UpdateChecker.swift` now reads the version from `Bundle.main`.** The
  hard-coded `currentVersion = "0.1.0"` made every existing v1.0.0 user see a
  permanent false "Update available!" banner pointing at the release they
  already had.
- **`pacing.rs` no longer panics on NaN / corrupt cache data.** A single
  malformed `usage_history_raw.json` line previously bricked the statusline
  silently because `panic="abort"` swallowed the trace.

### Schema
- **Wired Claude Code v2.1.80+ stdin fields.** Sonde now consumes
  `rate_limits.{five_hour,seven_day}` directly from stdin and prefers it over
  the OAuth endpoint — no HTTP round-trip on the hot path when the harness
  provides the data. `workspace.git_worktree` (v2.1.97), `effort.level`
  (v2.1.105) and `thinking.enabled` (v2.1.105) are now parsed for future use.

### Install + trust
- **Homebrew formula version bumped to v1.0.0 with verified SHA256s** for
  every platform tarball. `brew install ronrefael/tap/sonde` works again.
- **`install.sh` now points at `ronrefael/sonde`** instead of the
  non-existent `sonde-dev/sonde`.

### Hygiene
- Deleted two checked-in `sonde.toml.bak.*` files; added `*.bak`/`*.bak.*`
  to `.gitignore` so local backups stay local.

## [1.0.0] — 2026-03-21
[1.0.0]: https://github.com/ronrefael/sonde/releases/tag/v1.0.0
