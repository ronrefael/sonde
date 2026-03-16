---
name: sonde Phase 1 complete
description: Phase 1 Rust statusline binary is built and working with all 8 modules, live API integration, TOML config, and 41 passing tests
type: project
---

Phase 1 of sonde (Rust statusline binary) was built from scratch on 2026-03-16.

**Why:** Ron wanted a unified AI usage monitoring tool for Claude Code + Codex that sits in the terminal statusline with promo awareness, pacing, and combined spend tracking.

**How to apply:** The binary is fully functional. All 8 modules render correctly. Live API calls work (OAuth usage + PromoClock). Next steps would be Phase 2 (Swift macOS menu bar app) or enhancements to Phase 1 (more modules, install script, CI/CD, README polish).

Key facts:
- 41 unit tests all pass
- Release binary is 2.6 MB (stripped, LTO)
- Runs in ~200ms (dominated by API calls; cached runs will be faster)
- Live PromoClock API integration confirmed working
- Live OAuth usage API integration confirmed working (token from macOS Keychain)
- ureq v2 API (not v3) is what's in Cargo.toml
