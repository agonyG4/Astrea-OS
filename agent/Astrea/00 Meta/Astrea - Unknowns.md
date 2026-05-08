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

The intended boundary is unclear.

## Duplicate or Transitional Files
Potentially duplicated/transitional areas:
- `Core/components` top-level files and categorized subfolders.
- Bluetooth process modules exist under both `modules/bluetooth` and `modules/network`, but the active top bar imports `modules/network`.
- Paper/lockscreen files under multiple paths.

## Absolute Paths
Many QML files hardcode `/home/agony/.local/share/Astrea`.

That is correct for the live runtime inspected here, but portability is unclear.

## External Bench Dependencies
Astrea currently references:
- `/home/agony/GitHub/Bench/Look/quicklook.qml`
- `/home/agony/GitHub/Bench/StorageSense/sense.py`

See [[Astrea - External Dependencies]].

## Weather API Contract
The Weather bridge depends on external APIs and local cache.

The current API payload shape was not revalidated in this documentation pass.

## Network Backend Detail
`Core/bridge/network/manager.py` is used by Internet settings, but exact command/config behavior was not fully expanded.

## About App
`Apps/About/main.qml` is a standalone About window.

It reads system and hardware fields from `Core/bridge/system/info.py`.
