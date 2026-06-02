# MOC - UI

Parent: [[Astrea]]

## Purpose
UI notes describe the Quickshell runtime and persistent shell surfaces.

## Runtime
- [[Astrea - Quickshell Runtime]]

## Surfaces
- [[Astrea - Desktop Icons]]
- [[Astrea - Top Bar]]
- [[Astrea - Island]]
- [[Astrea - Spotlight]]
- [[Astrea - Alt Tab]]
- [[Astrea - Notifications]]

## Related Backends
- [[Astrea - Audio Bridge]]
- [[Astrea - Bluetooth Manager]]
- [[Astrea - Weather Bridge]]
- [[Astrea - System Layer]]

## Common Flow
1. `Quickshell/shell.qml` starts the shell.
2. `Runtime.ComponentSettings` reads component toggles from `~/.config/AstreaOS/ui/components.json`.
3. The shell loads Desktop Icons, Top Bar, Island, Spotlight, Alt Tab, and Notifications only when their component is enabled.
4. The shell creates shared music state.
5. Bar and Island consume shared state.
6. UI surfaces call process bridges for system data.
