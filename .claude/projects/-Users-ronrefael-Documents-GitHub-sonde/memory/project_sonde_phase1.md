---
name: sonde project status — all phases complete
description: Full project status after marathon build session — 34 commits, 85+ files, ~13K lines across Rust + Swift
type: project
---

## Project Status (2026-03-16)

sonde is feature-complete with Rust statusline (13 modules) + macOS menu bar app (SwiftUI).

### Architecture
- **Rust binary** (`src/`): 13 render modules, reads Claude Code stdin JSON, writes session cache
- **Swift app** (`SondeApp/`): Menu bar popover dashboard, floating watcher, toast notifications
- **Bidirectional cache**: Swift polls OAuth API → writes `~/Library/Caches/sonde/usage_limits.json` → Rust reads it. Rust writes `session_data.json` → Swift reads it.
- **Self-sufficient**: Swift app works without Claude Code running (polls API directly)

### Features built
- 13 Rust statusline modules (model, cost, context, usage, promo, pacing, codex, git, sessions, etc.)
- Compact popover dashboard (no scrolling, 320x400)
- Per-project drill-down with per-task token usage
- Historical usage chart (14-day bar chart)
- Budget limits with alerts
- Export to JSON
- Floating agent watcher window
- Dynamic Island-style toast notifications
- Promo countdown + scheduling intelligence
- Session stats (lines changed, cache hits, velocity, cost/line, web searches)
- Multi-worktree aggregate tracking
- Menu bar icon customization (5 styles)
- Auto-update checker (GitHub releases)
- Launch at Login
- .app bundle with entitlements + DMG packaging

### Distribution
- GitHub Actions CI (Rust test/clippy/fmt + Swift build)
- Release workflow (4 platform binaries + DMG on tag push)
- Homebrew tap at `ronrefael/homebrew-tap`
- Install script (`curl | bash`)
- v0.1.0 tagged (release workflow may need re-run after fmt fix)

### Remaining
- Publish to crates.io (needs `cargo login`)
- README screenshots
- WidgetKit desktop widgets (needs Xcode project)
- Multi-provider support (OpenAI, Google)
- Code signing + notarization for DMG
- App icon (currently SF Symbol)
