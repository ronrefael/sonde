---
name: macOS sandbox container must be cleared after entitlement changes
description: Changing app entitlements requires deleting ~/Library/Containers/{bundle-id} or the app freezes/crashes on launch
type: feedback
---

macOS caches the sandbox profile per bundle ID. If you change entitlements (e.g. adding read-write access), the app will freeze or fail to open the popover because macOS is still enforcing the OLD sandbox profile.

**Why:** macOS creates a sandbox container at `~/Library/Containers/{bundle-id}/` on first launch. This container locks in the entitlements. Re-codesigning the binary does NOT update the cached profile.

**How to apply:** After ANY entitlement change to `SondeApp.entitlements`, always run:
```bash
pkill -9 -f SondeApp
rm -rf ~/Library/Containers/dev.sonde.app
rm -rf ~/Library/Group\ Containers/group.dev.sonde.app
```
Then rebuild and relaunch. Add this to the `make clean` target or do it manually before every test after entitlement changes.
