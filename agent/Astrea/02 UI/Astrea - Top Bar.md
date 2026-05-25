# Astrea - Top Bar

Related notes: [[Astrea - Quickshell Runtime]], [[Astrea - Island]], [[Astrea - Bluetooth Manager]], [[Astrea - Audio Bridge]]

## Folder
`Quickshell/bar/`

## Responsibility
The top bar displays system status and opens quick controls.

Observed areas:
- Astrea menu.
- Workspaces.
- Tray.
- Clock.
- Network indicator and popup.
- Bluetooth indicator and popup.
- Volume indicator and popup.
- Control Center.

## Main File
`Quickshell/bar/Bar.qml`

## Data Sources
- Volume:
  - `~/.local/state/Astrea/status/audio.json`
  - manual set still calls `wpctl set-volume @DEFAULT_AUDIO_SINK@`
- Network:
  - `Quickshell/bar/modules/network/NetworkProcess.qml`
  - reads `~/.local/state/Astrea/status/network.json`
- Bluetooth:
  - `Quickshell/bar/modules/network/BluetoothProcess.qml`
  - [[Astrea - Bluetooth Manager]]
  - reads `~/.local/state/Astrea/status/bluetooth.json`
  - falls back to `bluetooth_manager.py status` directly when the status cache or `astrea-status.service` is stale.
- Music:
  - shared state from [[Astrea - Island]] / `MusicMonitor`.

## Interactions
The bar updates QML properties from backend JSON caches and explicit action results.

Do not add repeating shell timers for status polling.
If a status needs periodic refresh, add it to `astrea-status.service` or a focused backend.

The Control Center consumes:
- network state
- Bluetooth state
- volume state
- shared music state

## Astrea Menu Launches
`Quickshell/bar/ui/components/astrea/AstreaPopup.qml` opens Settings through:
- `~/.local/bin/astrea-settings-open`

That wrapper is the official Settings launch path from the top bar. When Hyprland is available, it resolves the active workspace with `hyprctl activeworkspace -j` and re-execs Settings through:
- `hyprctl dispatch exec [workspace <id>] ...`

`ASTREA_SETTINGS_DIRECT=1` is an internal escape hatch used by the wrapper to avoid recursion after Hyprland has placed the process on the current workspace.

## Bluetooth Notes
`Bar.qml` imports `modules/network`, so the active top-bar Bluetooth state owner is `Quickshell/bar/modules/network/BluetoothProcess.qml`.

Bluetooth power changes should go through `BluetoothProcess.setPower()` so the tray popup and Control Center share the same pending state, verified helper result, cache refresh, and scan resume behavior.
