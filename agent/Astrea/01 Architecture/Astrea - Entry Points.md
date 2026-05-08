# Astrea - Entry Points

Related notes: [[Astrea]], [[Astrea - Quickshell Runtime]], [[Astrea - Settings App]], [[Astrea - Explorer App]], [[Astrea - Weather App]]

## Path Prefix
All relative paths in this note resolve under:
- `/home/agony/.local/share/Astrea`

Use this live path for code changes unless the user explicitly requests documentation-only work.

## Agent Domain Map
| User mentions | Start here |
| --- | --- |
| desktop icons, desktop apps | [[Astrea - Desktop Icons]] |
| topbar, bar, tray | [[Astrea - Top Bar]] |
| island, music compact, notch | [[Astrea - Island]] |
| spotlight, launcher | [[Astrea - Spotlight]] |
| alt tab, app switcher, app switching | [[Astrea - Alt Tab]] |
| notifications, toast, DBus notify | [[Astrea - Notifications]] |
| settings pages | [[Astrea - Settings App]] |
| files, explorer, finder | [[Astrea - Explorer App]], [[Astrea - Explorer Backend]] |
| portal, file chooser, system file dialog | [[Astrea - FileChooser Portal]], [[Astrea - Explorer App]] |
| weather, INMET, forecast | [[Astrea - Weather App]], [[Astrea - Weather Bridge]] |
| audio, music bars, PipeWire | [[Astrea - Audio Bridge]] |
| monitor, display, Hyprland display config | [[Astrea - Display Bridge]] |
| wallpaper, lockscreen media | [[Astrea - Wallpaper Bridge]] |
| bluetooth | [[Astrea - Bluetooth Manager]] |

## Main Shell
- File: `Quickshell/shell.qml`
- Role: main Quickshell runtime entry point.
- Creates:
  - [[Astrea - Desktop Icons]]
  - [[Astrea - Top Bar]]
  - [[Astrea - Island]]
  - [[Astrea - Spotlight]]
  - [[Astrea - Alt Tab]]
  - [[Astrea - Notifications]]
  - shared music state through `MusicMonitor`.

## Standalone Apps
- `Apps/About/main.qml`
  - About app entry point.
- `Apps/Settings/main.qml`
  - [[Astrea - Settings App]] entry point.
- `Apps/Explorer/Main.qml`
  - [[Astrea - Explorer App]] entry point.
- `Apps/Weather/WeatherApp.qml`
  - [[Astrea - Weather App]] entry point.

## Bridge Entrypoints
- `Core/bridge/apps.py`
  - forwards to `Core/bridge/apps/manager.py`.
- `Core/bridge/audio.py`
  - forwards to `Core/bridge/system/audio.py`.
- `Core/bridge/display.py`
  - forwards to `Core/bridge/system/display.py`.
- `Core/bridge/network.py`
  - forwards to `Core/bridge/network/manager.py`.
- `Core/bridge/storage.py`
  - forwards to `Core/bridge/system/storage.py`.
- `Core/bridge/system.py`
  - forwards to `Core/bridge/system/info.py`.

## Native Executables
- `Core/bridge/apps/explorer_backend`
  - used by [[Astrea - Explorer App]].
- `Core/bridge/audio/music_bars_backend`
  - used by [[Astrea - Island]] through `System/services/music_bars.sh`.
- `System/auth/auth_helper`
  - setuid helper used by lockscreen/auth-related paths.

## Unknown
The exact external autostart owner for `Quickshell/shell.qml` was not established in this pass. See [[Astrea - Unknowns]].
