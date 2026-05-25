# Astrea - App Manager Bridge

Related notes: [[Astrea - Settings App]], [[Astrea - Core Bridge]], [[Astrea - Launcher and Latency]]

## Files
- `Core/bridge/apps.py`
- `Core/bridge/apps/manager.py`
- `Core/bridge/apps/app_uninstall.py`
- `Core/bridge/apps/test_manager.py`

`Core/bridge/apps.py` is a small forwarding entrypoint into `apps/manager.py`.

## Responsibility
The app manager bridge lists and manages installed desktop applications for Settings.

It reads `.desktop` files from XDG application directories, normalizes names/icons/categories through `astrea_shared.py`, and returns JSON for `Apps/Settings/pages/apps/Apps.qml`.

## Actions
`manager.py` accepts:
- `list`
- `details <identifier>`
- `create-shortcut <identifier>`
- `open-location <identifier>`
- `uninstall <identifier>`
- `set-permission <identifier> <permission> <blocked|allowed>`

Identifiers can be desktop IDs, desktop file paths, or parsed app identifiers.

## Boundaries
- `astrea-settings.desktop` is protected from uninstall.
- App launch should go through [[Astrea - Launcher and Latency]], not this bridge.
- Uninstall behavior belongs in `apps/app_uninstall.py`.
- Desktop file parsing and icon resolution belong in `Core/bridge/astrea_shared.py`.

## Consumers
- `Apps/Settings/pages/apps/Apps.qml`
- Desktop shortcut refresh flows in [[Astrea - Desktop Icons]]

## Validation
- `python3 -m py_compile /home/agony/.local/share/Astrea/Core/bridge/apps/manager.py`
- `python3 /home/agony/.local/share/Astrea/Core/bridge/apps.py list`
- `python3 /home/agony/.local/share/Astrea/Core/bridge/apps.py details astrea-settings.desktop`
