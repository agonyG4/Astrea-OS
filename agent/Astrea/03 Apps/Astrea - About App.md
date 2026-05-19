# Astrea - About App

Related notes: [[Astrea]], [[Astrea - Core Bridge]], [[Astrea - Top Bar]]

## Folder
`Apps/About/`

## Main Entry
`Apps/About/main.qml`

## Responsibility
About is a standalone system overview window for Astrea.

It is launched from the Astrea top-bar popup item labeled `About this PC`.

## Data Source
The app reads system information through [[Astrea - Core Bridge]]:
- `Core/bridge/system.py`
- forwarded implementation: `Core/bridge/system/info.py`

The bridge gathers OS, kernel, desktop, CPU, GPU, memory, and storage fields in one process instead of making the QML app spawn many shell commands.

## Launch Path
The top-bar popup starts it with:
- `quickshell -p "$ASTREA_ROOT/Apps/About/main.qml"`

Keep the About app lightweight. It should display system information and identity; broader settings actions belong in [[Astrea - Settings App]].
