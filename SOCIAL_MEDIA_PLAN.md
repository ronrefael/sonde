# sonde Social Media Launch Plan

## Timing

**Post Saturday morning (9-11 AM ET).** Developers browse Reddit and Threads with coffee on weekends. Late Friday night posts get buried with zero momentum.

**Saturday morning:**
- 9:00 AM: Post Threads thread (4 posts with images)
- 9:30 AM: Post to r/ClaudeAI (highest-value target)
- 11:00 AM: Post to r/MacApps

**Saturday afternoon:**
- 2:00 PM: Post to r/commandline

**Sunday:**
- Post to r/rust (technical deep-dive, weekends get more thoughtful engagement)
- Post to r/SideProject

**Monday:**
- Threads follow-up post with engagement numbers
- r/swift post about the SwiftUI menu bar app architecture

---

## Platform Strategy

### Reddit
Target subreddits where Claude Code users congregate. Reddit rewards genuine utility posts with screenshots, not hype.

**Primary targets:**
- r/ClaudeAI (169k members)
- r/LocalLLaMA (470k)
- r/MacApps (95k)
- r/commandline (250k)

**Secondary targets:**
- r/SideProject
- r/rust
- r/swift

### Threads
Threads rewards personality and visual content. Short threads (3-5 posts) with images perform best.

---

## Post Templates

### Reddit Post 1: r/ClaudeAI

**Title:** `I built a real-time usage monitor for Claude Code. Never get surprised by rate limits again.`

**Body:**

```
I kept getting blindsided by rate limits during deep coding sessions. No warning, no countdown, just... stopped. So I built sonde.

**What it does:**
- Sits in your macOS menu bar showing remaining capacity, pacing, and active promotions
- Click to see a full dashboard with usage gauges, pacing prediction, and active sessions
- Drill into per-project analytics: token counts, cache efficiency, message history, conversation breakdowns
- Also renders as a powerline statusline directly inside Claude Code

**Promotion tracking is the killer feature.** Claude Code runs capacity promotions that boost your limits. sonde monitors Claude's promotion page and detects them automatically. It shows you:
- Whether a promotion is active right now
- How long until it ends
- Your effective burn rate accounting for the boosted capacity

**Per-project token breakdown:** Tap any project to see input tokens, output tokens, cache read, cache write, cache hit %, total tokens, and individual conversations with their own stats.

**Tech stack:** Rust CLI (renders in <50ms) + native SwiftUI macOS app. 110 tests. 6 matching themes across both.

`brew install ronrefael/tap/sonde` or download Sonde.dmg from the release page.

[Screenshot of menu bar + dashboard open]
[Screenshot of terminal statusline]
[Screenshot of projects view with token breakdown]

GitHub: github.com/ronrefael/sonde

Would love feedback. What else would you want to see in the dashboard?
```

---

### Reddit Post 2: r/MacApps

**Title:** `sonde: a menu bar app that monitors your Claude Code AI usage in real-time [open source]`

**Body:**

```
I made a native SwiftUI menu bar app for monitoring Claude Code usage. Open source, no account needed. It reads from your existing Claude Code OAuth.

Features:
- Guided 6-step onboarding: detects Claude Code, validates OAuth, configures statusline, picks your theme with a live preview
- Menu bar shows: pace icon, promo status, remaining %, timer countdown
- Dashboard with 5h and 7d usage gauges
- Per-project analytics: tokens, cache %, messages, tasks, last activity
- Session detail view: full token breakdown (input, output, cache read, cache write, cache hit %, total)
- Conversation list with per-conversation stats
- 7-day usage history chart
- Active session tracking across multiple projects
- 7 themes including Liquid Glass, Terminal, Cyberpunk, Synthwave, Solarflare
- Pacing prediction ("you'll hit your limit in ~2h 15m")
- Automatic promotion detection
- Settings tab with custom chip pickers

Also includes a Rust-powered terminal statusline with powerline arrows and 6 matching themes.

[Screenshot of Liquid Glass theme]
[Screenshot of System dark theme]
[Screenshot of Terminal theme]
[Screenshot of projects view]
[Screenshot of session detail with token breakdown]
[Screenshot of settings tab]

GitHub: github.com/ronrefael/sonde
Install: brew install ronrefael/tap/sonde
```

---

### Reddit Post 3: r/commandline

**Title:** `sonde: a <50ms Rust statusline for Claude Code with 6 powerline themes, pacing prediction, and promotion detection`

**Body:**

