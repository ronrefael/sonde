# Sonde Theme — Status Bar Redesign & Theme System

**Date:** 2026-03-20
**Status:** Approved

## Overview

Redesign the status bar layout and introduce a new "Sonde" theme with a cohesive color palette that works across both the Rust terminal powerline and the Swift macOS menu bar app, with full dark/light mode support.

## 1. Status Bar Layout Redesign

### New segment order (left to right)

```
[sonde] [branch] [model] [5h usage] [7d usage] [pace tier] [context bar]
```

**Line 2 (conditional — only when promo is active):**
```
[promo badge]
```

### Segment details

| # | Segment | Source | Content | Example |
|---|---------|--------|---------|---------|
| 1 | **Project** | `ctx.workspace.project_dir` (last path component) | Project name | `sonde` |
| 2 | **Branch** | existing `git_branch` module | Git branch with icon | ` main` |
| 3 | **Model** | existing `model` module | Model name; append `(1M)` when Opus with 1M context | `Opus 4.6 (1M)` |
| 4 | **5h usage** | existing `usage_limits` module (5h window only) | Keep current format | `5h 3% (3h51m)` |
| 5 | **7d usage** | existing `usage_limits` module (7d window only) | Keep current format; show `Xd Xh` when > 24h | `7d 2% (156h56m)` or `7d 84% (1d 2h42m)` |
| 6 | **Pace tier** | existing `pacing` module | Tier icon + label (no percentage) | ` Comfortable` |
| 7 | **Context bar** | existing `context_bar` module | Bar with percentage | `[━━╌╌╌╌╌╌╌╌] 18%` |

### Removed from status bar

- `session_clock` — removed from default layout
- `active_sessions` — removed from default layout
- `mascot_icon` — removed from default layout
- `model_suggestion` — removed from default layout
- Promo "Off-peak in Xh" countdown — hidden when not in active promo period

### New module: `sonde.project`

- **File:** `src/modules/project.rs`
- **Source:** `ctx.workspace.project_dir` — extract last path component
- **Fallback:** `ctx.cwd` last path component
- **Returns:** `None` if no workspace data available

### Promo badge behavior change

- **Active promo:** Show as before — ` 2X Off-peak  4h12m left`
- **No active promo:** Return `None` (hide entirely, no countdown)

### Model display change

- Detect Opus with 1M context: append `(1M)` to model name
- Sonnet/Haiku: show as-is (no context suffix)

### Pacing display change

- Show tier icon + label only (e.g., ` Comfortable`)
- Remove the remaining percentage number
- Keep prediction text if `show_prediction` is enabled

### Per-model powerline colors

The model segment background color changes based on which model is active:
- Opus → mauve/purple
- Sonnet → amber/gold
- Haiku → mantle/dark blue

This requires the renderer to detect the model name and select the appropriate color from the theme palette, rather than using a fixed module color.

## 2. Color Palette — "Sonde" Theme

### Dark Mode (Catppuccin Mocha-inspired)

All colors are from or inspired by Catppuccin Mocha. Text on segments uses base `#1E1E2E` for light backgrounds, text `#CDD6F4` for dark backgrounds.

| Role | RGB | Hex | Name |
|------|-----|-----|------|
| sonde (project) | `(30, 30, 46)` | `#1E1E2E` | base |
| branch | `(69, 71, 90)` | `#45475A` | surface1 |
| Opus model | `(203, 166, 247)` | `#CBA6F7` | mauve |
| Sonnet model | `(235, 190, 100)` | `#EBBE64` | amber (custom) |
| Haiku model | `(24, 24, 37)` | `#181825` | mantle |
| 5h usage | `(148, 226, 213)` | `#94E2D5` | teal |
| 7d usage | `(137, 220, 235)` | `#89DCEB` | sky |
| Comfortable | `(166, 227, 161)` | `#A6E3A1` | green |
| On Track | `(180, 190, 254)` | `#B4BEFE` | lavender |
| Elevated | `(249, 226, 175)` | `#F9E2AF` | yellow |
| Hot | `(235, 160, 172)` | `#EBA0AC` | maroon |
| Runaway | `(150, 60, 85)` | `#963C55` | blood (custom) |
| context bar | `(116, 199, 236)` | `#74C7EC` | sapphire |
| promo badge | `(250, 179, 135)` | `#FAB387` | peach |

