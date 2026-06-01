# Astrea - Desktop Icons

Related notes: [[Astrea - Quickshell Runtime]], [[Astrea - Features]], [[Astrea - Assets and Data]], [[Astrea - Launcher and Latency]]

## Folder
`Quickshell/desktop/`

## Responsibility
Desktop Icons is the bottom-layer desktop application overlay.

It renders launchable `.desktop` applications on the desktop, supports drag placement, and provides a right-click menu.

## Main Files
- `DesktopIcons.qml`
- `app_index.py`
- `qmldir`

## Runtime Integration
`Quickshell/shell.qml` loads `DesktopIcons.qml` through a `Loader`.

It must not instantiate Desktop Icons directly. The loader is gated by:
- `~/.config/AstreaOS/ui/components.json`

When the `desktop` component is `false`, the main shell does not load the desktop icon overlay.

The overlay creates one bottom-layer `PanelWindow` per screen.

Layer namespace:
- `astrea-desktop-icons`

## Shared Components
Desktop Icons uses shared file UI from:
- `Features/Files`

It imports:
- `AstreaFiles.FileContextMenu`
- `AstreaFiles.ContextMenuAction`
- `AstreaFiles.ContextMenuDivider`

Local module link:
- `Quickshell/desktop/AstreaFiles -> Features/Files`

Do not reintroduce a local desktop-only context menu frame.

## State
Runtime component enablement:
- `~/.config/AstreaOS/ui/components.json`

Desktop icons behavior/config:
- `~/.local/state/Astrea/desktop-icons/config.json`

Persistent layout state:
- `~/.local/state/Astrea/desktop-icons/state.json`

Compatibility fallback:
- `Quickshell/desktop/state.json`

## Drag Placement
Manual positions are stored as grid slot indexes keyed by `.desktop` path.

The drag system is intentionally simple and slot-based:

- The dragged item follows the pointer after a small movement threshold.
- On release, `DesktopIcons.qml` maps the center of the dragged `Image` into desktop coordinates.
- Occupied icon hitboxes are square and centered on the target icon bitmap. The hitbox size is `iconSize`; label and selection highlight area do not count.
- If the dragged icon center lands inside another icon hitbox, the dragged icon takes that target slot and the target icon returns to the dragged icon's source slot.
- If the dragged icon center does not hit another icon, the fallback target is the grid cell containing that point.
- The fallback grid-cell lookup uses `floor`, not `round`, so a point inside the visible cell rectangle resolves to that same slot instead of jumping to the neighboring column or row.

Do not reintroduce a persistent drop-preview rectangle for normal use. Temporary debug overlays can be used while tuning slot math, but they should be removed after validation.

## App Index
`app_index.py` scans the XDG desktop folder only.

On this machine that is:
- `~/Área de trabalho`

It returns JSON for QML and writes local `apps.js` / `apps.json` only as generated cache files.

## Launching
Desktop Icons launches entries through `bin/astrea-launch`, so desktop launches share the same launcher daemon, history, and latency behavior as Spotlight and Explorer.

## Background Work
Desktop Icons must not keep a long-lived shell watcher process.

It refreshes the XDG desktop-folder signature from a QML timer and only starts a short Python process for each check.

This avoids orphaned watcher processes when the shell reloads.

## Validation
- `qmllint /home/agony/.local/share/Astrea/Quickshell/desktop/DesktopIcons.qml`
- `python3 /home/agony/.local/share/Astrea/Quickshell/desktop/app_index.py --json --max-apps 3`
- `hyprctl layers` should show `astrea-desktop-icons` after shell reload.