```
Built a Rust CLI that renders AI usage data as a powerline statusline for Claude Code.

- 10+ configurable modules (model, context bar, usage limits, pacing, promo, git branch, etc.)
- 6 theme palettes: catppuccin-mocha, terminal, cyberpunk, synthwave, solarflare, sonde
- Predictive pacing: tells you when you'll hit your rate limit
- Promotion detection: knows when Claude's capacity promotions are active
- Renders in <50ms with 110 tests and zero clippy warnings
- sonde setup auto-configures Claude Code in seconds
- sonde doctor runs 9 diagnostic checks

[Screenshot of all 6 themes side by side from `sonde themes`]
[Screenshot of statusline in Claude Code]

brew install ronrefael/tap/sonde

Source: github.com/ronrefael/sonde
```

---

### Reddit Post 4: r/rust

**Title:** `Wrote a 6k LOC Rust CLI that renders a real-time AI usage statusline in <50ms`

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
- 110 unit tests, rstest for parameterized, assert_cmd for integration
- Mock HTTP calls, never hit real APIs in tests
- Every theme × every module = valid RGB (no panics)

**Performance:**
- <50ms render time in release mode
- Terminal width detection: stderr fd (correct for split panes) → COLUMNS → /dev/tty → 80 fallback

6 themes, 10+ modules, matching SwiftUI menu bar app with the same palette names.

Repo: github.com/ronrefael/sonde
```

---

### Threads Post 1 (Saturday morning, lead with visual)

**Post 1/4:**
```
Built something I've wanted for months.

A real-time AI usage monitor that sits in your Mac menu bar.

One glance tells you exactly where you stand: capacity, pacing, promotions, active sessions.

Never get surprised by rate limits again.

[Screenshot of menu bar + full dashboard open]
```

**Post 2/4:**
```
The killer feature: promotion awareness.

Did you know Claude Code runs capacity promotions that boost your limits?

sonde monitors Claude's promotion page and detects them automatically. Shows you when one is active, how long it lasts, and adjusts your pacing to account for the extra capacity.

Most people have no idea this exists.

[Screenshot of promo badge in dashboard]
```

**Post 3/4:**
```
Also runs as a terminal statusline directly in Claude Code:

 Opus  [████░░░░░░] 42%  5h 20%  7d 39%  Elevated 38%

6 powerline themes that match the menu bar app: Terminal, Cyberpunk, Synthwave, Solarflare.

Renders in <50ms. 110 tests.

[Screenshot of terminal with themes]
```

**Post 4/4:**
```
It's called sonde.

A device sent into the atmosphere to transmit measurements back to the observer. Just like a weather sonde reports conditions from the sky, sonde reports the conditions of your AI usage in real-time.

Open source. Rust + SwiftUI. Free forever.

github.com/ronrefael/sonde

brew install ronrefael/tap/sonde
```

---

### Threads Post 2 (Sunday, behind the scenes)

**Post 1/3:**
```
The most satisfying part of building sonde:

The onboarding.

6-step guided setup. One-click statusline config. And a live theme preview that updates as you tap each option. You see the dashboard colors change in real-time before you commit.

Then the settings screen. Custom chip pickers that match every theme. Hover animations. No stock macOS dropdowns.

7 themes and every single UI element adapts.

[Screenshot of onboarding theme picker with live preview]
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
→ iOS companion app
→ Apple notarization (no more xattr workaround)

Star it if you want to follow along: github.com/ronrefael/sonde
```

---

## Screenshots to Capture

Take these screenshots before posting:

1. **Menu bar hero:** Menu bar with dashboard open below
2. **Dashboard full:** System dark theme, all cards visible
3. **Promo badge:** Close-up of promotion badge in dashboard
4. **Terminal themes:** Output of `sonde themes` showing all 6 palettes
5. **Statusline in Claude Code:** Real session with powerline rendering
6. **Projects view:** Project list with token counts, cache %, messages
7. **Session detail:** Full token breakdown (input, output, cache read/write, cache hit %)
8. **Settings:** Synthwave theme showing chip pickers
9. **Settings light:** System light theme for contrast
10. **Usage chart:** 7-day bar chart with varied data
11. **Multi-session:** Activity card showing multiple projects
12. **sonde doctor:** All 9 checks passing
13. **Onboarding theme picker:** Theme selection step with live preview

## Engagement Rules

1. **Reply to every comment** within the first 2 hours. Reddit algorithm rewards active OPs
2. **Ask questions back.** "What else would you want to see?" drives comments
3. **Be genuine about limitations.** Builds trust
4. **Don't cross-post simultaneously.** Space them out so each community feels like original content
5. **Pin a comment** with install instructions + key screenshots on each Reddit post
6. **Use Reddit's image gallery** feature (up to 20 images). Posts with images get 3-5x more engagement than text-only
