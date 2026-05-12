# Astrea - Alt Tab

Related notes: [[Astrea - Quickshell Runtime]], [[Astrea - Entry Points]]

## File
`Quickshell/alttab/AltTab.qml`

## Responsibility
Alt Tab is the resident app switcher for the Astrea desktop shell.

It handles:
- `Alt+Tab` to move forward through open apps.
- `Alt+Shift+Tab` to move backward.
- releasing Alt to commit the selected app.
- a macOS-like centered app strip with large icon-only items.
- switching to the selected app's workspace before focusing its window.

## Data Source
The switcher reads the live Quickshell Hyprland model:
- `Hyprland.toplevels`
- `Hyprland.activeToplevel`

The QML filters hidden and special-workspace windows. Standalone Astrea apps are kept even when their compositor class is `org.quickshell`; their window title identifies the app.

## Icons
Alt Tab uses the shared `Quickshell/components/AppIcon.qml` component.

The component uses the same primary path as Spotlight: `image://icon/<icon name>`. For Hyprland clients that do not expose a desktop-entry icon, it infers common icons from class/title metadata and then falls back to initials.

The switcher UI intentionally shows only the app icon. It does not show app names, workspace names, or a separate workspace indicator. The selected client is communicated through the icon tile background, border, and slight scale change.

## Focus Flow
1. Hyprland receives `Alt+Tab`.
2. The global shortcut `quickshell:alt_tab_next` reaches the resident shell.
3. `AltTab.qml` reads the in-memory Hyprland toplevel list.
4. The app strip opens and selects the next recent client by `focusHistoryID`.
5. Repeated `Alt+Tab` cycles the selection.
6. Releasing Alt, clicking, or pressing Enter commits the selection.
7. Alt Tab dispatches:
   - `workspace <workspace id>`
   - `focuswindow address:<client address>`

Addresses from `Hyprland.toplevels` are normalized with a `0x` prefix before the focus dispatch because Hyprland's dispatcher expects that format.

## Fast Release Behavior
Alt Tab does not spawn `hyprctl` while switching.

The client list comes from Quickshell's already-live Hyprland model, so a quick `Alt+Tab` can open, select the previous app, and commit on Alt release without waiting for process I/O.

There is no automatic timer commit. Keyboard switching commits when the focused overlay receives an Alt key release. The Hyprland release binding still points at `quickshell:alt_tab_commit` as a secondary path, but the QML key-release handler is the primary commit path because compositor-level release globals can be unreliable for modifier-only keys.

## Hyprland Wiring
The bindings live in:
- `~/.config/hypr/bindings/keybindings.conf`

The shortcut names live in:
- `~/.config/hypr/system/programs.conf`

The layer blur rules live in:
- `~/.config/hypr/system/rules/windowrules.conf`

Modifier-only release binds must include the target modifier in the modmask.

Use:
- `bindr = ALT, Alt_L, global, $altTabCommit`
- `bindr = ALT, Alt_R, global, $altTabCommit`

The empty-modifier form registers but does not reliably fire for releasing Alt.
