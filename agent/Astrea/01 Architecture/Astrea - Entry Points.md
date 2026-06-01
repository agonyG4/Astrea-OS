# Astrea - Entry Points

Related notes: [[Astrea]], [[Astrea - Quickshell Runtime]], [[Astrea - Settings App]], [[Astrea - Explorer App]], [[Astrea - Weather App]], [[Astrea - Media Viewer App]], [[Astrea - Wallpapers App]]

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
| about, system info, About this PC | [[Astrea - About App]], [[Astrea - Core Bridge]] |
| files, explorer, finder | [[Astrea - Explorer App]], [[Astrea - Explorer Backend]] |
| image viewer, media viewer, preview | [[Astrea - Media Viewer App]] |
| portal, file chooser, system file dialog | [[Astrea - FileChooser Portal]], [[Astrea - Explorer App]] |
| weather, INMET, forecast | [[Astrea - Weather App]], [[Astrea - Weather Bridge]] |
| audio, music bars, PipeWire | [[Astrea - Audio Bridge]] |
| monitor, display, Hyprland display config | [[Astrea - Display Bridge]] |
| internet, Wi-Fi, DNS, Cloudflare WARP, network status | [[Astrea - Network Bridge]], [[Astrea - Settings App]] |
| wallpaper, lockscreen media | [[Astrea - Wallpaper Bridge]] |
| wallpapers app, wallpaper library | [[Astrea - Wallpapers App]], [[Astrea - Wallpaper Bridge]] |
| bluetooth | [[Astrea - Bluetooth Manager]] |
| language, translation, i18n, locale | [[Astrea - I18n]] |
| polkit, authentication prompt, privilege prompt | [[Astrea - Polkit Auth]] |
| app launch, launcher daemon, latency burst | [[Astrea - Launcher and Latency]] |
| gamescope, SteamOS session, Proton, Wine, Windows `.exe` or `.msi` | [[Astrea - Gaming and Compatibility]] |

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
- `Apps/MediaViewer/Main.qml`
  - [[Astrea - Media Viewer App]] entry point.
- `Apps/Wallpapers/main.qml`
  - [[Astrea - Wallpapers App]] entry point.

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
- `Core/bridge/astrea_sessiond.py`
  - [[Astrea - Session Daemon]] status/state/run CLI.
- `Core/bridge/state_json.py`
  - [[Astrea - State JSON Bridge]] atomic JSON helper.

## Native Executables
- `Core/bridge/apps/explorer_backend`
  - used by [[Astrea - Explorer App]].
- `Core/bridge/audio/music_bars_backend`
  - used by [[Astrea - Island]] through `System/services/music_bars.sh`.
- `System/auth/auth_helper`
  - setuid helper used by lockscreen/auth-related paths.
- `System/auth/astrea-polkit-agent.py`
  - Python Polkit authentication agent.
- `System/auth/astrea-polkit-agent.qml`
  - Quickshell Polkit prompt implementation.
- `System/launch/target/release/astrea-launch`
  - built source for `bin/astrea-launch`.
- `bin/astrea-launch`
  - app-facing launch wrapper used by Spotlight, Desktop Icons, Explorer, and app manager calls.
- `bin/astrea-gaming`
  - Proton/GameMode/MangoHud wrapper generated from `~/.config/AstreaOS/gaming/proton.json`.
- `bin/astrea-gamescope-session`
  - Gamescope/Steam session launcher generated from `~/.config/AstreaOS/gaming/gamescope.json`.
- `System/scripts/astrea-windows-run`
  - Windows `.exe`/`.msi` runner using Proton, Wine, or auto mode.
- `bin/weather-cli`
  - Weather CLI consumed by Weather QML and Spotlight.
- `bin/astrea-weatherd`
  - Weather monitor daemon binary installed by `astrea-services.sh`.

## Session Autostart
Hyprland starts the live shell from:
- `~/.config/hypr/system/autostart.conf`

Current relevant entries include:
- `quickshell -p ~/.local/share/Astrea/Quickshell`
- `quickshell -p ~/.local/share/Astrea/Features/Paper/lockscreen/Lockscreen.qml`
- `bash $HOME/.local/share/Astrea/System/services/display_apply.sh`
