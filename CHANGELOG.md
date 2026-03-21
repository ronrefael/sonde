# Changelog

All notable changes to sonde will be documented in this file.

## [1.0.0] — 2026-03-20

### Added
- **macOS menu bar app** — native SwiftUI dashboard with usage rings, pacing tier, time-to-limit, active sessions, 7-day chart, context bar, and promo badge
- **7 dashboard themes** — Liquid Glass, System (light/dark), Sonde, Terminal, Cyberpunk, Synthwave, Solar Flare
- **2X promo detection** — tracks Claude Code's capacity promotions via PromoClock API, adjusts pacing predictions automatically
- **Guided onboarding** — 7-step setup wizard (Claude Code check, auth, statusline, font install, theme picker)
- **Nerd Font bundled** — one-click install during onboarding and in Settings
- **App icon** — pixel-art mascot with dark rounded background
- **DMG installer** — drag-to-Applications install experience
- **Terminal statusline** — Rust-powered, renders in <50ms, 10+ configurable modules
- **7 terminal powerline themes** — catppuccin-mocha, dracula, tokyo-night, nord, gruvbox, solarized-dark, sonde
- **Nerd Font auto-detection** — icons disabled automatically if terminal font doesn't support them
- **Homebrew tap** — `brew install ronrefael/tap/sonde`
- **GitHub Actions release workflow** — automated DMG + binary builds on tag push
- **`sonde setup`** — auto-configures Claude Code statusline integration
- **`sonde doctor`** — 9 diagnostic checks
- **`sonde themes`** — preview all terminal palettes
- **Duplicate instance prevention** — kills other running Sonde instances on launch
- **Configurable menu bar** — toggle promo status, timer, choose from 7 timer modes
- **Settings panel** — theme picker, timer mode, refresh interval, Nerd Font install

[1.0.0]: https://github.com/ronrefael/sonde/releases/tag/v1.0.0
