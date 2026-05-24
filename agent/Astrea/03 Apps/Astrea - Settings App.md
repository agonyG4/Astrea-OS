# Astrea - Settings App

Related notes: [[Astrea]], [[Astrea - Core Components]], [[Astrea - Core Bridge]], [[Astrea - System Layer]]

## Folder
`Apps/Settings/`

## Main Entry
`Apps/Settings/main.qml`

Top-bar launch entry:
- `~/.local/bin/astrea-settings-open`

The top bar should use the wrapper rather than calling `quickshell -p` directly. The wrapper opens Settings on the currently active Hyprland workspace and uses `ASTREA_SETTINGS_DIRECT=1` only for its own recursion guard.

## Responsibility
Settings is the user-facing control center for system and Astrea configuration.

Observed sections:
- System
- Software Update
- Display
- Apps
- Performance
- Internet
- Bluetooth
- Personalization
- Paper
- Audio
- Island
- Storage

## Navigation Model
`main.qml` defines:
- a sidebar nav model
- `selectedIndex`
- page paths
- a `Loader` for pages
- profile navigation to `pages/personalization/User.qml`

## Dependencies
- [[Astrea - Core Components]]
- [[Astrea - Core Bridge]]
- [[Astrea - App Manager Bridge]]
- [[Astrea - Display Bridge]]
- [[Astrea - Audio Bridge]]
- [[Astrea - Bluetooth Manager]]
- [[Astrea - Wallpaper Bridge]]
- [[Astrea - I18n]]
- [[Astrea - System Layer]]
- Settings icons under `Assets/icons/settings`.

## Shared Component Import
Settings uses a local module link:
- `Apps/Settings/AstreaComponents -> Core/components`
- `Apps/Settings/AstreaI18n -> System/i18n`

Pages import this link with relative paths, for example:
- `import "AstreaComponents"` from `main.qml`
- `import "../../AstreaComponents"` from page files

This keeps the app loading through Quickshell while still using the shared component library.

## Config Targets
Observed config/state paths:
- `~/.config/AstreaOS`
- `~/.local/state/Astrea`
- `~/.local/state/Astrea/desktop-icons/config.json`
- `~/.local/state/Astrea/desktop-icons/state.json`
- `~/.config/AstreaOS/system/settings.json`
- `~/.config/AstreaOS/ui/theme.json`
- WirePlumber config under `~/.config/wireplumber`

## Desktop Icons Page
`pages/display/Desktop.qml` controls the resident desktop-icons overlay loaded by the main Quickshell shell. It is currently not exposed as a sidebar item; the page remains available for future routing or internal reuse.

It writes:
- `desktop-icons/config.json` for whether the overlay is loaded.
- `desktop-icons/state.json` for icon visibility, sort mode, icon size, and manual grid positions.

The page exposes the same durable options as the desktop context menu:
- enable or disable Desktop Icons
- show or hide icons
- choose small, medium, or large icon size
- sort by name, type, or path
- clear manual positions and reorganize the grid
- rebuild the shortcut index through `Quickshell/desktop/app_index.py --json --write`

Changes that affect the resident overlay restart the main Quickshell shell through the existing Settings restart helper so the runtime state matches the saved JSON.

## Apps Page
`pages/apps/Apps.qml` reads installed desktop applications through:
- `Core/bridge/apps/manager.py`

The page shows the real `Name=` value from each `.desktop` file. Astrea app launchers in `~/.local/share/applications` should therefore be renamed in the desktop entries themselves when the visible app name changes.

Clicking an app expands its row inline. The expanded card exposes:
- create desktop shortcut
- open the desktop file location
- uninstall

`Settings` is protected from uninstall through `astrea-settings.desktop`.

## Page Pattern
Most pages follow this pattern:
1. UI loads.
2. Page starts a Quickshell `Process`.
3. Process calls a bridge script.
4. Bridge returns JSON or applies a side effect.
5. QML parses stdout and updates state.

See [[Astrea - Data Flow]].

## Bluetooth Page
`pages/connectivity/Bluetooth.qml` should not show the `OUTROS DISPOSITIVOS` section while scanning if no devices have been found.

The discovered-device section becomes visible only when `scannedDevices.length > 0`. This keeps the page from showing an empty bottom card or scanning bar when there is no Bluetooth device candidate to display.

The main Bluetooth switch calls `System/scripts/bluetooth_manager.py power on|off` explicitly and keeps a short pending state while BlueZ applies the change. The helper verifies the final adapter state before reporting success, and the page refreshes status after the power transition so the switch does not get stuck on stale state.

## Storage Page
`pages/system/Storage.qml` reads StorageSense through:
- `Core/bridge/system/storage.py json`

The cache-backed approach is intentional. Opening Settings should read the existing StorageSense SQLite cache quickly instead of walking the whole filesystem every time. Full scans are expensive and should only happen when the cache is missing, stale, or explicitly refreshed.

The bridge must not depend on a single loose Bench checkout path. It resolves the StorageSense scanner from stable candidates and, for `json`, can still render from `~/.cache/storagesense/metadata_cache.db` when the scanner code is temporarily unavailable. This keeps the Storage page visible instead of turning a moved backend into an empty page.

`storage.py json` owns the automatic refresh contract. It should return stable fields such as `refresh_running`, `refresh_started`, `cache_stale`, `error`, and `data`. When a scanner backend is available and the cache is missing or stale, the bridge starts a background refresh and the QML page polls `json` until it finishes. If no backend exists, `json` falls back cleanly to cache/error metadata instead of pretending a scan is running.

The UI should show the scanning/updating state from those fields and must not keep the overview stuck on `Calculando` when there is no cache.

The overview line also shows compressed storage beside the used-storage text. Prefer exact `compsize`/zstd fields when present; fall back to the StorageSense allocated-size estimate only when exact compression data is unavailable.

Storage values are formatted with decimal units (`1 GB = 1,000,000,000 bytes`) so they match disk/vendor-style numbers instead of showing binary GiB values with a `GB` label.
