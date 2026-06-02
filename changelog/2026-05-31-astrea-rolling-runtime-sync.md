# Astrea Rolling Runtime And Bench Sync

Date: 2026-05-31
Branch: `codex/sync-astrea-rolling-runtime`
Runtime source of truth: `/home/agony/.local/share/Astrea-Rolling`
Bench source of truth: `/home/agony/GitHub/Bench`
Target repo: `/home/agony/GitHub/Astrea-Dev`

## Summary

Synced the live Astrea Rolling runtime into `Astrea-Dev/src` and refreshed the `Astrea-Dev/Bench` mirror from the current `/home/agony/GitHub/Bench` filesystem tree. The runtime sync keeps cache, build output, temporary files, credentials, and user-data paths out of the repo. The Bench sync is a filesystem mirror because `/home/agony/GitHub/Bench` is not a git repository at its root.

The tracked diff after the sync is:

```text
219 files changed, 18095 insertions(+), 18208 deletions(-)
```

The refreshed runtime and Bench mirror are included in the commit, including new Bench prototypes, Settings compatibility UI, runtime launchers, Spotlight UI modules, helper tests, and service installers.

## Runtime Changes From Git Diff

### Gaming And Windows Compatibility

- Added `src/Apps/Settings/pages/gaming/Compatibility.qml` for `.exe` / `.msi` compatibility settings.
- Updated `src/Apps/Settings/pages/gaming/Proton.qml` and the Settings entrypoint to expose the current gaming controls.
- Added and synced `src/System/scripts/astrea-windows-run` plus `test_astrea_windows_run.py` for shared Proton/Wine launch handling.
- Updated `astrea-gaming-settings` and its tests for compatibility profile save/load behavior.

### Runtime Bin Inventory

- Added user-facing launcher scripts under `src/bin`:
  - `astrea-explorer-open`
  - `astrea-settings-open`
  - `astrea-weather-open`
  - `astrea-media-open`
  - `astrea-wallpapers-open`
  - `astrea-shell`
  - `astrea-shell-rolling`
  - `astrea-gaming`
  - `astrea-gamescope-session`
  - `astrea-spatialctl`
- Kept the compiled launch/weather binaries synced from the live runtime.
- Added `src/System/tests/test_bin_launchers.py` so the launcher inventory can be checked from source.

### Lockscreen And Authentication

- Synced the current lockscreen runtime and security tests.
- Preserved the current 12/24-hour region behavior and password submission hardening.
- Synced the auth helper binary/source and added `System/services/install-auth-helper.sh` for reproducible privileged helper installation.

### Settings And System Bridges

- Synced Settings pages for Apps, Audio, Internet, Proton, Language/Region, Performance, and the new Compatibility page.
- Added region bridge support and tests under `src/Core/bridge/system`.
- Synced user profile, audio, storage, app icon, app manager, network, wallpaper, and Weather bridge changes.
- Added missing English and Brazilian Portuguese i18n entries for the new Compatibility page.
- Updated `.gitignore` to exclude Gmail / Google OAuth credentials and token files.

### Explorer, Media Viewer, And Weather

- Synced Explorer helper/backend updates, file-operation handling, AppImage handling, thumbnails, JSON handling, and tests.
- Synced Media Viewer helper/test updates.
- Synced Weather backend, daemon, CLI, UI state, current summary, alert rendering, and Weather bridge updates.

### Quickshell Runtime

- Synced bar, tray, control center, network/audio/Bluetooth process modules, desktop icons, notifications, Alt-Tab, Spotlight, and shared AppIcon changes.
- Added the current Spotlight UI module directory.
- Added status-file, tray-icon, desktop-surface, notification-history, and Now Playing test/runtime files.
- Removed stale tracked runtime state and backup files that no longer exist in the live Rolling tree.

### Audio Assets

- Synced the active live `audio/hrir.wav`; it is currently a 48 kHz, 16-channel, 0.020s WAV.
- Copied `audio/oghrir.wav` from the live runtime as a source asset.
- Removed the stale tracked PipeWire reference config because it is no longer present in the live Rolling runtime.

## Bench Mirror Changes

- Refreshed `Astrea-Dev/Bench` from `/home/agony/GitHub/Bench`.
- Updated `Bench/BlurButtons-Bench/Main.qml` to the current source version.
- Added current Bench prototypes:
  - `Bench/ComponentGallery`
  - `Bench/Email`
  - `Bench/transparency-test`
- Preserved current Bench apps still present in the source tree: BlurButtons-Bench, DualSense, LiquidGlass-Bench, Look, ScreenTime, Screenshot, launchpad, and notepad.
- Removed stale mirror directories that are no longer present in `/home/agony/GitHub/Bench`: Explorer, MacMinimizeDemo, Notifications, cavabutgood, desktop-icons, and portal.
- Excluded Python caches, build output, local tokens, OAuth client secrets, `.env`, key files, logs, and temporary files during the Bench sync.

## Review Notes

- A pre-sync backup of the dirty repo-side `src`, `Bench`, and `changelog` folders was saved at `/tmp/astrea-dev-presync-20260531-202323`.
- The live runtime path was confirmed with `readlink -f /home/agony/.local/share/Astrea`, which resolved to `/home/agony/.local/share/Astrea-Rolling`.
- The typo path `/home/agony/.local/share/Astrea-Roilling` is not the active source; the real tree is `Astrea-Rolling`.
- Post-sync dry-runs for both runtime and Bench rsync returned no pending content changes.
- No local token, secret, key, or `.env` file was found in the synced `Astrea-Dev/Bench` mirror.
- `audio/oghrir.wav` remains a review candidate because previous sync notes identified it as a duplicate HRIR candidate.
- The final commit was rebased onto the current remote `codex/sync-astrea-rolling-runtime` branch, preserving the remote review-fix commits and resolving the audio conflicts back to the live Rolling runtime state.

## Validation

- `rsync --dry-run --itemize-changes` for `Astrea-Rolling` -> `Astrea-Dev/src` with no pending content changes.
- `rsync --checksum --dry-run --itemize-changes` for `GitHub/Bench` -> `Astrea-Dev/Bench` with no pending content changes.
- `find /home/agony/GitHub/Astrea-Dev/Bench` credential scan found no token, secret, key, or `.env` files.
- `git diff --check`
- `git diff --stat`
- `git diff --name-status`
- `python3 src/System/i18n/validate_i18n.py` passed with 626 referenced keys.
- `python3 src/Core/bridge/system/test_audio_outputs.py` passed 8 tests.
- `python3 src/System/scripts/test_astrea_windows_run.py` passed 5 tests.
- `python3 src/System/scripts/test_astrea_gaming_settings.py` passed 5 tests.
- `python3 src/System/scripts/test_astrea_performance.py` passed 3 tests.
- `python3 src/System/tests/test_bin_launchers.py` passed 4 tests.
- `python3 Bench/Email/scripts/test_email_cli.py` passed 2 tests.
- `python3 Bench/Email/scripts/test_gmail_bridge.py` passed 25 tests.
- `qmllint src/Apps/Settings/pages/connectivity/Audio.qml src/Apps/Settings/pages/gaming/Compatibility.qml`

## Suggested Commit Title

```text
sync astrea rolling runtime and bench mirror
```
