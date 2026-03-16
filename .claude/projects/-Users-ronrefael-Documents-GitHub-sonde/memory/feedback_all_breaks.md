---
name: All breaks encountered during sonde build and their fixes
description: Comprehensive list of every bug/crash hit during Phase 1-3 development, with root causes and prevention rules
type: feedback
---

## Break 1: ureq v2 vs v3 API mismatch
**Symptom:** Compile errors — `.header()` signature wrong, `.body_mut()` doesn't exist.
**Root cause:** Wrote code using ureq v3 API but Cargo.toml pinned ureq v2.
**Fix:** Changed to ureq v2 API: `AgentBuilder::new().timeout().build().get().set()` and `.into_json()`.
**Prevention:** Always check the actual version in Cargo.toml before writing API calls. Use Context7 MCP for live crate docs.

## Break 2: nu-ansi-term `.bg()` doesn't exist
**Symptom:** Compile error on `style.bg(color)`.
**Root cause:** nu-ansi-term uses `.on(color)` for background, not `.bg()`.
**Fix:** Changed `.bg(color)` to `.on(color)`.
**Prevention:** Same as above — check actual crate API docs, don't assume from memory.

## Break 3: Missing Serialize derives
**Symptom:** Compile errors when writing structs to cache.
**Root cause:** `PromoStatus` and `UsageData` only had `Deserialize`, but `cache::write_cache` requires `Serialize`.
**Fix:** Added `Serialize` to the derive macros.
**Prevention:** When a struct is both read from API and written to cache, it needs both Serialize and Deserialize.

## Break 4: Security framework Keychain access fails from SPM binaries
**Symptom:** Swift menu bar app shows no usage data — `CredentialProvider.getOAuthToken()` returns nil silently.
**Root cause:** `SecItemCopyMatching` requires Keychain entitlements that SPM-built binaries don't have.
**Fix:** Shell out to `/usr/bin/security find-generic-password -s "Claude Code-credentials" -w` instead.
**Prevention:** NEVER use Security.framework APIs in SPM-built tools. Always use the `security` CLI command for Keychain access unless building a signed .app bundle with proper entitlements.

## Break 5: Shared cache TTL too strict for cross-process reads
**Symptom:** Swift app reads Rust cache but always gets nil — cache is "expired".
**Root cause:** Rust binary writes cache with 60s TTL. By the time Swift app polls, TTL has passed. API fallback hits 429 rate limit.
**Fix:** Allow stale cache reads in Swift — skip TTL check, only reject on window-reset invalidation.
**Prevention:** When one process produces cache and another consumes it, the consumer should ALWAYS allow stale reads. Only the producer owns freshness. Consumer shows last-known-good data.

## Break 6: HTTP 429 rate limiting from duplicate API calls
**Symptom:** Usage API returns 429, Swift app shows no data.
**Root cause:** Multiple consumers (Rust binary + Swift app + test runs) all hitting the same API endpoint.
**Fix:** Swift app reads Rust cache first, only falls back to API if cache missing. Also added `OnceLock` memoization in Rust so multiple modules don't make duplicate calls.
**Prevention:** Always read shared cache before making API calls. Use per-process memoization for modules that share data.

## Break 7: UNUserNotificationCenter crashes in unbundled SPM binaries
**Symptom:** App crashes on launch with `NSInternalInconsistencyException: bundleProxyForCurrentProcess is nil`.
**Root cause:** `UNUserNotificationCenter.current()` requires a proper app bundle. SPM debug builds produce bare executables without bundles.
**Fix:** Guard with `Bundle.main.bundleIdentifier != nil` before calling any UNUserNotificationCenter API.
**Prevention:** ANY Apple framework API that depends on app bundle identity (UNUserNotificationCenter, NSUserDefaults with suite, WidgetKit, etc.) will crash in SPM-built executables. Always guard with a bundle check.

## Break 8: Two menu bar icons appeared
**Symptom:** User saw two separate sonde icons in menu bar.
**Root cause:** Launched `swift run` twice — once as a test, once for real. First process wasn't fully killed.
**Fix:** `pkill -f SondeApp` before launching to ensure clean state.
**Prevention:** Always kill existing instances before relaunching. Use `pkill -f` on the process name.
