# Astrea - Island

Related notes: [[Astrea - Quickshell Runtime]], [[Astrea - Top Bar]], [[Astrea - Audio Bridge]], [[Astrea - System Layer]]

## Folder
`Quickshell/island/`

## Responsibility
The Island is a compact/expanded shell surface focused on music presence and small status notifications.

It handles:
- compact music state
- expanded music controls
- album art
- dominant color
- live music bars
- game mode notification
- island visibility/config state

## Main Files
- `Island.qml`
- `IslandContent.qml`
- `IslandProcesses.qml`
- `MusicMonitor.qml`
- `MusicView.qml`

## Music Data
`MusicMonitor.qml` produces shared music state.

It reads:
- Spotify metadata through `playerctl --player=spotify`.
- music bars through `System/services/music_bars.sh`.
- dominant album color through `scripts/get-dominant-color.py`.

## Music Control
User actions call `playerctl` for:
- play/pause
- next
- previous
- seek
- shuffle
- loop

## State and Config
Observed paths:
- `~/.local/state/Astrea/island`
- `Quickshell/island/config/island.json`
- `Quickshell/island/config/dropped-images.json`

## Dependencies
- [[Astrea - Audio Bridge]]
- `Core/bridge/audio/music_bars_backend`
- `System/services/music_bars.sh`
- `playerctl`
- Quickshell layer shell.
