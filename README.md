# sonde

> Precision instrumentation that continuously measures AI usage and reports conditions in real-time.

sonde sits in your terminal statusline and continuously reports model, cost, context window usage, rate limits, promo status, pacing, and Codex spend — all in one place.

## What it looks like

```
 ◆  Opus  2h14m  [████░░░░░░] 42%  5h 20% (3h41m)  7d 39% (81h41m)  🟢 Comfortable
 ⚡ 2X — Off-peak limits active ⏳ 15h33m left
```

## What makes sonde different

- **Promo awareness** — shows peak/off-peak 2x status (first tool to do this)
- **Promo-aware pacing** — 6-tier burn rate that accounts for 2x capacity
- **Combined Claude + Codex view** — unified daily spend across both
- **16 tokens across 15 modules** — model, cost, context bar, usage limits, pacing, promo badge, codex cost, session clock, git branch, active sessions, model suggestions, combined spend, context window, mascot (art + icon), cursor

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
git clone https://github.com/ronrefael/sonde
cd sonde
cargo build --release
# Binary at target/release/sonde
```

### macOS Menu Bar App

```bash
cd SondeApp && swift build
swift run  # Launches menu bar app
```

The menu bar app shows a popover dashboard with usage bars, promo status, pacing tier, active session count, and fires macOS notifications at 60%/80%/90% usage thresholds.

## Configure Claude Code

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "command": "sonde"
  }
}
```

## Configuration

sonde looks for config in this order:

1. `$SONDE_CONFIG` environment variable
2. `./sonde.toml` (project-local)
3. `~/.config/sonde/sonde.toml` (XDG)
4. `~/.sonde.toml` (home fallback)

### Default config

```toml
[sonde]
theme = "powerline"   # default; also: "retro", "plain"
lines = [
  "$sonde.mascot_icon $sonde.model $sonde.session_clock $sonde.context_bar $sonde.usage_limits $sonde.pacing",
  "$sonde.promo_badge"
]

[sonde.model]
symbol = " "
style  = "bold cyan"

[sonde.context_bar]
width              = 10
style              = "fg:#7dcfff"
warn_threshold     = 40.0
warn_style         = "fg:#e0af68"
critical_threshold = 70.0
critical_style     = "bold fg:#f7768e"

[sonde.usage_limits]
five_hour_format   = " 5h {pct}% ({reset})"
seven_day_format   = " 7d {pct}% ({reset})"
warn_threshold     = 60.0
critical_threshold = 80.0
ttl                = 60

[sonde.promo_badge]
enabled = true

[sonde.mascot]
enabled  = true
frame_ms = 250

[sonde.cursor]
enabled      = true
sessions_dir = "~/.cursor"

[sonde.pacing]
enabled     = true
promo_aware = true
```

## Modules

| Module | Token | Description |
|--------|-------|-------------|
| model | `$sonde.model` | Current model name (Opus, Sonnet, Haiku) |
| cost | `$sonde.cost` | Session cost in USD |
| context_bar | `$sonde.context_bar` | Visual progress bar of context window usage |
| context_window | `$sonde.context_window` | Token counts (e.g., 20k/200k) |
| usage_limits | `$sonde.usage_limits` | 5-hour and 7-day utilization with reset countdowns |
| promo_badge | `$sonde.promo_badge` | Peak/off-peak 2x promo status |
| pacing | `$sonde.pacing` | 6-tier burn rate (Comfortable to Runaway) |
| codex_cost | `$sonde.codex_cost` | Running Codex session cost from JSONL logs |
| combined_spend | `$sonde.combined_spend` | Claude + Codex daily total |
| session_clock | `$sonde.session_clock` | Elapsed session time |
| git_branch | `$sonde.git_branch` | Current git branch |
| active_sessions | `$sonde.active_sessions` | Count of parallel Claude Code sessions |
| model_suggestion | `$sonde.model_suggestion` | Switch-model suggestions at usage thresholds |
| mascot_top | `$sonde.mascot_top` | Animated mascot top row — expression changes with session state |
| mascot_bot | `$sonde.mascot_bot` | Animated mascot bottom row |
| mascot_icon | `$sonde.mascot_icon` | Compact animated status icon — single character, color shifts with state |
| cursor | `$sonde.cursor` | Cursor IDE session cost (reads `~/.cursor/`) |

## Pacing tiers

| Tier | Condition | Emoji |
|------|-----------|-------|
| Comfortable | < 30% of expected | 🟢 |
| On Track | 30-60% | 🔵 |
| Elevated | 60-80% | 🟡 |
| Hot | 80-100% | 🟠 |
| Critical | >= 100% | 🔴 |
| Runaway | > 90% absolute | ⛔ |

When the 2x promo is active, effective capacity doubles and pacing adjusts automatically.

## TUI Dashboard

Run `sonde tui` for a full-screen terminal dashboard:
- Live session info, usage bars, pacing, and sessions list
- Auto-refreshes every 30 seconds
- Press `r` to force refresh, `q` or `Esc` to quit

## Debugging

```bash
# Verbose logging
echo '{"model":{"display_name":"Opus"}}' | RUST_LOG=debug sonde

# Test with full context
echo '{"model":{"display_name":"Opus"},"cost":{"total_cost_usd":1.23},"context_window":{"used_percentage":42.0,"total_input_tokens":15000,"total_output_tokens":5000,"context_window_size":200000}}' | sonde
```

## License

MIT
