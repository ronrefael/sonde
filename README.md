<p align="center">
  <strong>sonde</strong> — precision instrumentation for AI coding tools
</p>

<p align="center">
  <a href="#install">Install</a> &bull;
  <a href="#quick-start">Quick Start</a> &bull;
  <a href="#themes">Themes</a> &bull;
  <a href="#modules">Modules</a> &bull;
  <a href="#configuration">Configuration</a>
</p>

<p align="center">
  <img src="https://img.shields.io/github/v/release/ronrefael/sonde?style=flat-square" alt="Release">
  <img src="https://img.shields.io/github/license/ronrefael/sonde?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/rust-stable-orange?style=flat-square" alt="Rust">
</p>

---

sonde sits in your Claude Code statusline and continuously reports model, cost, context usage, rate limits, promo status, and pacing — across Claude, Codex, Cursor, Windsurf, Copilot, and Gemini.

```
 Opus  2h14m  [████░░░░░░] 42%  5h 20% (3h41m)  7d 39% (81h41m)   Comfortable 80% (~2h 15m)
 2X — Off-peak limits active  14h33m left
```

## What makes sonde different

| Feature | sonde | ccusage | CodexBar | ccstatusline |
|---------|:-----:|:-------:|:--------:|:------------:|
| Real-time statusline | **Yes** | No | No | Yes |
| Promo awareness (2X/3X) | **Yes** | No | No | No |
| 6-tier pacing with prediction | **Yes** | No | No | No |
| Multi-provider (Claude+Codex+Cursor+Windsurf) | **Yes** | No | No | No |
| Named theme presets (6 palettes) | **Yes** | No | No | No |
| macOS menu bar app | **Yes** | No | Yes | No |
| TUI dashboard with sparklines | **Yes** | No | No | No |
| iOS companion app | **Yes** | No | No | No |
| Custom plugin modules | **Yes** | No | No | No |
| Webhook notifications | **Yes** | No | No | No |
| Setup wizard | **Yes** | No | No | No |
| 20+ configurable modules | **Yes** | No | No | No |

## Install

### Homebrew (macOS/Linux)

```bash
brew install ronrefael/tap/sonde
```

### From source

```bash
cargo install --git https://github.com/ronrefael/sonde --locked
```

### Quick install script

```bash
curl -sSf https://raw.githubusercontent.com/ronrefael/sonde/main/install.sh | bash
```

### Build locally

```bash
git clone https://github.com/ronrefael/sonde && cd sonde
cargo build --release
# Binary at target/release/sonde
```

## Quick Start

### 1. Auto-configure Claude Code

```bash
sonde setup
```

This detects Claude Code, validates your OAuth token, and writes the `statusLine` config to `~/.claude/settings.json` (with backup).

