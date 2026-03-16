---
name: Swift app Keychain and cache pitfalls
description: Two bugs hit during Phase 2 - Security framework needs entitlements, and shared cache TTL must allow stale reads
type: feedback
---

Two issues broke the Swift menu bar app's usage data display:

**Bug 1: Security framework Keychain access fails from SPM-built binaries.**
The initial CredentialProvider used `SecItemCopyMatching` directly. SPM-built executables don't have Keychain entitlements, so it silently returned nil. Fix: shell out to `/usr/bin/security find-generic-password` (same approach as the Rust binary).

**Why:** macOS sandboxing/entitlements. Only signed apps with proper entitlements can use Security.framework APIs directly. CLI tools built with `swift build` don't get these.

**How to apply:** Always use the `security` CLI command for Keychain access in SPM-built tools. Reserve Security.framework for signed .app bundles.

**Bug 2: Rust cache TTL too strict for Swift app reads.**
The Swift app tried to read the Rust binary's cache at `~/Library/Caches/sonde/usage_limits.json`, but rejected it because the 60s TTL had expired. When it fell back to a direct API call, it got HTTP 429 rate-limited. Result: no usage data shown.

**Why:** The Rust statusline refreshes cache on every render (triggered by Claude Code), but the Swift app polls independently. By the time Swift reads the cache, 60s has often passed.

**How to apply:** When reading another process's cache, allow stale reads (skip TTL check). Only reject on window-reset invalidation. The data producer (Rust binary) owns freshness; the consumer (Swift app) should show last-known-good data rather than nothing.
