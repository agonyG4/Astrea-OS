# Astrea - Data Flow

Related notes: [[Astrea]], [[Astrea - Patterns]], [[Astrea - Core Bridge]]

## Shell Startup
1. Quickshell loads `Quickshell/shell.qml`.
2. `shell.qml` creates shared `MusicMonitor`.
3. It loads [[Astrea - Desktop Icons]] only when desktop icons are enabled.
4. It creates one [[Astrea - Top Bar]] per screen.
5. It creates one [[Astrea - Island]] per screen.
6. It creates resident [[Astrea - Spotlight]].
7. It creates resident [[Astrea - Alt Tab]].
8. It creates resident [[Astrea - Notifications]].

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
1. `Quickshell/shell.qml` reads `~/.local/state/Astrea/desktop-icons/config.json`.
2. If enabled, a `Loader` opens `DesktopIcons.qml`.
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

## Launch Flow
1. Astrea launcher surfaces call `bin/astrea-launch`.
2. The CLI forwards requests to `astrea-launchd` over `/run/user/1000/Astrea/astrea-launchd.sock`.
3. `astrea-launchd` resolves desktop IDs, commands, files, URLs, Steam URIs, or argv JSON.
4. When configured, it asks `astrea-latencyd` for a temporary launch burst.
5. `astrea-latencyd` snapshots state, applies the burst through its narrow helper path, then rolls back.
6. Launch records are written under `~/.local/state/Astrea/launch/history.jsonl`.

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