### 2. Or configure manually

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "command": "sonde"
  }
}
```

### 3. Verify installation

```bash
sonde doctor
```

Runs 9 diagnostic checks: Claude Code installed, OAuth token, API connectivity, config validity, cache permissions, terminal colors, and Nerd Font glyphs.

## Themes

sonde ships with 6 named theme presets. Set `theme` in your config:

```toml
[sonde]
theme = "dracula"   # catppuccin-mocha (default), dracula, tokyo-night, nord, gruvbox, solarized-dark
```

Preview all themes in your terminal:

```bash
sonde themes
```

| Theme | Base | Accent |
|-------|------|--------|
| catppuccin-mocha | Dark purple | Pastel mauve, blue, green |
| dracula | Dark grey | Purple, cyan, pink |
| tokyo-night | Deep blue | Lavender, teal, green |
| nord | Polar blue | Frost blue, cyan, green |
| gruvbox | Warm dark | Orange, yellow, green |
| solarized-dark | Teal-black | Violet, blue, yellow |

## Commands

| Command | Description |
|---------|-------------|
| `sonde` | Render statusline (default, reads JSON from stdin) |
| `sonde tui` | Full-screen terminal dashboard |
| `sonde setup` | Interactive setup wizard |
| `sonde doctor` | System health check (9 diagnostics) |
| `sonde themes` | Preview all 6 theme palettes |
| `sonde version` | Print version |

## Modules

| Module | Token | Description |
|--------|-------|-------------|
| model | `$sonde.model` | Current model name (Opus, Sonnet, Haiku) |
| cost | `$sonde.cost` | Session cost in USD |
| context_bar | `$sonde.context_bar` | Visual progress bar of context window usage |
| context_window | `$sonde.context_window` | Token counts (e.g., 20k/200k) |
| usage_limits | `$sonde.usage_limits` | 5-hour and 7-day utilization with reset countdowns |
| promo_badge | `$sonde.promo_badge` | Peak/off-peak 2X/3X promo status |
| pacing | `$sonde.pacing` | 6-tier burn rate with time-to-limit prediction |
| codex_cost | `$sonde.codex_cost` | Running Codex session cost |
| cursor | `$sonde.cursor` | Cursor IDE session cost |
| windsurf_cost | `$sonde.windsurf_cost` | Windsurf/Codeium session cost |
| copilot_cost | `$sonde.copilot_cost` | GitHub Copilot status |
| gemini_cost | `$sonde.gemini_cost` | Google Gemini Code Assist status |
| combined_spend | `$sonde.combined_spend` | Total across all providers |
| session_clock | `$sonde.session_clock` | Elapsed session time |
| git_branch | `$sonde.git_branch` | Current git branch |
| active_sessions | `$sonde.active_sessions` | Count of parallel Claude sessions |
| model_suggestion | `$sonde.model_suggestion` | Switch-model suggestions at thresholds |
| mascot_icon | `$sonde.mascot_icon` | Animated status icon |
| agent | `$sonde.agent` | Agent name badge |
| worktree | `$sonde.worktree` | Worktree name |
| custom | `$sonde.custom.{name}` | User-defined shell command modules |

## Pacing Tiers

| Tier | Condition | Icon | Prediction |
|------|-----------|------|------------|
| Comfortable | < 30% | check-circle | — |
| On Track | 30-60% | check | — |
| Elevated | 60-80% | warning | ~Xh Ym to limit |
| Hot | 80-100% | fire | ~Xh Ym to limit |
| Critical | >= 100% | exclamation | now |
| Runaway | > 90% absolute | ban | — |

When 2X promo is active, effective capacity doubles and pacing adjusts automatically.

## Configuration

sonde looks for config in this order:

1. `$SONDE_CONFIG` environment variable
2. `./sonde.toml` (project-local)
3. `~/.config/sonde/sonde.toml` (XDG)
4. `~/.sonde.toml` (home fallback)

### Default config

```toml
[sonde]
theme = "catppuccin-mocha"
lines = [
  "$sonde.model $sonde.session_clock $sonde.context_bar $sonde.usage_limits $sonde.pacing $sonde.agent $sonde.worktree",
  "$sonde.promo_badge"
]

[sonde.context_bar]
width              = 10
warn_threshold     = 40.0
critical_threshold = 70.0

[sonde.usage_limits]
five_hour_format   = " 5h {pct}% ({reset})"
seven_day_format   = " 7d {pct}% ({reset})"
warn_threshold     = 60.0
critical_threshold = 80.0
ttl                = 60

[sonde.pacing]
enabled        = true
promo_aware    = true
show_prediction = true

[sonde.promo_badge]
enabled = true

[sonde.mascot]
enabled  = true
frame_ms = 250
```

### Custom modules

```toml
[sonde.custom.cpu]
command = "top -l 1 | awk '/CPU usage/ {print $3}'"
style   = "fg:#7dcfff"
```

Use as `$sonde.custom.cpu` in your `lines` config.

### Webhook notifications

```toml
[sonde.notifications]
webhook_url        = "https://hooks.slack.com/services/T.../B.../..."
thresholds         = [80.0, 95.0]
rate_limit_minutes = 5
```

Auto-detects Slack, Discord, or generic webhook format from URL.

### Multi-account

```toml
[sonde.accounts.work]
credential_service = "Claude Code Work-credentials"

[sonde.accounts.personal]
credential_service = "Claude Code-credentials"
```

```bash
sonde --account work
```

## TUI Dashboard

Run `sonde tui` for a full-screen terminal dashboard:

- Live session info with animated mascot
- 5-hour and 7-day usage bars
- Pacing tier indicator
- 24-hour usage history sparkline
- Active sessions list with context bars
- Auto-refreshes every 30 seconds
- Press `r` to refresh, `q` or `Esc` to quit

## macOS Menu Bar App

```bash
cd SondeApp && swift build && swift run
```

Features: popover dashboard, 6 SwiftUI themes, usage gauges, pacing tier, active sessions, and macOS notifications at 60/80/90% thresholds.

## iOS Companion App

The iOS companion connects via iCloud to show usage data on your phone with widgets for the home screen.

## Debugging

```bash
# Verbose logging
echo '{"model":{"display_name":"Opus"}}' | RUST_LOG=debug sonde

# Test with full context
echo '{"model":{"display_name":"Opus"},"cost":{"total_cost_usd":1.23},"context_window":{"used_percentage":42.0}}' | sonde

# Run diagnostics
sonde doctor

# Preview themes
sonde themes
```

## License

MIT
