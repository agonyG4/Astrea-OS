# Astrea - Patterns

Related notes: [[Astrea]], [[Astrea - Data Flow]], [[Astrea - Core Bridge]]

## QML Composition
Astrea composes UI through QML components and modules.

Shell surfaces use:
- `ShellRoot`
- `Variants`
- `PanelWindow`

Apps use:
- `ApplicationWindow`
- `FloatingWindow`
- dynamic `Loader`

## Extend Existing Surfaces
Feature work should extend the existing surface instead of creating a parallel style.

See [[Astrea - Design Rules]] for visual rules.

When adding behavior:
- keep the current layout and visual tokens
- add actions inside existing menus, rows, cards, and state facades
- call the existing bridge/backend when possible
- introduce a shared component only when more than one surface needs it

This is especially important in app work. Add the function, not a redesign.

## Process Bridge
The dominant integration pattern is:
1. QML `Process`
2. Python/Bash/native command
3. JSON stdout or side effect
4. QML parser/state update

## Singleton State Facade
[[Astrea - Explorer App]] uses `AppState.qml` as a singleton facade.

It hides multiple state modules behind one app API.

## Shared Component Library
[[Astrea - Settings App]] imports [[Astrea - Core Components]] for consistent controls and theme.

Settings uses:
- `Apps/Settings/AstreaComponents -> Core/components`

Pages should import that link and reuse exported controls before creating local controls.

## Feature Modules
[[Astrea - Features]] holds reusable domain modules.

This separates reusable file/paper UI from full apps.

Explorer uses:
- `Apps/Explorer/AstreaFiles -> Features/Files`

File-manager surfaces should import `AstreaFiles` instead of copying file UI helpers.

Context menu behavior follows this pattern:
1. app wrapper owns the action logic and app state calls
2. `AstreaFiles.FileContextMenu` owns the frame and open/close behavior
3. reusable menu visuals stay in `Features/Files`
4. file operations route through `AppState` and the backend

New reusable feature components must be registered in the feature module's `qmldir`.

## Compatibility Entrypoints
[[Astrea - Core Bridge]] keeps top-level forwarding scripts that route to deeper domain scripts.

This preserves short paths while allowing internal organization.

## Config and State Convention
Observed convention:
- `~/.config/AstreaOS` for persistent user-facing config.
- `~/.config/AstreaOS/ui/components.json` for resident shell surface toggles.
- `~/.config/AstreaOS/gaming/*.json` for Gamescope, Proton, and Windows compatibility settings.
- `~/.local/state/Astrea` for runtime/application state.
- `~/.local/state/Astrea/weather/settings.json` for Weather notification preferences.
- `~/.local/state/Astrea/weather/alerts-seen.json` for Weather alert deduplication.
- `~/.cache/weather` for weather cache.
- `~/.local/share/AstreaOS` for durable user-owned library data such as wallpapers and Windows prefixes.

Some runtime state also exists inside the Astrea tree. See [[Astrea - Unknowns]].

## Absolute Runtime Paths
Many paths are hardcoded to `/home/agony/.local/share/Astrea`.

This makes the live runtime explicit but tightly binds the project to this local install path.
