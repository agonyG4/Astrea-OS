# Astrea Rolling Runtime Sync

Date: 2026-06-01
Branch: `codex/sync-astrea-rolling-runtime`
Runtime source of truth: `/home/agony/.local/share/Astrea-Rolling`
Target repo: `/home/agony/GitHub/Astrea-Dev`

## Summary

Synced the current live Astrea Rolling runtime into `Astrea-Dev/src` with the same repo-safe filters used by prior runtime syncs: Python caches, build output, temporary files, credentials, user data, backup folders, wallpaper payloads, and generated desktop-icon app lists stay out of the source mirror.

The branch was also fetched and checked against its upstream. After fetch, `HEAD...@{u}` reported `0 0`, so the branch was not actually one commit behind the remote at sync time. The first normal fetch failed because the local system SSH config has a bad-owner/bad-permission entry; the successful fetch used `GIT_SSH_COMMAND='ssh -F /dev/null'`.

The tracked diff before this changelog was:

```text
80 files changed, 2110 insertions(+), 507 deletions(-)
```

## Runtime Changes

### Explorer, Portal, And Cloud-Ready Listing

- Synced the Explorer file dialog and portal component updates.
- Synced multi-file drag/drop and file-operation backend fixes.
- Added the remote listing profile for rclone, GVFS, and network filesystems.
- Disabled expensive remote-directory metadata refresh, directory watching, and thumbnail warm-up paths.
- Rebuilt and installed the Explorer backend as an optimized release binary instead of the earlier debug binary.

### Settings And System Runtime

- Synced Settings page updates for Audio, Internet, Proton, Language, Components, and shared page structure.
- Added missing `en_US` and `pt_BR` i18n entries for the Astrea file dialog title and language country search UI.
- Synced audio bridge, storage auto-refresh logic, Bluetooth manager, latency/status services, and their tests.
- Removed `src/Apps/Settings/test_audio_qml.py` because it is no longer present in the live Rolling runtime.

### Windows Compatibility And Launchers

- Synced `astrea-windows-run` with the current Proton/Wine runner behavior.
- Synced launcher inventory checks and runtime launcher scripts.
- Preserved the Astrea runtime-bin launcher contract instead of relying on user-local bin copies.

### Agent Docs

- Carried forward current agent documentation updates for runtime routing, Explorer, Settings, network bridge, gaming/compatibility, and dependency notes.
- Added new agent docs for Network Bridge and Gaming/Compatibility routing.

## Hardcoded Path Sweep

- Searched `src` for `/home/agony` outside markdown/changelog files.
- Removed `/home/agony` from test fixtures in:
  - `src/System/portal/test_filechooser_portal.py`
  - `src/Core/bridge/apps/test_manager.py`
  - `src/System/tests/test_bin_launchers.py`
- Remaining `agony` strings in non-doc source are not hardcoded paths: they are test usernames or Qt application organization names.
- Remaining `/home/agony` strings are in docs and historical changelogs where they describe this machine's live runtime and validation paths.

## Review Notes

- Pre-sync backup was saved at `/tmp/astrea-dev-presync-20260601-203744`.
- `readlink -f /home/agony/.local/share/Astrea` resolved to `/home/agony/.local/share/Astrea-Rolling`.
- Final runtime dry-run showed no content drift for the synced runtime except the three intentionally repo-side test fixture path cleanups; `src/Apps/Settings/main.qml` matched the live runtime byte-for-byte and only differed in rsync timestamp reporting.
- `Data/`, `Backups/`, `Wallpapers/`, caches, target directories, token files, key files, and generated `Quickshell/desktop/apps.js` / `apps.json` were excluded from the sync.

## Validation

- `git diff --check`
- `python3 src/System/portal/test_filechooser_portal.py`
- `python3 src/Core/bridge/apps/test_manager.py`
- `python3 src/System/tests/test_bin_launchers.py`
- `python3 src/Apps/Explorer/tests/test_explorer_qml.py`
- `cargo test` in `src/Core/bridge/apps/explorer`
- `python3 src/System/scripts/test_astrea_windows_run.py`
- `python3 src/System/scripts/test_bluetooth_manager.py`
- `python3 src/System/services/test_astrea_latencyd.py`
- `python3 src/System/services/test_astrea_statusd.py`
- `python3 src/Core/bridge/system/test_storage_auto_refresh.py`
- `qmllint` on changed Explorer, Settings, and Quickshell runtime QML entrypoints
- `python3 src/Quickshell/runtime/test_component_settings.py`
- `python3 src/System/i18n/validate_i18n.py`
- `python3 -m json.tool src/System/i18n/en_US.json`
- `python3 -m json.tool src/System/i18n/pt_BR.json`
- `python3 src/System/scripts/test_astrea_gaming_settings.py`
- `python3 src/System/scripts/test_astrea_performance.py`

## Suggested Commit Title

```text
sync astrea rolling runtime and cleanup local paths
```
