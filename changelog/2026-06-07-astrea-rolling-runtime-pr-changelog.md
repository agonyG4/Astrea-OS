# Astrea Rolling Runtime PR Changelog

Date: 2026-06-07
Branch: `codex/sync-astrea-rolling-runtime`
Base: `origin/Stable`
Runtime source of truth: `/home/agony/.local/share/Astrea-Rolling`
Target repo: `/home/agony/GitHub/Astrea-Dev`

## Summary

This PR syncs the current live Astrea Rolling runtime back into `Astrea-Dev`, refreshes the Bench mirror and agent documentation, and carries forward the recent service, shell, Explorer, Settings, Spatial Audio, and system integration work.

The PR diff against `origin/Stable` is broad by design:

```text
412 files changed, 35370 insertions(+), 20180 deletions(-)
155 files added, 203 files modified, 54 files deleted
```

Top-level scope:

```text
src: 295 files
Bench: 79 files
agent: 29 files
changelog: 4 files
gitpage: 2 files
root docs/config: .gitignore, AGENTS.md, README.md
```

## Runtime Source Sync

- Refreshed `src` from the active Astrea Rolling runtime.
- Kept runtime-local noise out of the repo: cache directories, build output, temporary files, credentials, local user data, wallpaper payloads, backup files, logs, and generated desktop-icon app lists.
- Added repo structure documentation under `src/ARCHITECTURE.md`, `src/Docs`, `src/Runtime`, `src/Backend`, `src/Core`, and `src/UI`.
- Updated `.gitignore` for local data, OAuth/Gmail credentials, token files, logs, temporary files, backups, and generated runtime files.
- Removed stale tracked runtime state and backup files that no longer exist in the live Rolling tree.

## Apps

### Explorer

- Synced the current Explorer app, file dialog, portal dialog, theme, navigation state, preview state, recent state, and view components.
- Removed the old `JsonWorker.js` state file because the live runtime no longer uses it.
- Expanded helper behavior for file operations, archive extraction, trash/restore, paste handling, conflict detection, and safer path/name validation.
- Synced Rust backend updates for entries, file operations, AppImage handling, JSON output, thumbnails, devices, and remote/cloud-ready listing behavior.
- Added or expanded Explorer helper and QML regression tests.
- Rebuilt and synced the tracked Explorer backend binary.

### Settings

- Added shared `SectionOverview.qml`.
- Added new gaming pages for Compatibility, Gamescope, and Proton.
- Added system pages for Components and Services.
- Updated Apps, Audio, Internet, Personalization, Language, Performance, and Storage pages.
- Synced Settings navigation and page routing from the live runtime.
- Added i18n keys for the current Settings, gaming, language, services, and file-dialog UI.

### Media Viewer, Wallpapers, And Weather

- Added `AstreaI18n` links for Media Viewer and Wallpapers.
- Synced Media Viewer helper and test updates.
- Updated Wallpapers UI behavior from the live runtime.
- Synced Weather backend, CLI, daemon, core library, UI state, forecast sections, weather icon handling, and Weather bridge changes.

## Core Bridges And Shared Components

- Added notification bridge support in `src/Core/bridge/notifications.py` with contract tests.
- Added system services bridge support in `src/Core/bridge/system/services.py` with tests.
- Added app-icon and region bridge support.
- Updated app manager, Weather, audio, network, storage, user profile, wallpaper, and shared runtime bridge logic.
- Added shared `Core/components/AppIcon.qml`.
- Added shared notification client components and tests.
- Added the Borealis theme module under `Core/components/theme/Borealis`.
- Updated shared controls, navigation, forms, theme integration, and component module exports.

## Quickshell Runtime

- Synced bar, topbar content, clock, tray, tray icon handling, workspaces, volume popup/OSD, network, Bluetooth, and control-center UI.
- Updated control-center modules, widget library behavior, connectivity rows, media controls, sliders, and Now Playing tests.
- Synced desktop icons, desktop surface handling, and app-index generation logic.
- Synced Alt-Tab controller and view updates.
- Added Quickshell runtime component settings and service-manager modules.
- Updated Spotlight shell and added modular Spotlight panel, results list, and weather chip UI.
- Synced shared app icon behavior in both Core and Quickshell component paths.

## Island

- Refactored Island into mode host, geometry, interaction, state, and router modules.
- Added mode containers and explicit mode modules for idle, game mode, music, and email-code flows.
- Added email-code UI and `EmailEventMonitor.qml`.
- Updated Island architecture tests to cover the current modular structure.
- Synced music artwork/view behavior and game-mode notification behavior.

## Notifications

