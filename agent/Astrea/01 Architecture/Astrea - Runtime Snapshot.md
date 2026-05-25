# Astrea - Runtime Snapshot

Related notes: [[Astrea]], [[Astrea - Project Overview]], [[Astrea - Entry Points]], [[Astrea - Data Flow]]

## Snapshot Source
Inspected runtime:
- `/home/agony/.local/share/Astrea-Rolling`

Canonical app-facing runtime:
- `/home/agony/.local/share/Astrea`

On this machine the canonical path currently resolves to the Rolling tree. Keep code and docs biased toward `ASTREA_ROOT` or `~/.local/share/Astrea`; only runtime sync/activation tooling should care about Stable versus Rolling.

## Top Level
- `Apps`: About, Explorer, MediaViewer, Settings, Wallpapers, Weather.
- `Assets`: display/settings icons, brand images, weather media, shell UI assets.
- `Core`: shared QML components and Python/Rust bridge backends.
- `Data`: Astrea-owned user data, including wallpapers.
- `Features`: reusable feature modules such as Files and Paper.
- `Quickshell`: resident shell surfaces.
- `System`: auth and Polkit helpers, i18n catalogs, service scripts, portal backend, config, launch backend, metadata.
- `bin`: installed runtime CLIs such as `astrea-launch`, `weather-cli`, and `astrea-weatherd`.

## Apps
- [[Astrea - About App]]: `Apps/About/main.qml`; standalone system overview opened from the Astrea top-bar popup.
- [[Astrea - Settings App]]: `Apps/Settings/main.qml`; sidebar routes to 12 visible sections and several internal pages.
- [[Astrea - Explorer App]]: `Apps/Explorer/Main.qml`; tabs, list/icon views, file actions, portal dialog, preview panel, and archive actions. Quick Look is disabled and treated as future work.
- [[Astrea - Weather App]]: `Apps/Weather/WeatherApp.qml`; thin wrapper around `ui/WeatherAppView.qml`.
- [[Astrea - Media Viewer App]]: `Apps/MediaViewer/Main.qml`; image viewer opened with `ASTREA_MEDIA_TARGET`.
- [[Astrea - Wallpapers App]]: `Apps/Wallpapers/main.qml`; standalone wallpaper library manager.

## Settings Pages
Live pages under `Apps/Settings/pages`:
- `apps/Apps.qml`
- `connectivity/Audio.qml`, `Bluetooth.qml`, `Internet.qml`
- `display/Desktop.qml`, `Display.qml`, `Island.qml`
- `paper/Lockscreen.qml`, `Paper.qml`, `Screensaver.qml`, `Wallpaper.qml`
- `personalization/Personalization.qml`, `User.qml`
- `system/Performance.qml`, `SoftwareUpdate.qml`, `Storage.qml`, `System.qml`

The sidebar currently exposes System, Software Update, Display, Apps, Performance, Internet, Bluetooth, Personalization, Paper, Audio, Island, and Storage. Desktop, Lockscreen, Screensaver, Wallpaper, and User are routed internally or reserved for subflows.

## Shell Surfaces
`Quickshell/shell.qml` creates shared process state and resident surfaces:
- Desktop Icons are loaded conditionally from `~/.local/state/Astrea/desktop-icons/config.json`.
- One [[Astrea - Top Bar]] per screen.
- One [[Astrea - Island]] per screen.
- Resident [[Astrea - Spotlight]], [[Astrea - Alt Tab]], and [[Astrea - Notifications]].
- Shared `MusicMonitor`, `NetworkProcess`, `BluetoothProcess`, and `AudioProcess` instances.

## Core And Features
- `Core/components`: shared QML controls, forms, menus, navigation, typography, theme, feedback, sidebar, and progress surfaces.
- `Core/bridge`: forwarding entrypoints plus app, audio, display, network, storage, system, session, state JSON, and wallpaper domain backends.
- `Features/Files`: shared file menu, operation progress, sidebar frame, and drag/drop behavior.
- `Features/Paper`: wallpaper and lockscreen feature files.
- `System/i18n`: translation catalogs and QML/Python helpers consumed through `AstreaI18n` symlinks.

## Native And Service Backends
- `Core/bridge/apps/explorer_backend`: Rust Explorer backend for list/search/devices/mount/remount/thumbnails/AppImage/file-op.
- `Core/bridge/audio/music_bars_backend`: Rust audio bars backend used by the island music view.
- `Apps/Weather/backend`: Rust workspace with `weather-core`, `weather-cli`, and `weatherd`.
- `System/launch`: Rust `astrea-launch` backend and tests.
- `Core/bridge/astrea_sessiond.py`: lightweight session daemon scaffold and status/state CLI.
- `Core/bridge/state_json.py`: atomic JSON read/write helper for QML.
- `System/services/astrea_statusd.py`: status cache daemon.
- `System/services/astrea_latencyd.py`: launch latency burst daemon.
- `System/auth/astrea-polkit-agent.py` and `astrea-polkit-agent.qml`: Polkit authentication agent paths.
- `System/portal/astrea_filechooser_portal.py`: XDG FileChooser portal backend.

## User Services
`System/services/astrea-services.sh` installs or verifies:
- `astrea-status.service`
- `astrea-latencyd.service`
- `astrea-launchd.service`
- `astrea-weatherd.service`
- `astrea-filechooser-portal.service`
- night-shift service/timer units
- DBus and portal registration files for the FileChooser portal

## Important State
- `~/.config/AstreaOS`: persistent user config.
- `~/.local/state/Astrea/status`: shell status cache.
- `~/.local/state/Astrea/weather`: Weather settings, current cache, and alert dedupe state.
- `~/.local/state/Astrea/desktop-icons`: desktop-icons config and grid state.
- `~/.local/state/Astrea/sessiond-status.json`: session daemon status heartbeat.
- `~/.cache/Astrea/media-viewer/previews`: converted Media Viewer previews.
- `~/.cache/weather`: compatibility weather cache.
- `~/.cache/storagesense/metadata_cache.db`: Storage page cache fallback.

## Validation Map
- QML: `qmllint <file.qml>` or `qs -p <entry.qml>`.
- Live shell: `quickshell list --all`.
- Python: `python3 -m py_compile <file.py>`.
- Rust: `cargo check --manifest-path <Cargo.toml>`.
- Services: `System/services/astrea-services.sh doctor all`.
- Launch path: `bin/astrea-launch doctor` and `bin/astrea-launch history`.
