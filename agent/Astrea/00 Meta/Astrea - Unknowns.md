# Astrea - Unknowns

Related notes: [[Astrea]], [[Astrea - External Dependencies]], [[Astrea - Patterns]]

## Compiled Backends
The internals of these compiled executables were not inspected:
- `Core/bridge/apps/explorer_backend`
- `Core/bridge/audio/music_bars_backend`
- `System/auth/auth_helper`

See [[Astrea - Explorer Backend]] and [[Astrea - Audio Bridge]].

## Autostart Ownership
The exact external autostart owner for:
- `Quickshell/shell.qml`
- `notification_daemon.py`

was not established in this pass.

## Runtime State Placement
Some runtime state lives inside the Astrea tree:
- `Quickshell/notifications/state.json`
- `Quickshell/notifications/notifications.log`
- `Quickshell/island/config/*.json`

Other runtime state lives under:
- `~/.local/state/Astrea`
- `~/.local/share/AstreaOS`
- `~/.cache/Astrea`

The intended boundary is unclear.

## Duplicate or Transitional Files
Potentially duplicated/transitional areas:
- `Core/components` top-level files and categorized subfolders.
- Bluetooth process modules exist under both `modules/bluetooth` and `modules/network`, but the active top bar imports `modules/network`.
- Paper/lockscreen files under multiple paths.
- `Apps/Wallpapers/main.qml.bak-before-polish` and `Backups/wallpapers-app` are backup material, not active app code.

## Absolute Paths
Many QML files hardcode `/home/agony/.local/share/Astrea`.

That is correct for the live runtime inspected here, but portability is unclear.

## External Bench Dependencies
Astrea currently references:
- `/home/agony/GitHub/Bench/StorageSense/sense.py` as an optional StorageSense scanner candidate.

Quick Look is disabled in Explorer. It is future work, not an active runtime dependency.

See [[Astrea - External Dependencies]].

## Weather API Contract
The Weather bridge depends on external APIs and local cache.

The current API payload shape was not revalidated in this documentation pass.

## Network Backend Detail
`Core/bridge/network/manager.py` is used by Internet settings, but exact command/config behavior was not fully expanded.

## Session Daemon Detail
`Core/bridge/astrea_sessiond.py` currently exposes a heartbeat/status scaffold and health domain. The reported socket path should not be assumed to serve requests until the implementation grows a real socket loop.

Current tests cover the status payload shape and the stable `health` state contract; they do not imply a full socket daemon.

## About App
Resolved in the current snapshot: `Apps/About/main.qml` is a standalone About window opened from the Astrea top-bar popup. See [[Astrea - About App]].

It reads system and hardware fields from `Core/bridge/system/info.py`.
