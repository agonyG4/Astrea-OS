# Astrea - Data Flow

Related notes: [[Astrea]], [[Astrea - Patterns]], [[Astrea - Core Bridge]]

## Shell Startup
1. Quickshell loads `Quickshell/shell.qml`.
2. `ComponentSettings` reads `~/.config/AstreaOS/ui/components.json`.
3. `ComponentServiceManager` reconciles status-service and helper cleanup for disabled surfaces.
4. `GameModeManager` tracks whether selected services should pause for game mode.
5. `shell.qml` creates shared `MusicMonitor`.
6. It loads [[Astrea - Desktop Icons]] only when the component is enabled.
7. It creates one [[Astrea - Top Bar]] per screen when topbar is enabled.
8. It creates one [[Astrea - Island]] per screen when island is enabled.
9. It creates resident [[Astrea - Spotlight]], [[Astrea - Alt Tab]], and [[Astrea - Notifications]] when enabled.

## Shell Status Flow
1. `astrea-status.service` runs `System/services/astrea_statusd.py`.
2. The service polls audio, network, and Bluetooth outside Quickshell.
3. It writes stable JSON under `~/.local/state/Astrea/status`.
4. Top bar modules read those JSON files with `FileView`.
5. Manual refresh actions send `SIGUSR1` to the service.
6. User side effects still use focused commands, such as `wpctl set-volume` or Bluetooth actions.

## Settings Flow
1. `Apps/Settings/main.qml` opens.
2. User selects a sidebar item.
3. A `Loader` loads a page.
4. Page starts a Quickshell `Process`.
5. Process calls [[Astrea - Core Bridge]] or [[Astrea - System Layer]].
6. Backend returns JSON or applies a side effect.
7. QML updates state.

## Shell Components Flow
1. Settings Components page reads or initializes `~/.config/AstreaOS/ui/components.json` through [[Astrea - State JSON Bridge]].
2. `Quickshell/runtime/ComponentSettings.qml` watches the file with `FileView`.
3. `shell.qml` gates Desktop Icons, Top Bar, Island, Spotlight, Alt Tab, and Notifications from those booleans.
4. `ComponentServiceManager.qml` stops `astrea-status.service` when the topbar is disabled or game mode is active, and kills desktop/music/notification helper processes when their owning surface is disabled.

## Network Settings Flow
1. `Apps/Settings/pages/connectivity/Internet.qml` calls [[Astrea - Network Bridge]].
2. The bridge returns interface stats, DNS state, Wi-Fi status/networks, and Cloudflare WARP status as JSON.
3. DNS changes write through `nmcli connection modify`.
4. Wi-Fi actions call `nmcli radio wifi`, `nmcli device wifi connect`, or device disconnect commands.
5. WARP actions use `warp-cli` plus systemd service/tray state when WARP is installed.

## Explorer Flow
1. `Apps/Explorer/Main.qml` starts.
2. `AppState.qml` initializes state modules.
3. Navigation calls [[Astrea - Explorer Backend]].
4. Backend returns JSON.
5. `JsonWorker.js` parses large payloads.
6. Views render list or icon models.
7. File actions route back through state modules and backend processes.

## FileChooser Portal Flow
1. An application calls the XDG Desktop Portal FileChooser API.
2. `xdg-desktop-portal` selects the `astrea` FileChooser backend.
3. `System/portal/astrea_filechooser_portal.py` receives the DBus request.
4. The backend launches `Apps/Explorer/PortalDialog.qml`.
5. `PortalDialog.qml` wraps Explorer's `FileDialog`.
6. The dialog writes result JSON or emits the `__ASTREA_FILE_DIALOG__` prefix.
7. The portal backend returns selected file URIs to the caller.

## Desktop Icons Flow
1. `Quickshell/shell.qml` reads component enablement from `~/.config/AstreaOS/ui/components.json`.
2. If the `desktop` component is enabled, a `Loader` opens `DesktopIcons.qml`.
3. `DesktopIcons.qml` creates one bottom-layer window per screen.
4. `app_index.py` returns XDG desktop-folder `.desktop` entries as JSON.
5. QML renders icons with `image://icon`.
6. Dragged icon positions persist under `~/.local/state/Astrea/desktop-icons/state.json`.
7. Right-click menus reuse [[Astrea - Features]] file menu components.

