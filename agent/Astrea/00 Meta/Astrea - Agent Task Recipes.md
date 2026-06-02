# Astrea - Agent Task Recipes

Related notes: [[Astrea - Code Agent Guide]], [[Astrea - Entry Points]], [[Astrea - Data Flow]], [[Astrea - Patterns]]

## Purpose
This note gives repeatable investigation and validation recipes for common Astrea code tasks.

Use it after [[Astrea - Code Agent Guide]] when the task needs implementation, debugging, or verification.

## QML UI Change
Read:
1. The app or UI note for the surface.
2. [[Astrea - Core Components]] if shared controls are involved.
3. [[Astrea - Patterns]] for process bridge and state conventions.
4. [[Astrea - Agent Working Rules]] for scope and style boundaries.
5. [[Astrea - Design Rules]] if the change is visual.

Edit:
- app-local QML for app-only behavior
- `Core/components` only for shared controls
- `Quickshell` only for resident shell surfaces
- `Features/*` only for reusable domain UI

Preserve the local style unless the task is visual.

Validate:
- `qmllint <changed.qml>`
- `qs -p <entry.qml>` for standalone app entries
- `quickshell -p <entry.qml>` when matching the active runtime is required

Update docs when:
- a visible workflow changes
- a new state file, setting, dependency, or bridge command appears

## App Feature Addition
Read:
1. [[Astrea - Agent Working Rules]]
2. [[MOC - Apps]]
3. the target app note
4. any shared module note named by the app

Decide ownership:
- app-only workflow: edit the app
- reusable file UI: edit `Features/Files`
- reusable Settings-style control: edit `Core/components`
- system read/write: edit `Core/bridge` or `System`

Edit:
- add the new action, property, process call, or backend method
- keep existing page layout, colors, spacing, typography, and control shape
- import the existing module link instead of copying shared UI
- register new shared QML in the owning module's `qmldir`

Validate:
- `qmllint` for changed QML
- app entry smoke test with `qs -p <entry.qml>` when practical
- direct bridge/backend command if system state changed

Document:
- new public action or setting
- new state/config path
- new bridge command or JSON field

## Shared Context Menu Or File UI Change
Read:
1. [[Astrea - Explorer App]]
2. [[Astrea - Features]]
3. [[Astrea - Explorer Backend]] if the action touches file operations

Use:
- `AstreaFiles.FileContextMenu` for the menu frame
- app-local action delegates for app-specific actions
- `Features/Files/qmldir` for reusable file UI exports

Avoid:
- duplicating the menu frame in the app
- restyling the shared menu while adding one action
- bypassing `AppState` or backend ownership for file operations

Validate:
- `qmllint` on the changed menu/component
- direct backend command for file operations when possible
- Explorer app smoke test when the action changes a visible workflow

## Bridge Or Backend Change
Read:
1. [[MOC - Bridges and Backends]]
2. the specific bridge note
3. the consuming app or shell note

Edit:
- `Core/bridge` for Python or forwarding CLI logic
- native backend source only when the task requires compiled behavior
- avoid changing public command names without updating consumers

Validate:
- `python3 -m py_compile <file.py>`
- bridge command with JSON mode when available
- `cargo check` for Rust backends
- direct consumer smoke test when possible

Update docs when:
- command syntax changes
- output JSON changes
- a new dependency, cache, state file, or side effect appears

## Service Or Runtime Change
Read:
1. [[MOC - System]]
2. [[Astrea - System Layer]]
3. the related app, bridge, or UI note

Validate:
- `systemctl --user status <unit>`
- `journalctl --user -u <unit>`
- runtime command called by the service

Document:
- unit names
- owning script
- state/log paths
- manual recovery command if useful

## Network Or Internet Settings Change
Read:
1. [[Astrea - Settings App]]
2. [[Astrea - Network Bridge]]
3. [[Astrea - External Dependencies]]

Edit:
- `Apps/Settings/pages/connectivity/Internet.qml` for UI and presentation
- `Core/bridge/network/manager.py` for stats, DNS, Wi-Fi, and WARP behavior

Validate:
- `python3 -m py_compile /home/agony/.local/share/Astrea/Core/bridge/network/manager.py`
- run the changed bridge command directly
- `qmllint /home/agony/.local/share/Astrea/Apps/Settings/pages/connectivity/Internet.qml` for QML edits

Document:
- new bridge command names
- JSON fields consumed by QML
- new external commands or services
- new config/state paths

## Gaming Or Windows Compatibility Change
Read:
1. [[Astrea - Settings App]]
2. [[Astrea - Gaming and Compatibility]]
3. [[Astrea - External Dependencies]]

Edit:
- `Apps/Settings/pages/gaming/*.qml` for UI controls
- `System/scripts/astrea-gaming-settings` for saved Gamescope/Proton/Compatibility config
- `System/scripts/astrea-windows-run` for `.exe` and `.msi` launch behavior
- `bin/astrea-gaming` or `bin/astrea-gamescope-session` only when wrapper behavior changes

Validate:
- `python3 -m py_compile /home/agony/.local/share/Astrea/System/scripts/astrea-gaming-settings`
- `python3 -m py_compile /home/agony/.local/share/Astrea/System/scripts/astrea-windows-run`
- `/home/agony/.local/share/Astrea/System/scripts/astrea-gaming-settings get`
- `qmllint` on touched gaming pages

Document:
- saved config paths under `~/.config/AstreaOS/gaming`
- generated launchers or environment files
- optional dependencies such as Gamescope, Proton, Wine, umu, GameMode, and MangoHud

## Notification Change
Read:
1. [[Astrea - Notifications]]
2. the app or bridge emitting the notification

Validate:
- `notify-send "Astrea test" "message"`
- `gdbus` only when testing DBus behavior directly
- app-specific notification command if one exists

Document:
- whether the app owns a preference
- whether deduplication exists
- state files used by the notification path

## Explorer Or Portal Change
Read:
1. [[Astrea - Explorer App]]
2. [[Astrea - Explorer Backend]]
3. [[Astrea - External Dependencies]]

Validate:
- backend command directly
- app launch or focused QML view
- MIME/portal behavior from the application that triggers it when relevant

Document:
- portal ownership
- MIME defaults
- backend command changes
- file action side effects

## Documentation-Only Change
Read:
1. [[Astrea]]
2. the affected MOC
3. the affected component note

Keep changes:
- short
- specific to the current behavior
- linked to adjacent notes

Check:
- `rg` for old terminology
- search for standard merge conflict markers
