# Astrea - Structure Breakdown

Related notes: [[Astrea]], [[Astrea - Project Overview]], [[Astrea - Entry Points]]

## Path Prefix
All folders below resolve under:
- `/home/agony/.local/share/Astrea`

## Top-Level Folders
- `Apps/`
  - standalone applications and app-specific workflows.
  - Put app-only UI state, pages, delegates, and process calls here.
  - See [[Astrea - Settings App]], [[Astrea - Explorer App]], [[Astrea - Weather App]].
- `Core/`
  - shared components and bridge scripts.
  - Put generic reusable controls and command wrappers here.
  - See [[Astrea - Core Components]] and [[Astrea - Core Bridge]].
- `Features/`
  - reusable domain modules.
  - Put domain-specific reusable UI here, such as file or paper features.
  - See [[Astrea - Features]].
- `Quickshell/`
  - persistent shell runtime.
  - Put shell surfaces here: bar, island, spotlight, notifications, and conditional desktop icons.
  - See [[Astrea - Quickshell Runtime]].
- `Assets/`
  - icons, images, and shell UI assets.
  - See [[Astrea - Assets and Data]].
- `Data/`
  - Astrea-owned user data.
  - See [[Astrea - Assets and Data]].
- `System/`
  - local system scripts, config, auth helper, cache, and metadata.
  - Put service wrappers, local config templates, auth helpers, and machine integration here.
  - See [[Astrea - System Layer]].

## Where To Add Things
| Need | Add it here |
| --- | --- |
| Settings page action or field | `Apps/Settings/pages/...` |
| Settings shared control | `Core/components` and `Core/components/qmldir` |
| Shared menu, button, card, or progress visual | `Core/components` and `Core/components/qmldir` |
| Explorer file action | `Apps/Explorer` state/component plus [[Astrea - Explorer Backend]] when needed |
| Reusable file-domain wrapper or drag/drop behavior | `Features/Files` and `Features/Files/qmldir` |
| Weather visual section | `Apps/Weather/ui/components` |
| Weather data display | `Apps/Weather/ui/state/WeatherState.qml` plus `Apps/Weather/backend/weather-cli` |
| Weather notifications | `Apps/Weather/backend/weatherd` |
| Shell bar/island/spotlight behavior | `Quickshell/...` |
| System read/write command | `Core/bridge` or `System` |
| Persistent user config | `~/.config/AstreaOS` |
| Runtime app state | `~/.local/state/Astrea` |

When adding app functionality, reuse the app's current shared modules and only add the behavior needed.

Do not change app style while adding backend or workflow behavior.

## Component Relationship
`Quickshell/` and `Apps/` are the visible UI layers.

`Core/components/` provides shared QML controls such as menus, buttons, cards, progress surfaces, navigation, and form controls.

`Core/bridge/` and `System/` provide system access.

`Features/` provides reusable domain UI and behavior that can be consumed by apps. It may wrap Core components, but generic visuals should stay in Core.

`Assets/` and `Data/` provide visual and user data inputs.

## Important Dependency Direction
- UI -> shared components.
- UI -> process bridge.
- process bridge -> system command/config.
- system command/config -> JSON or side effect.
- JSON -> UI model/property update.

See [[Astrea - Data Flow]].
