# Sonde Quality Audit — Implementation Plan

**Date:** 2026-03-20
**Status:** Planned
**Baseline commit:** `e00789d` (pushed to remote)

## Priority Order

All fixes are ordered by severity, then by dependency (some fixes unblock others).

---

## PHASE 1: CRITICAL (Blocks Release)

### CRIT-1: PromoSchedule Will Show "2X Active" Forever After March 28

**Problem:** `PromoSchedule.swift` has hardcoded peak/off-peak logic with no promo end date. After March 28, 2026 11:59 PM PT, the promo ends but the app will keep showing "2X Active" indefinitely.

**Root cause:** The Swift app uses its own local schedule calculation (`PromoSchedule.swift`) instead of the PromoClock API. The Rust terminal correctly uses the API (`promo.rs` → `https://promoclock.co/api/status`) which has `promotionEnd` in the response.

**Fix:**
1. In `PromoSchedule.swift`, add a `promotionEnd` constant: `2026-03-28T07:59:00Z` (11:59 PM PT = 07:59 UTC next day)
2. In `nextTransition()`, check if `Date() > promotionEnd` — if so, return a struct with `isCurrentlyOffpeak: false`, `label: ""`, `countdown: ""`, `multiplier: 1`
3. In `SondeViewModel`, when `promoMultiplier == 1`, set `promoActive = false`
4. Long-term: replace `PromoSchedule.swift` with a call to the PromoClock API (same as Rust) so future promos work automatically

**Files:** `SondeApp/Sources/SondeCore/PromoSchedule.swift`, `SondeApp/Sources/SondeCore/SondeViewModel.swift`
**Risk:** Low — additive check
**Test:** Set system clock to March 29, verify no promo badge shows

---

### CRIT-2: Cost Estimates Shown as Real Numbers

**Problem:** The Swift app's fallback path (transcript parsing) uses hardcoded per-token prices to calculate `sessionCost`. This is displayed as `$X.XX` with no "estimated" qualifier. Prices vary by model version and caching tier.

**Fix:**
1. Rename `sessionCost` to `estimatedCost` in `SessionData` and `ProjectSession`
2. In the UI where cost is displayed, prefix with `~` (e.g., `~$1.23`) when the value comes from transcript parsing (not the Rust cache)
3. Add a `isCostEstimated: Bool` flag to `SessionData` — set `true` when cost comes from `calculateCost()`, `false` when from Rust cache's `costTracker`
4. In `PopoverView` where cost is displayed, show `~` prefix and a tooltip "Estimated based on list pricing" when `isCostEstimated`

**UPDATE:** The commit `026354f` already removed all cost features: "feat: remove all cost features — estimated data is unreliable". Verify that NO cost data is displayed anywhere in the current UI. If it's fully removed, this is already fixed.

**Files:** `SondeApp/Sources/SondeCore/SessionData.swift`, `SondeApp/Sources/SondeApp/PopoverView.swift`
**Risk:** Low — UI label change or verify already removed
**Test:** Check popover for any `$` display

---

### CRIT-3: Project Name Decoding Ambiguity

**Problem:** Claude encodes project paths by replacing `/` with `-`. A project at `/Users/ron/my-project` and `/Users/ron-project` produce identical encoded strings. The `decodeProjectName` heuristic uses marker strings (`"GitHub-"`, `"Projects-"`) which don't cover all cases.

**Fix:**
1. In `decodeProjectName`, add the encoded path as a fallback tooltip/subtitle so users can see the raw encoded form
2. In the Rust session cache (`main.rs`), write the actual `project_dir` from context alongside the encoded session ID — this gives Swift the real path without needing to decode
3. In `SessionData.readFromRustSessionCache`, prefer the explicit `project_dir` field over decoding the session filename

**Files:** `src/main.rs` (add `project_dir` to session cache JSON), `SondeApp/Sources/SondeCore/SessionData.swift`
**Risk:** Medium — changes cache format, must handle backward compatibility
**Test:** Run with a project path containing dashes, verify correct name shown

---

## PHASE 2: HIGH (Should Fix Before Release)

### HIGH-1: Git Branch Decode Broken for Paths With Dashes

**Problem:** `detectGitBranch` replaces ALL `-` with `/` when decoding the project path, breaking any path with dashes in folder names.

**Fix:**
1. Use the `project_dir` from the Rust session cache (added in CRIT-3) instead of decoding the filename
2. If `project_dir` is available, use it directly for `git rev-parse`
3. Fall back to the current decode logic only when `project_dir` is missing (backward compat)

**Files:** `SondeApp/Sources/SondeCore/SessionData.swift`
**Risk:** Low — depends on CRIT-3
**Blocked by:** CRIT-3

---

### HIGH-2: Sparkline Is In-Memory Only, Not a Real Time Series