## Weather Flow
1. [[Astrea - Weather App]] creates `WeatherState`.
2. `WeatherState` loads the Weather notification setting from [[Astrea - Weather Bridge]].
3. `WeatherState` calls [[Astrea - Weather Bridge]] for forecast JSON.
4. Bridge reads cache or external APIs.
5. Bridge returns JSON, including INMET alerts when available.
6. Weather sections render structured data.
7. `astrea-weatherd` independently checks Weather data on a low-frequency loop.
8. `astrea-weatherd` deduplicates Weather alerts and sends them through `System/services/astrea_notify.py`.
9. Astrea's central `org.freedesktop.Notifications` service owns notification delivery and rendering.

## Media Viewer Flow
1. A launcher opens `Apps/MediaViewer/Main.qml` with `ASTREA_MEDIA_TARGET`.
2. QML calls `Apps/MediaViewer/media_viewer_helper.py open <target>`.
3. The helper scans the target directory for supported image files and returns JSON records.
4. QML requests previews with `media_viewer_helper.py preview <image>`.
5. Direct Qt-compatible image formats load from the original URI.
6. Other formats convert through ImageMagick or ffmpeg into `~/.cache/Astrea/media-viewer/previews`.

## Wallpapers Flow
1. `Apps/Wallpapers/main.qml` starts and calls `Core/bridge/wallpaper/wallpaper_manager.py list-user`.
2. The bridge returns user wallpaper records with wallpaper, thumbnail, blurred, slug, and base directory paths.
3. The app can call `apply`, `rename-user`, and `delete-user`.
4. Wallpaper/lockscreen side effects stay in [[Astrea - Wallpaper Bridge]].

## Launch Flow
1. Astrea launcher surfaces call `bin/astrea-launch`.
2. The CLI forwards requests to `astrea-launchd` over `/run/user/1000/Astrea/astrea-launchd.sock`.
3. `astrea-launchd` resolves desktop IDs, commands, files, URLs, Steam URIs, or argv JSON.
4. When configured, it asks `astrea-latencyd` for a temporary launch burst.
5. `astrea-latencyd` snapshots state, applies the burst through its narrow helper path, then rolls back.
6. Launch records are written under `~/.local/state/Astrea/launch/history.jsonl`.

## Gaming And Compatibility Flow
1. Settings Gamescope, Proton, and Compatibility pages call `System/scripts/astrea-gaming-settings`.
2. The helper writes `~/.config/AstreaOS/gaming/gamescope.json`, `proton.json`, and `compatibility.json`.
3. Gamescope saves regenerate `~/.local/bin/astrea-gamescope-session` and `~/.config/environment.d/gamescope-session-plus.conf`.
4. Proton saves regenerate the `astrea-gaming %command%` wrapper behavior consumed by launchers.
5. `System/scripts/astrea-windows-run <path>` opens `.exe` and `.msi` files with Proton, Wine, or auto mode, using the shared prefix under `~/.local/share/AstreaOS/windows-prefixes/shared/proton`.

## Music Flow
1. `MusicMonitor.qml` starts `playerctl` and `music_bars.sh`.
2. `music_bars.sh` starts `music_bars_backend`.
3. QML receives metadata, playback status, art, dominant color, and bars.
4. [[Astrea - Island]] and Control Center render the shared state.
5. User controls call `playerctl`.

## Notification Flow
1. App sends notification to DBus.
2. `notification_daemon.py` receives it.
3. Daemon writes `Quickshell/notifications/state.json`.
4. `Notifications.qml` reloads state via `FileView`.
5. UI renders cards.
6. Dismissal calls `gdbus`.

## Theme Flow
1. Theme config lives at `~/.config/AstreaOS/ui/theme.json`.
2. `Core/components/theme/Theme.qml` reads the config.
3. Theme scripts apply desktop/Hyprland side effects.
4. Apps and shell components bind to theme values.

## I18n Flow
1. Translatable strings live in `System/i18n/en_US.json` and `System/i18n/pt_BR.json`.
2. `System/i18n/i18n.py dump` merges the active language with the `en_US` fallback.
3. QML imports `AstreaI18n` through app-local symlinks or calls the Python helper.
4. Language selection reads `~/.config/AstreaOS/system/settings.json` or `system.json`.
