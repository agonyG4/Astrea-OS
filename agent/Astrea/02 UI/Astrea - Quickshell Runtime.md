# Astrea - Quickshell Runtime

Related notes: [[Astrea]], [[Astrea - Entry Points]], [[Astrea - Desktop Icons]], [[Astrea - Top Bar]], [[Astrea - Island]], [[Astrea - Spotlight]], [[Astrea - Alt Tab]], [[Astrea - Notifications]]

## Folder
`Quickshell/`

## Responsibility
Owns the persistent desktop shell surfaces.

Quickshell should stay mostly visual.
Periodic system reads belong in services or backend bridges, not shell timers.

It composes:
- [[Astrea - Desktop Icons]]
- [[Astrea - Top Bar]]
- [[Astrea - Island]]
- [[Astrea - Spotlight]]
- [[Astrea - Alt Tab]]
- [[Astrea - Notifications]]

## Main Entry
`Quickshell/shell.qml`

The shell creates:
- one `Runtime.ComponentSettings`
- one `Runtime.ShellRuntime`
- one `Runtime.ComponentServiceManager`
- one `MusicMonitor`
- conditional `DesktopIcons`
- one `Bar` per screen when topbar is enabled
- one `Island` per screen when island is enabled
- resident `Spotlight`, `AltTab`, and `Notifications` when enabled

## Component Toggles
`Quickshell/runtime/ComponentSettings.qml` reads:
- `~/.config/AstreaOS/ui/components.json`

Defaults are enabled for:
- desktop
- topbar
- island
- spotlight
- alttab
- notifications

`Apps/Settings/pages/system/Components.qml` edits the same file through [[Astrea - State JSON Bridge]].

`Quickshell/runtime/ComponentServiceManager.qml` reconciles side effects:
- starts or stops `astrea-status.service` depending on topbar and game mode state
- kills desktop icon indexing helpers when desktop icons are disabled
- kills music monitoring helpers when both topbar and island are disabled
- kills `notification_daemon.py` when notifications are disabled

## Game Mode
`Quickshell/runtime/GameModeManager.qml` checks selected user services and exposes `gameModeActive`.

The shell passes this to Desktop Icons, Island, Spotlight, and ComponentServiceManager so expensive or distracting runtime work can pause while game mode is active.

## Shared State
`MusicMonitor` is created once in `shell.qml` and passed into:
- `Bar.sharedMusicState`
- `Island.sharedMusicState`

This means the bar control center and island consume the same music state.

## Dependencies
- Quickshell.
- Quickshell Wayland/layer shell modules.
- Hyprland.
- `playerctl`.
- `astrea-status.service` for cached audio, network, and Bluetooth status.
- [[Astrea - System Layer]].

## App Switching
`Quickshell/alttab/AltTab.qml` owns the resident Alt Tab app switcher.

It uses Hyprland clients as the source of truth, opens as an overlay, and dispatches both workspace switching and window focus for the selected app.

## Shared Components
`Quickshell/components/AppIcon.qml` owns app icon rendering for shell surfaces.

It follows the Spotlight icon path first: `image://icon/<icon name>`. When an entry does not provide an icon, it can infer common app icons from Hyprland class/title metadata and then falls back to initials.

Icon inference should avoid broad substring matches for short app names. For example, Obsidian uses the class `obsidian`, so OBS Studio must be matched by `obs`, `obsproject`, or `obs-studio`, not by any class containing `obs`.

## Status Cache
`System/services/astrea_statusd.py` owns low-frequency polling.

It writes stable JSON under:
- `~/.local/state/Astrea/status/audio.json`
- `~/.local/state/Astrea/status/network.json`
- `~/.local/state/Astrea/status/bluetooth.json`

Shell modules read these files with `FileView`.

Manual refreshes send `SIGUSR1` to `astrea-status.service`.
