---
name: sonde project status — all phases complete
description: Full project status after marathon build — Rust statusline + Swift menu bar app with onboarding, themes, promo awareness
type: project
---

## Project Status (2026-03-20)

sonde is feature-complete with Rust statusline (13 modules) + macOS menu bar app (SwiftUI) + guided onboarding.

### Architecture
- **Rust binary** (`src/`): 13 render modules, reads Claude Code stdin JSON, writes session cache
- **Swift app** (`SondeApp/`): Menu bar popover dashboard, floating watcher, toast notifications, 6-step onboarding
- **Bidirectional cache**: Swift polls OAuth API → writes `~/Library/Caches/sonde/usage_limits.json` → Rust reads it. Rust writes `session_data.json` → Swift reads it.
- **Self-sufficient**: Swift app works without Claude Code running (polls API directly)

### Features built
- 13 Rust statusline modules (model, cost, context, usage, promo, pacing, codex, git, sessions, etc.)
- **6-step guided onboarding** (welcome, Claude check, auth check, statusline config, theme picker with live preview, done)
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
- Error banners (Claude not installed, auth missing, data stale, rate limited)
- 6 menu bar themes: Liquid Glass, System (light+dark), Terminal, Cyberpunk, Synthwave, Solar Flare
- Cost features removed (026354f) — estimated data was unreliable
- Messages API fallback for usage data (a15c8f2) — fixes 429 rate limiting

### Recent changes (2026-03-20)
- Fixed onboarding: replaced broken TabView with switch-based navigation
- Fixed white-on-white text: forced `.preferredColorScheme(.light)` at outer level
- Added live theme preview card in onboarding theme picker step
- Fixed `~/.claude/` sandbox entitlement from read-only to read-write (statusline config writes)
- Fixed statusline preview clipping with `.fixedSize()`

### Distribution
- GitHub Actions CI (Rust test/clippy/fmt + Swift build)
- Release workflow (4 platform binaries + DMG on tag push)
- Homebrew tap at `ronrefael/homebrew-tap`
- Install script (`curl | bash`)
- v0.1.0 tagged

### Remaining
- Publish to crates.io (needs `cargo login`)
- README screenshots + animated demo GIF
- WidgetKit desktop widgets (needs Xcode project)
- Multi-provider support (OpenAI, Google, Windsurf, Copilot)
- Code signing + notarization for DMG
- App icon (currently SF Symbol)
- Landing page
- VS Code extension
