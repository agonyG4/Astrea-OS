# Astrea - Core Bridge

Related notes: [[Astrea]], [[Astrea - Settings App]], [[Astrea - System Layer]], [[Astrea - Patterns]]

## Folder
`Core/bridge/`

## Responsibility
Process bridge layer between QML and system APIs.

The bridge turns system state into JSON and applies requested changes through scripts or system tools.

## Forwarding Entrypoints
- `apps.py` -> `apps/manager.py`
- `audio.py` -> `system/audio.py`
- `display.py` -> `system/display.py`
- `network.py` -> `network/manager.py`
- `storage.py` -> `system/storage.py`
- `system.py` -> `system/info.py`

## Shared Helpers
- `astrea_shared.py`
  - XDG paths, atomic writes, desktop file parsing, icon resolution, and safe command helpers.
- `state_json.py`
  - small atomic JSON state helper. See [[Astrea - State JSON Bridge]].
- `astrea_sessiond.py`
  - lightweight session daemon/status scaffold. See [[Astrea - Session Daemon]].
- `astrea_doctor.py`
  - diagnostic helper for runtime checks.

## System Info
`Core/bridge/system/info.py` returns JSON for system and hardware identity.

Consumers include:
- [[Astrea - Settings App]] System page
- `Apps/About/main.qml`

The About app uses this bridge as a single process instead of spawning separate shell commands for OS, kernel, desktop, CPU, GPU, memory, and storage fields.

## Domain Backends
- [[Astrea - App Manager Bridge]]
- [[Astrea - Explorer Backend]]
- [[Astrea - Weather Bridge]]
- [[Astrea - Audio Bridge]]
- [[Astrea - Display Bridge]]
- [[Astrea - Wallpaper Bridge]]

## Pattern
QML starts a process, receives stdout, parses JSON, and updates UI state.

See [[Astrea - Data Flow]] and [[Astrea - Patterns]].
