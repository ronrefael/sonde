# sonde Social Media Launch Plan

## Platform Strategy

### Reddit — High-value subreddits
Target subreddits where Claude Code users congregate. Reddit rewards genuine utility posts with screenshots, not hype.

**Primary targets:**
- r/ClaudeAI (169k members) — main Claude community
- r/LocalLLaMA (470k) — technical AI users
- r/MacApps (95k) — macOS utility hunters
- r/commandline (250k) — terminal tool enthusiasts

**Secondary targets:**
- r/SideProject — indie dev appreciation
- r/rust — Rust community loves well-built CLI tools
- r/swift — SwiftUI menu bar app angle

### Threads — Visual, personal, storytelling
Threads rewards personality and visual content. Short threads (3-5 posts) with images perform best.

---

## Post Templates

### Reddit Post 1: r/ClaudeAI (Tonight — Main Launch)

**Title:** `I built a real-time usage monitor for Claude Code — never get surprised by rate limits again`

**Body:**

```
I kept getting blindsided by rate limits during deep coding sessions. No warning, no countdown, just... stopped. So I built sonde.

**What it does:**
- Sits in your macOS menu bar showing remaining capacity: ✓ | 2X | 92% | 3h21m
- Click to see a full dashboard with usage gauges, pacing prediction, and active sessions
- Also renders as a powerline statusline directly in Claude Code
- Tells you when 2X promo is active (did you know Claude has off-peak 2X capacity? Most people don't)

**The promo thing is the killer feature.** Claude doubles your limits during off-peak hours (before 8 AM, after 2 PM weekdays, all weekend). sonde tracks this automatically and tells you:
- Whether 2X is active right now
- How long until it ends
- Your effective burn rate accounting for the multiplier

**Tech stack:** Rust CLI (renders in <50ms) + native SwiftUI macOS app. 102 tests. 6 themes.

`brew install ronrefael/tap/sonde` or `sonde setup` to auto-configure.

[Screenshot of menu bar + dashboard]
[Screenshot of terminal statusline]

GitHub: github.com/ronrefael/sonde

Would love feedback — what else would you want to see in the dashboard?
```

---

### Reddit Post 2: r/MacApps

**Title:** `sonde — a menu bar app that monitors your Claude Code AI usage in real-time [open source]`

**Body:**

```
I made a native SwiftUI menu bar app for monitoring Claude Code usage. Open source, no account needed — it reads from your existing Claude Code OAuth.

Features:
- Menu bar shows: pace icon | promo status | remaining % | timer countdown
- Dashboard with 5h and 7d usage gauges
- 7-day usage history chart
- Active session tracking across multiple projects
- 6 themes including a gorgeous Liquid Glass mode
- Pacing prediction ("you'll hit your limit in ~2h 15m")
- Promo awareness (2X off-peak detection)
- Settings tab with custom chip pickers (pretty proud of these)

Also includes a Rust-powered terminal statusline with powerline arrows.

[Screenshot of Liquid Glass theme]
[Screenshot of System dark theme]
[Screenshot of Terminal theme]
[Screenshot of settings tab]

GitHub: github.com/ronrefael/sonde
Install: brew install ronrefael/tap/sonde
```

---

### Reddit Post 3: r/commandline

**Title:** `sonde: a <50ms Rust statusline for Claude Code with 6 powerline themes, pacing prediction, and promo detection`

**Body:**

```
Built a Rust CLI that renders AI usage data as a powerline statusline for Claude Code.

- 20+ configurable modules (model, context bar, usage limits, pacing, promo, git branch, etc.)
- 6 theme palettes: catppuccin-mocha, dracula, tokyo-night, nord, gruvbox, solarized-dark
- Predictive pacing: tells you when you'll hit your rate limit
- Promo detection: knows when Claude's 2X capacity is active
- Renders in <50ms with 102 tests and zero clippy warnings
- Plugin system: add custom modules via shell commands
- sonde setup auto-configures Claude Code in seconds
- sonde doctor runs 9 diagnostic checks

[Screenshot of all 6 themes side by side from `sonde themes`]
[Screenshot of statusline in Claude Code]

brew install ronrefael/tap/sonde

Source: github.com/ronrefael/sonde
```

---

### Reddit Post 4: r/rust (Tomorrow)

**Title:** `Wrote a 6k LOC Rust CLI that renders a real-time AI usage statusline in <50ms — learnings and architecture`

**Body:**

