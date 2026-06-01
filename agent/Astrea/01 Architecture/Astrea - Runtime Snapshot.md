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
- `Backend`: canonical symlink namespace for bridges, services, portal, and auth helpers.
- `Core`: shared QML components and Python/Rust bridge backends.
- `Features`: reusable feature modules such as Files and Paper.
- `Quickshell`: resident shell surfaces.
- `Runtime`: canonical symlink namespace for bin, scripts, config, and i18n.
- `System`: auth and Polkit helpers, i18n catalogs, service scripts, portal backend, config, launch backend, metadata.
- `UI`: canonical symlink namespace for shell, components, and UI assets.
- `Docs`: local runtime structure notes.
- `Tools`: structure and maintenance helpers.
- `bin`: installed runtime CLIs such as `astrea-launch`, `weather-cli`, and `astrea-weatherd`.

## Apps
- [[Astrea - About App]]: `Apps/About/main.qml`; standalone system overview opened from the Astrea top-bar popup.
- [[Astrea - Settings App]]: `Apps/Settings/main.qml`; sidebar routes to core pages, grouped section overviews, and internal subpages.
- [[Astrea - Explorer App]]: `Apps/Explorer/Main.qml`; tabs, list/icon views, file actions, portal dialog, preview panel, and archive actions. Quick Look is disabled and treated as future work.
- [[Astrea - Weather App]]: `Apps/Weather/WeatherApp.qml`; thin wrapper around `ui/WeatherAppView.qml`.
- [[Astrea - Media Viewer App]]: `Apps/MediaViewer/Main.qml`; image viewer opened with `ASTREA_MEDIA_TARGET`.
- [[Astrea - Wallpapers App]]: `Apps/Wallpapers/main.qml`; standalone wallpaper library manager.

## Settings Pages
Live pages under `Apps/Settings/pages`:
- `apps/Apps.qml`
- `connectivity/Audio.qml`, `Bluetooth.qml`, `Internet.qml`
- `display/Desktop.qml`, `Display.qml`, `Island.qml`
- `gaming/Compatibility.qml`, `Gamescope.qml`, `Proton.qml`
- `paper/Lockscreen.qml`, `Paper.qml`, `Screensaver.qml`, `Wallpaper.qml`
- `personalization/Personalization.qml`, `User.qml`
- `system/Components.qml`, `Language.qml`, `Performance.qml`, `SoftwareUpdate.qml`, `Storage.qml`, `System.qml`
- `SectionOverview.qml`

The sidebar currently exposes System, Software Update, Internet, Bluetooth, Audio, Components, and grouped overviews for Desempenho, Aparencia, and Mais Ajustes. Group overviews route to Gamescope, Proton, Performance, Display, Personalization, Paper, Island, Language, Apps, Compatibilidade, Storage, and Components. Desktop, Lockscreen, Screensaver, Wallpaper, and User remain internal or subflow pages.

## Shell Surfaces
`Quickshell/shell.qml` creates shared process state and resident surfaces:
- `ComponentSettings` reads `~/.config/AstreaOS/ui/components.json` and gates shell surfaces.
- `ComponentServiceManager` starts/stops `astrea-status.service` and cleans helper processes when components are disabled.
- `GameModeManager` pauses selected services while game mode is active.
- Desktop Icons are loaded conditionally from the component config and desktop-icons state.
- One [[Astrea - Top Bar]] per screen.
- One [[Astrea - Island]] per screen.
- Resident [[Astrea - Spotlight]], [[Astrea - Alt Tab]], and [[Astrea - Notifications]].
- Shared `MusicMonitor`, `NetworkProcess`, `BluetoothProcess`, and `AudioProcess` instances.

## Core And Features
- `Core/components`: shared QML controls, forms, menus, navigation, typography, theme, feedback, sidebar, and progress surfaces.
- `Core/bridge`: forwarding entrypoints plus app, audio, display, network, storage, system, session, state JSON, doctor, and wallpaper domain backends.
- `Features/Files`: shared file menu, operation progress, sidebar frame, and drag/drop behavior.
- `Features/Paper`: wallpaper and lockscreen feature files.
- `System/i18n`: translation catalogs and QML/Python helpers consumed through `AstreaI18n` symlinks.

## Native And Service Backends
- `Core/bridge/apps/explorer_backend`: Rust Explorer backend for list/search/devices/mount/remount/thumbnails/AppImage/file-op.
- `Core/bridge/audio/music_bars_backend`: Rust audio bars backend used by the island music view.
- `Apps/Weather/backend`: Rust workspace with `weather-core`, `weather-cli`, and `weatherd`.
- `System/launch`: Rust `astrea-launch` backend and tests.
- `System/scripts/astrea-gaming-settings`: Gamescope, Proton, and Windows compatibility settings writer.
- `System/scripts/astrea-windows-run`: Windows `.exe`/`.msi` runner through Proton, Wine, or auto mode.
- `Core/bridge/astrea_sessiond.py`: lightweight session daemon scaffold and status/state CLI.
- `Core/bridge/state_json.py`: atomic JSON read/write helper for QML.
- `Core/bridge/network/manager.py`: Internet Settings bridge for stats, DNS, Wi-Fi, and WARP.
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
- `~/.config/AstreaOS/ui/components.json`: shell component toggles.
- `~/.config/AstreaOS/gaming/gamescope.json`, `proton.json`, and `compatibility.json`: gaming and Windows-app compatibility config.
- `~/.local/state/Astrea/status`: shell status cache.
- `~/.local/state/Astrea/weather`: Weather settings, current cache, and alert dedupe state.
- `~/.local/state/Astrea/desktop-icons`: desktop-icons config and grid state.
- `~/.local/state/Astrea/sessiond-status.json`: session daemon status heartbeat.
- `~/.local/share/AstreaOS/user/wallpapers`: durable user wallpaper library.
- `~/.local/share/AstreaOS/windows-prefixes/shared/proton`: shared Windows-app prefix data.
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