- Updated notification daemon behavior and contract coverage.
- Added notification history panel UI and tests.
- Updated `NotificationStore.qml`, notification card behavior, and notification history handling.
- Removed stale tracked notification state from the repo mirror.
- Added Astrea notification bridge/client contracts for app-facing notification metadata.

## System Layer

- Added Rust crates and source for:
  - `src/System/latencyd`
  - `src/System/portal`
  - `src/System/statusd`
- Added tracked runtime binaries:
  - `src/bin/astrea-filechooser-portal`
  - `src/bin/astrea-latencyd`
  - `src/bin/astrea-statusd`
- Added `src/bin/astrea-notify`.
- Updated existing launch, weather, and runtime launcher binaries/scripts.
- Synced service scripts for latency/status daemons, service installation, profile image helper installation, and theme decoration.
- Updated `astrea-services.sh` for the current service inventory.
- Added service tests for latency, status, services listing, and launcher inventory.
- Synced auth and Polkit agent runtime files, helper source/binary, and security tests.
- Updated gaming, performance, Windows compatibility, Bluetooth, and volume OSD scripts with tests.
- Synced the file chooser portal Python wrapper and added Rust portal implementation/tests.

## Spatial Audio And Assets

- Synced the current Spatial Audio HRIR assets and sidefix WAV payloads.
- Updated the tracked `hrir.wav` asset and added `oghrir.wav`.
- Synced Spatial Audio bridge behavior for the current Astrea spatial sink contract.
- Updated audio bridge tests and Settings Audio integration.
- Updated the control-center image asset and added current gitpage logo assets.

## Bench Mirror

- Refreshed `Bench` from the current local Bench source tree.
- Added current Bench prototypes:
  - `Bench/ComponentGallery`
  - `Bench/Email`
  - `Bench/transparency-test`
- Updated `Bench/BlurButtons-Bench`.
- Removed stale Bench mirrors that are no longer present in the source tree:
  - `Bench/Explorer`
  - `Bench/MacMinimizeDemo`
  - `Bench/Notifications`
  - `Bench/cavabutgood`
  - `Bench/desktop-icons`
  - `Bench/portal`
- Added Email bench backend, Gmail bridge, QML services, UI components, shell, README, and tests.

## Agent Docs And Changelogs

- Updated root `AGENTS.md` and the Astrea agent vault under `agent/Astrea`.
- Updated runtime snapshot, entry points, data flow, UI, Settings, bridges, system layer, assets/data, and dependency notes.
- Added Network Bridge and Gaming/Compatibility agent docs.
- Added prior granular changelogs for:
  - 2026-05-28 runtime/spatial-audio sync
  - 2026-05-31 runtime and Bench sync
  - 2026-06-01 runtime cleanup sync
  - 2026-06-02 Explorer backend performance work
- This file is the PR-level changelog that summarizes the full branch diff.

## Removed Or Cleaned Up

- Removed stale tracked Bench mirrors that no longer exist in the live Bench source.
- Removed stale Quickshell control-center backup files.
- Removed stale Explorer `JsonWorker.js`.
- Removed stale notification runtime state.
- Excluded runtime `Data`, user wallpapers, cache/build output, token files, key files, logs, temporary files, and backup artifacts from the source mirror.

## Review Notes

- This is an intentionally broad runtime sync, not a narrow feature patch.
- The PR includes tracked compiled binaries because this repo already tracks runtime binaries under `src/bin` and backend binary outputs.
- Reviewers should scan the new Rust service crates and tracked binaries together:
  - `System/latencyd`
  - `System/portal`
  - `System/statusd`
  - `src/bin/astrea-filechooser-portal`
  - `src/bin/astrea-latencyd`
  - `src/bin/astrea-statusd`
- The sync is based on the active runtime path where `/home/agony/.local/share/Astrea` resolves to `/home/agony/.local/share/Astrea-Rolling`.
- Existing granular changelogs remain useful for detailed historical context; this changelog is meant to give reviewers a single full-PR map.

## Validation

Validation performed across the branch and latest runtime sync included:

- `git diff --check`
- `git diff --cached --check`
- `python3 src/System/i18n/validate_i18n.py`
- Python unit tests for Explorer, notifications, services, notification client, Island architecture, system scripts, runtime launchers, Weather, region, audio, storage, and Bench Email where applicable
- `cargo test` or `cargo check` for changed Rust backends and services
- `qmllint` on changed Explorer, Settings, Quickshell, Island, and shared component QML
- `qs -p` smoke loads for Settings, Explorer, and Island entrypoints
- dry-run/runtime sync checks for excluded local data and generated artifacts

## Suggested PR Title

```text
Sync Astrea Rolling runtime, services, and Bench mirror
```