**Problem:** The sparkline accumulates one data point per poll (30s). It's not persisted, resets on app restart, and has no timestamps — so gaps from sleep/pause look like instant jumps.

**Fix:**
1. Add timestamps to each sparkline data point: `struct SparklinePoint { let timestamp: Date; let value: Double }`
2. Persist the last 30 points to the sonde cache directory as `sparkline.json`
3. On app launch, load persisted points and filter out those older than 30 minutes
4. When rendering, space points proportionally by time rather than evenly — gaps from sleep show as flat sections

**Files:** `SondeApp/Sources/SondeCore/SondeViewModel.swift`, `SondeApp/Sources/SondeApp/SparklineView.swift`
**Risk:** Medium — new persistence + rendering logic
**Test:** Kill app, wait 2 min, relaunch — sparkline should show historical data with a gap

---

### HIGH-3: 5h Elapsed Mode Hardcodes 300 Minutes

**Problem:** `elapsed = 300 - remaining` assumes 5h window is exactly 300 minutes. Not derived from actual reset timestamp.

**Fix:**
1. Calculate elapsed from `Date()` minus `(resetDate - 5*3600)` — derive the window start from the reset timestamp
2. Replace `max(0, 300 - remaining)` with `max(0, Int(Date().timeIntervalSince(windowStart) / 60))`

**Files:** `SondeApp/Sources/SondeApp/SondeApp.swift`
**Risk:** Low — arithmetic change
**Test:** Verify elapsed timer counts up correctly from window start

---

### HIGH-4: Session Timer Drifts After First Start

**Problem:** `sessionStartTime` is set once on first poll and never updated. The live timer will undercount by however many minutes passed before the app first saw the session.

**Fix:**
1. On each `refresh()`, recalculate `sessionStartTime` from the latest `sessionDurationMs`
2. Replace the `== nil` guard: always update `sessionStartTime = Date().addingTimeInterval(-Double(durationMs) / 1000.0)`
3. The timer display will self-correct every poll cycle

**Files:** `SondeApp/Sources/SondeCore/SondeViewModel.swift`
**Risk:** Low — removes a guard
**Test:** Start app after session has been running for 10 minutes, verify timer shows ~10m not 0m

---

### HIGH-5: Race Condition Between Rust Writer and Swift Reader

**Problem:** Swift enumerates cache directory and deletes stale files while Rust may be writing the same file. Not atomic.

**Fix:**
1. In `readAllRustSessionCaches`, don't delete files — let Rust manage its own cache cleanup
2. Remove the `try? fm.removeItem(at: fileURL)` call
3. In `readFromRustSessionCache`, use `try? Data(contentsOf:)` which handles concurrent access gracefully — if the file is partially written, the JSON parse will fail and return nil (which is already handled)

**Files:** `SondeApp/Sources/SondeCore/SessionData.swift`
**Risk:** Low — removing code
**Test:** Run multiple concurrent Claude Code sessions, verify no crashes

---

### HIGH-6: Rate Limited Banner Never Shows After Initial Load

**Problem:** `isLoading` is set `false` after first `refresh()` and never set back to `true`.

**Fix:**
1. Set `isLoading = true` at the start of each `refresh()` call
2. Set `isLoading = false` at the end (already done)
3. Add a `lastRefreshFailed: Bool` flag that's set when the API returns nil
4. Show the rate limited banner when `lastRefreshFailed && lastUpdated != nil` instead of `isLoading && lastUpdated != nil`

**Files:** `SondeApp/Sources/SondeCore/SondeViewModel.swift`, `SondeApp/Sources/SondeApp/PopoverView.swift`
**Risk:** Low — state management
**Test:** Block API access (disable WiFi briefly), verify banner appears

---

### HIGH-7: Stale Data Toast Fires on Every Poll (Spam)

**Problem:** "Using cached data" toast fires every 30 seconds when cache is > 2 minutes old. That's 8+ toasts per 5-minute cache cycle.

**Fix:**
1. Add a `hasShownCacheToast: Bool` flag
2. Show the toast only once per cache staleness period
3. Reset the flag when fresh data arrives

**Files:** `SondeApp/Sources/SondeCore/SondeViewModel.swift`
**Risk:** Low — boolean flag
**Test:** Wait for cache to go stale, verify only one toast appears

---

### HIGH-8: Transcript Parser Only Reads Last 64KB

**Problem:** Long sessions have transcripts >> 64KB. Token/cost totals are understated.