```
sonde is a statusline binary for Claude Code that monitors usage, rate limits, and promotions. Here's what I learned building it:

**Architecture:**
- Module pattern: each module is `pub fn render(ctx: &Context, cfg: &SondeConfig) -> Option<String>`
- OnceLock memoization for API calls (multiple modules share data without duplicate requests)
- Cache with TTL + window-reset invalidation (5h window resets invalidate usage cache)
- Powerline renderer with auto-compact (abbreviate text → drop low-priority modules → fit any terminal width)
- 6 named theme palettes as static data (zero allocation)

**Security model:**
- OAuth token: NEVER written to disk, cache, stdout, or stderr
- Retrieved from macOS Keychain via `security` command, held in memory only for API call duration
- All diagnostics via tracing to stderr, stdout owned only by main.rs

**Testing:**
- 102 unit tests, rstest for parameterized, assert_cmd for integration
- Mock HTTP calls, never hit real APIs in tests
- Every theme × every module = valid RGB (no panics)

**Performance:**
- <50ms render time in release mode
- Terminal width detection: stderr fd (correct for split panes) → COLUMNS → /dev/tty → 80 fallback

6 themes, 20+ modules, custom plugin system, webhook notifications.

Repo: github.com/ronrefael/sonde
```

---

### Threads Post 1 (Tonight — Lead with visual)

**Post 1/4:**
```
Built something I've wanted for months.

A real-time AI usage monitor that sits in your Mac menu bar.

One glance: ✓ | 2X | 92% | 3h21m

Never get surprised by rate limits again.

[Screenshot of menu bar + full dashboard open]
```

**Post 2/4:**
```
The killer feature: promo awareness.

Did you know Claude Code DOUBLES your limits during off-peak hours?

Before 8 AM, after 2 PM, all weekend = 2X capacity.

sonde detects this automatically. Shows you when it's active and how long it lasts.

Most people have no idea this exists.

[Screenshot of 2X Active badge in dashboard]
```

**Post 3/4:**
```
Also runs as a terminal statusline directly in Claude Code:

 Opus  [████░░░░░░] 42%  5h 20%  7d 39%  ⚡ 92%
 2X — Off-peak limits active  10h32m left

6 powerline themes. Renders in <50ms. 102 tests.

[Screenshot of terminal with themes]
```

**Post 4/4:**
```
It's called sonde.

French for "probe" — like the atmospheric instruments that transmit weather data back to observers.

sonde transmits your AI usage data back to you.

Open source. Rust + SwiftUI. Free forever.

github.com/ronrefael/sonde

brew install ronrefael/tap/sonde
```

---

### Threads Post 2 (Tomorrow — Behind the scenes)

**Post 1/3:**
```
The most satisfying part of building sonde:

The settings screen.

Custom chip pickers that match every theme. Hover animations. No stock macOS dropdowns.

6 themes and every single UI element adapts.

[Screenshot of settings in Synthwave theme]
[Screenshot of settings in System light theme]
```

**Post 2/3:**
```
Security detail that matters:

Your Claude OAuth token is NEVER written to disk.

Not to cache. Not to logs. Not to stdout.

Retrieved from macOS Keychain, held in memory for one API call, then dropped.

This is how auth should work in developer tools.
```

**Post 3/3:**
```
What's next for sonde:

→ VS Code extension (status bar widget)
→ Raycast extension (quick view)
→ Apple Watch complication (usage ring on your wrist)
→ Landing page at sonde.dev

Star it if you want to follow along: github.com/ronrefael/sonde
```

---

## Screenshots to Capture

Take these screenshots before posting:

1. **Menu bar hero** — Menu bar showing `✓ | 2X | 92% | 3h21m` with dashboard open below
2. **Dashboard full** — System dark theme, all cards visible
3. **Promo badge** — Close-up of `⚡ 2X Active · 12h30m` badge
4. **Terminal themes** — Output of `sonde themes` showing all 6 palettes
5. **Statusline in Claude Code** — Real session with powerline rendering
6. **Settings** — Synthwave theme showing chip pickers
7. **Settings light** — System light theme for contrast
8. **Usage chart** — 7-day bar chart with varied data
9. **Multi-session** — Activity card showing 3+ projects
10. **sonde doctor** — All 9 checks passing

## Timing Strategy

**Tonight (Thursday):**
- 9:30 PM: Post Threads thread (4 posts with images)
- 10:00 PM: Post to r/ClaudeAI (highest-value target)

**Friday morning:**
- 8:00 AM: Post to r/MacApps
- 10:00 AM: Post to r/commandline
- Cross-post link in r/ClaudeAI comments if it gains traction

**Saturday:**
- Post to r/rust (technical deep-dive, weekends get more thoughtful engagement)
- Post to r/SideProject

**Monday:**
- Threads follow-up post with engagement numbers
- r/swift post about the SwiftUI menu bar app architecture

## Engagement Rules

1. **Reply to every comment** within the first 2 hours — Reddit algorithm rewards active OPs
2. **Ask questions back** — "What else would you want to see?" drives comments
3. **Be genuine about limitations** — "Yeah, the 5h timer shows 'now' when it just reset, working on that" builds trust
4. **Don't cross-post simultaneously** — space them out so each community feels like they're getting original content
5. **Pin a comment** with install instructions + key screenshots on each Reddit post
6. **Use Reddit's image gallery** feature (up to 20 images) — posts with images get 3-5x more engagement than text-only
