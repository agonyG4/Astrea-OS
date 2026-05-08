# Astrea - AI Project Brain

Related notes: [[Astrea]], [[Astrea - Agent Working Rules]], [[Astrea - Design Rules]], [[Astrea - Entry Points]]

## Prime Directive
Astrea is the user's live desktop runtime.

Default to useful, narrow changes in:
- `/home/agony/.local/share/Astrea`

Use this vault as context:
- `/home/agony/Documentos/Astrea/Astrea`

Do not treat GitHub mirrors, old `.config/quickshell` trees, or Bench copies as live unless the user says so or runtime inspection proves it.

## How To Think
1. Find the owner of the behavior.
2. Read the smallest matching note.
3. Inspect the live code.
4. Reuse existing imports, components, bridges, and state.
5. Change only the needed behavior.
6. Validate the changed layer.
7. Update only the affected docs.

## Runtime Map
| Surface | Live owner | Read |
| --- | --- | --- |
| shell startup | `Quickshell/shell.qml` | [[Astrea - Quickshell Runtime]] |
| desktop icons | `Quickshell/desktop` | [[Astrea - Desktop Icons]] |
| topbar and popups | `Quickshell/bar` | [[Astrea - Top Bar]] |
| island and music | `Quickshell/island` | [[Astrea - Island]] |
| spotlight | `Quickshell/spotlight` | [[Astrea - Spotlight]] |
| notifications | `Quickshell/notifications` | [[Astrea - Notifications]] |
| Settings | `Apps/Settings` | [[Astrea - Settings App]] |
| Explorer | `Apps/Explorer` | [[Astrea - Explorer App]] |
| Weather | `Apps/Weather` | [[Astrea - Weather App]] |
| shared controls | `Core/components` | [[Astrea - Core Components]] |
| reusable file UI | `Features/Files` | [[Astrea - Features]] |
| system bridges | `Core/bridge`, `System` | [[Astrea - Core Bridge]], [[Astrea - System Layer]] |
| file chooser portal | `System/portal` + `Apps/Explorer/PortalDialog.qml` | [[Astrea - FileChooser Portal]] |

## Design DNA
Astrea should feel like a polished desktop tool, not a web landing page.

Default style:
- restrained
- dense but readable
- theme-driven
- subtle motion
- clear typography
- minimal decorative chrome

The user preference is often: professional, clean, no visual fluff.

When adding functionality, do not restyle the app.

## App Rules
Settings:
- import `AstreaComponents`
- use `Theme`, `ScrollPage`, `SectionHeader`, `FormCard`, `SettingRow`, `SelectButton`, `ToggleSwitch`
- keep settings pages row/card based
- use `Core/bridge` or `System` for system reads/writes

Explorer:
- import `AstreaFiles`
- use `AstreaFiles.FileContextMenu` for menu frames
- add file actions through app wrappers, `AppState`, and backend flow
- reusable file UI belongs in `Features/Files` and `Features/Files/qmldir`
- Portal dialog behavior belongs in Explorer, while portal DBus ownership belongs in `System/portal`

Weather:
- keep it compact and information-first
- use existing section components and bottom sheets
- data and alert behavior belongs in `Core/bridge/apps/weather.py`

Shell:
- use resident popup patterns
- use `Quickshell/bar/Theme.qml` tokens
- code sharing does not mean visual merging
- verify the active shell before touching runtime behavior
- keep Quickshell as UI: periodic system polling belongs in user services or bridges
- audio, network, and Bluetooth status come from `astrea-status.service` JSON caches under `~/.local/state/Astrea/status`
- Desktop Icons is a conditional bottom-layer shell surface
- It is loaded by `Quickshell/shell.qml` only when `~/.local/state/Astrea/desktop-icons/config.json` has `enabled != false`
- It renders `.desktop` files from the XDG desktop folder, not the full application database

## Design Rules
Read [[Astrea - Design Rules]] before visual edits.

Short version:
- use theme tokens first
- keep typography small and crisp
- preserve local spacing and density
- prefer rows, cards, sheets, and popups already present
- avoid broad redesigns during functional work
- make visual experiments easy to revert

## State Rules
Persistent user config:
- `~/.config/AstreaOS`

Runtime app state:
- `~/.local/state/Astrea`

Cache:
- `~/.cache`

Some legacy state still lives inside the Astrea tree. Inspect the consumer before moving it.

## Bridge Rules
QML talks to the system through `Process`.

State reads should return JSON.

Side effects should be explicit commands.

Long-running or repeated system reads should not live in Quickshell timers.

Prefer:
- backend service writes stable JSON only when state changes
- QML reads with `FileView`
- QML sends `SIGUSR1` or calls a focused command for manual refresh

Do not change command names or JSON fields without updating every consumer and the matching docs.

## Validation Cheatsheet
Use the smallest proof:
- QML file: `qmllint <file.qml>`
- app smoke: `qs -p <entry.qml>`
- shell runtime: `quickshell list --all`, `hyprctl layers`
- Python bridge: `python3 -m py_compile <file.py>`
- bridge output: run the command and inspect JSON
- Rust backend: `cargo check`
- notification path: `notify-send`, `gdbus`
- user service: `systemctl --user`, `journalctl --user`

## Do Not
- do not redesign while fixing behavior
- do not copy shared QML into an app
- do not add a second theme system
- do not hardcode a new palette inside a themed surface
- do not assume `.config/quickshell` is active
- do not restart or kill the shell unless that is the established fix
- do not flatten app-specific behavior into Core
- do not move state paths without a migration