**Fix:**
1. Increase `readSize` to 512KB or 1MB
2. Better: read the ENTIRE file but parse line-by-line (JSONL format) without loading everything into memory — use a streaming reader
3. Or: since we removed cost features (CRIT-2), verify this only affects token counts displayed in the "tokens" stat. If token counts are also sourced from the Rust cache (which reads Claude Code's own context), then transcript parsing is only a fallback and this is lower priority

**Files:** `SondeApp/Sources/SondeCore/SessionData.swift`
**Risk:** Medium — performance impact of reading large files
**Test:** Run a long session (>64KB transcript), verify token count matches expectations

---

## PHASE 3: MEDIUM

### MED-1: PromoSchedule Uses Minute Resolution
**Fix:** Show "< 1m" instead of "0m" when countdown is under 60 seconds.
**Files:** `PromoSchedule.swift`

### MED-2: Pacing Ignores 7-Day Utilization
**Fix:** Add a check: if 7d util > 80%, bump tier by one level regardless of 5h. Display both in tooltip.
**Files:** `src/modules/pacing.rs`, `SondeCore/Pacing.swift`

### MED-3: Predict Time-to-Limit Uses Average Rate
**Fix:** Add a "(avg)" qualifier to the prediction text. Or use a rolling window rate.
**Files:** `src/modules/pacing.rs`

### MED-4: 5h Formatter Doesn't Show Days (Edge Case)
**Fix:** Add the same `>= 24` check as 7d formatter. Unlikely to trigger but defensive.
**Files:** `src/modules/usage_5h.rs`

### MED-5: "+X lines" Only Counts Added, Not Net
**Fix:** Change label to show net: `+X / -Y = Z net` (which the Activity card already does). Or change stat to `totalLinesChanged`.
**Files:** `PopoverView.swift`

### MED-6: Menu Bar Shows "sonde" When No Data
**Fix:** Show a loading indicator icon instead of text when `fiveHourUtil == nil`.
**Files:** `SondeApp.swift`

### MED-7: TimeFormatting Projects Forward in 5h Increments
**Fix:** Return "refreshing..." when reset is in the past instead of guessing. Or trigger an API fetch.
**Files:** `TimeFormatting.swift`

### MED-8: Cost Calculation Uses Display Names Not Model IDs
**Fix:** Already resolved if cost features are removed (CRIT-2). Otherwise, switch to model ID matching.
**Files:** `SessionData.swift`

### MED-9: Primary Session From Legacy File, Not Per-Session
**Fix:** Use `readAllRustSessionCaches` for the primary session too. Pick the most recently written file.
**Files:** `SessionData.swift`, `SondeViewModel.swift`

### MED-10: History Recording May Trigger Unnecessary API Call
**Fix:** Only record history if `fetch_usage` was already called during rendering (check `USAGE_MEMO`).
**Files:** `src/main.rs`

---

## PHASE 4: LOW

### LOW-1: git_branch.rs Spawns Process Every Render
**Fix:** Prefer `ctx.worktree.branch` when available, fall back to `git rev-parse` only when absent.
**Files:** `src/modules/git_branch.rs`

### LOW-2: Long Branch Names Not Truncated
**Fix:** Cap at 30 chars with `...` suffix in Rust. Swift already has `.lineLimit(1)`.
**Files:** `src/modules/git_branch.rs`

### LOW-3: Promo Label Hardcoded "2x" in Swift vs API-Driven in Rust
**Fix:** Resolved when CRIT-1 is fixed (add end date check). Long-term: use API in Swift too.

### LOW-4: Nerd Font "X" Icon for Off-Peak Countdown Is Confusing
**Fix:** Use clock icon `\uf017` instead of times icon `\uf00d` for the non-offpeak state.
**Files:** `src/modules/promo_badge.rs`

### LOW-5: abbreviate() Strips All Parenthetical Content
**Fix:** Document this behavior. Or only strip content matching `(\d+[hm]\d*[ms]?)` pattern.
**Files:** `src/renderer.rs`

### LOW-6: Onboarding Has No Skip Button
**Fix:** Add a "Skip" text button in the navigation footer on all steps.
**Files:** `OnboardingView.swift`

### LOW-7: Cache Serves Stale Data Indefinitely When API Is Down
**Fix:** Add a max-stale-age (e.g., 1 hour). After that, show "data unavailable" instead of stale numbers.
**Files:** `src/cache.rs`

### LOW-8: Promo Timer Mode Shows Blank During Peak
**Fix:** Fall back to 5h countdown when promo timer is empty.
**Files:** `SondeApp.swift`

---

## Execution Strategy

1. **Phase 1 first** — CRIT-1 is the most urgent (promo ends in 8 days)
2. **Commit after each fix** — maintain revert points
3. **Full protocol test after each Swift change** — kill all, nuke .build, nuke defaults, nuke sonde cache, rebuild, launch, verify
4. **Push after each phase** — remote backup
5. **Phases 3-4 can be batched** — lower risk, less testing needed

## Estimated Scope

| Phase | Items | Estimated files touched | Risk |
|-------|-------|------------------------|------|
| Phase 1 | 3 | 4-5 | Medium (cache format change) |
| Phase 2 | 8 | 6-8 | Low-Medium |
| Phase 3 | 10 | 8-10 | Low |
| Phase 4 | 8 | 6-8 | Low |