### Light Mode (Catppuccin Latte-inspired)

Deeper/saturated variants for readability on light backgrounds. Text on segments uses base `#EFF1F5` (white) for saturated backgrounds, text `#4C4F69` for light backgrounds.

| Role | RGB | Hex | Name |
|------|-----|-----|------|
| sonde (project) | `(220, 224, 232)` | `#DCE0E8` | surface0 |
| branch | `(188, 192, 204)` | `#BCC0CC` | surface1 |
| Opus model | `(136, 57, 239)` | `#8839EF` | mauve |
| Sonnet model | `(180, 135, 35)` | `#B48723` | amber (custom) |
| Haiku model | `(156, 160, 176)` | `#9CA0B0` | overlay0 |
| 5h usage | `(23, 146, 153)` | `#179299` | teal |
| 7d usage | `(4, 165, 229)` | `#04A5E5` | sky |
| Comfortable | `(64, 160, 43)` | `#40A02B` | green |
| On Track | `(114, 135, 253)` | `#7287FD` | lavender |
| Elevated | `(223, 142, 29)` | `#DF8E1D` | yellow |
| Hot | `(230, 69, 83)` | `#E64553` | maroon |
| Runaway | `(210, 15, 57)` | `#D20F39` | red |
| context bar | `(32, 159, 181)` | `#209FB5` | sapphire |
| promo badge | `(254, 100, 11)` | `#FE640B` | peach |

### Zero-collision guarantee

All 14 segment colors are unique. No two adjacent segments will ever share the same color regardless of model, pace tier, or promo state. This was verified across all 3 models x 5 pace tiers x 2 promo states = 30 combinations.

### Pace tier color semantics

The pace tier colors form a severity gradient:
- **Comfortable** (green) — all good
- **On Track** (lavender) — normal usage rate
- **Elevated** (yellow) — caution, usage climbing
- **Hot** (maroon) — high usage, slow down
- **Runaway** (blood/dark red) — near limit, critical

Each tier is progressively more alarming. Hot→Runaway darkens rather than brightens, conveying severity through depth rather than saturation.

## 3. Implementation — Rust Terminal (`src/themes.rs`)

### New theme: `"sonde"`

Add a new `SONDE_MODULES` static and `SONDE` palette to `src/themes.rs`, following the existing pattern.

**Dark/light mode detection in terminal:**

Add a function to detect terminal background brightness:
1. Check `COLORFGBG` env var (format: `fg;bg` — bg > 6 typically means light)
2. Fall back to dark mode as default

The `get_palette` function will accept a `"sonde"` name and return either dark or light variant based on detection.

### New module colors in palette

The `sonde` palette needs entries for all new module names:
- `sonde.project` — project segment
- `sonde.usage_5h` — 5-hour usage (split from `sonde.usage_limits`)
- `sonde.usage_7d` — 7-day usage (split from `sonde.usage_limits`)

### Module changes

#### New: `src/modules/project.rs`
```rust
pub fn render(ctx: &Context, cfg: &SondeConfig) -> Option<String>
```
Extracts project name from `ctx.workspace.project_dir` or `ctx.cwd`.

#### Modified: `src/modules/usage_limits.rs`
Split into two separate render functions or make the existing one configurable to render only the 5h or 7d window. This allows them to be separate powerline segments with different colors.

Option A: Two new modules `usage_5h` and `usage_7d` that each render one window.
Option B: Keep one module but add a config option for which window to show.

**Recommended: Option A** — cleaner separation, each gets its own powerline color.

#### Modified: `src/modules/pacing.rs`
- Remove the percentage from output
- Show only icon + tier label: ` Comfortable`

#### Modified: `src/modules/promo_badge.rs`
- When `is_offpeak == false`: return `None` (hide entirely)
- Remove the "Off-peak in Xh" countdown

#### Modified: `src/modules/model.rs`
- Detect Opus with 1M context window and append `(1M)`
- Requires access to context window data

#### Modified: `src/renderer.rs`
- Per-model powerline colors: detect model name from context and override the model segment's bg color
- Update `module_priority` for new modules
- Update `abbreviate` for new segment text patterns
- Update default powerline lines to new segment order

#### Modified: `src/config.rs`
- Add default lines for sonde theme
- Add config entries for new modules

### Default powerline lines (sonde theme)

