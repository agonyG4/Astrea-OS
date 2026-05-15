# Astrea - Bluetooth Manager

Related notes: [[Astrea - Settings App]], [[Astrea - Top Bar]], [[Astrea - System Layer]]

## File
`System/scripts/bluetooth_manager.py`

## Responsibility
Bluetooth helper for status, power, connection, disconnection, and autoconnect behavior.

## Consumers
- `Apps/Settings/pages/connectivity/Bluetooth.qml`
- `Quickshell/bar/modules/*/BluetoothProcess.qml`
- `Quickshell/bar/ui/components/bluetooth/BluetoothPopup.qml`
- `Quickshell/bar/ui/components/controlcenter/ControlCenterPopup.qml`

## State
Stored under:
- `~/.local/state/Astrea/bluetooth/autoconnect.json`
- `~/.local/state/Astrea/bluetooth/runtime.json`
- `~/.local/state/Astrea/bluetooth/status-cache.json`

## Dependencies
- `bluetoothctl`

## Pattern
QML calls the script with a command.

The script emits JSON and normally keeps user-facing errors inside the JSON payload.

Power commands report the verified adapter state:
- `power on`
- `power off`

The top bar uses `Quickshell/bar/modules/network/BluetoothProcess.qml` as the active Bluetooth state owner. It reads the status cache when available, but also calls `bluetooth_manager.py status` directly on refresh so a stopped `astrea-status.service` does not leave the tray stuck on stale Bluetooth state.