```toml
[sonde]
theme = "sonde"
lines = [
    "$sonde.project $sonde.git_branch $sonde.model $sonde.usage_5h $sonde.usage_7d $sonde.pacing $sonde.context_bar",
    "$sonde.promo_badge"
]
```

## 4. Implementation — Swift Menu Bar (`PopoverView.swift`)

### New theme case: `.sonde`

Add to `PopoverTheme` enum:
```swift
case sonde = "Sonde"
```

### Theme color mapping

Map the 14-color palette to the ~20 theme properties:

| Theme Property | Dark Mode | Light Mode |
|----------------|-----------|------------|
| `popoverBackground` | `#1E1E2E` (base) | `#EFF1F5` (latte base) |
| `cardBackground` | `#313244` (surface0) | `#FFFFFF` (white) |
| `textPrimary` | `#CDD6F4` (text) | `#4C4F69` (latte text) |
| `textSecondary` | `#A6ADC8` (subtext0) | `#6C6F85` (latte subtext1) |
| `headerAccent` | `#74C7EC` (sapphire) | `#209FB5` (latte sapphire) |
| `borderColor` | `#45475A` opacity 0.5 | `#BCC0CC` opacity 0.6 |
| `dividerColor` | `#45475A` opacity 0.3 | `#BCC0CC` opacity 0.4 |
| `footerText` | `#6C7086` (overlay0) | `#8C8FA1` (latte overlay0) |
| `lowUtilColor` | `#A6E3A1` (green) | `#40A02B` (latte green) |
| `medUtilColor` | `#F9E2AF` (yellow) | `#DF8E1D` (latte yellow) |
| `highUtilColor` | `#F38BA8` (red) | `#D20F39` (latte red) |
| `costHighColor` | `#F38BA8` (red) | `#D20F39` (latte red) |
| `costMedColor` | `#FAB387` (peach) | `#FE640B` (latte peach) |
| `highlightAccent` | `#89DCEB` (sky) | `#04A5E5` (latte sky) |
| `modelOpusColor` | `#CBA6F7` (mauve) | `#8839EF` (latte mauve) |
| `modelSonnetColor` | `#EBBE64` (amber) | `#B48723` (latte amber) |
| `modelHaikuColor` | `#181825` (mantle) | `#9CA0B0` (latte overlay0) |
| `modelPillText` | `#1E1E2E` (base) for light pills, `#CDD6F4` for dark pills | `#EFF1F5` for saturated pills, `#4C4F69` for light pills |
| `swatchColor` | `#CBA6F7` (mauve) | `#8839EF` (latte mauve) |

### Dark/light mode behavior

The `.sonde` theme supports dark/light mode the same way `.system` does:
- Reads `@AppStorage("appearanceMode")` — `"auto"`, `"light"`, `"dark"`
- Auto mode: follows `@Environment(\.colorScheme)` from macOS
- Shows the light/dark toggle in Settings (like System theme does)

### Theme visual properties

| Property | Value |
|----------|-------|
| `preferMonospaced` | `false` |
| `hasScanlines` | `false` |
| `textGlow` | `nil` |
| `cardGlow` | subtle mauve glow `#CBA6F7` opacity 0.06 |

## 5. File Changes Summary

### New files (2)
- `src/modules/project.rs` — project name module
- `src/modules/usage_5h.rs` — 5-hour usage module (or refactor existing)
- `src/modules/usage_7d.rs` — 7-day usage module (or refactor existing)

### Modified files — Rust
- `src/themes.rs` — add `SONDE` / `SONDE_LIGHT` palettes with dark/light detection
- `src/modules/mod.rs` — register new modules (`project`, `usage_5h`, `usage_7d`)
- `src/modules/pacing.rs` — remove percentage, show icon + label only
- `src/modules/promo_badge.rs` — hide when not in active promo
- `src/modules/model.rs` — append `(1M)` for Opus
- `src/renderer.rs` — per-model colors, new default lines, updated priorities
- `src/config.rs` — new module configs, default sonde lines
- `src/context.rs` — no changes needed (workspace data already available)

### Modified files — Swift
- `SondeApp/Sources/SondeApp/PopoverView.swift` — add `.sonde` case to `PopoverTheme` with all color properties, dark/light support

## 6. Migration

- The `"sonde"` theme becomes the new default for fresh installs
- Existing users keep their current theme — no forced migration
- The theme is available in the Settings theme picker alongside existing themes
