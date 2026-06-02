# Astrea Runtime Architecture

Astrea keeps the runtime entrypoint stable at `~/.local/share/Astrea`.
Channel directories such as `Astrea-Rolling` are implementation details.

## Top-Level Boundaries

- `Apps/`: app entrypoints and app-owned code. If an app has its own backend, it stays inside that app.
- `UI/`: canonical UI namespace. It points to shell surfaces, shared QML components, and UI assets.
- `Backend/`: canonical system backend namespace. It points to shared bridges, services, portal helpers, and auth helpers.
- `Runtime/`: runtime wiring such as scripts, config, and i18n.
- `Core/`: compatibility home for shared components and bridge code used by existing imports.
- `System/`: compatibility home for OS integration, services, scripts, portal code, and auth helpers.
- `Assets/`: shipped static assets.
- `Features/`: cross-app features that are larger than a single app but not global runtime services.
- `Data/`: legacy durable user/project data location when present. New user libraries should prefer `~/.local/share/AstreaOS`; cache and generated state should prefer `~/.cache`, `~/.local/state`, or `~/.config`.
- `Docs/Architecture/`: structure notes and migration rules.
- `Tools/structure/`: structure checks and maintenance helpers.

## Migration Rule

Use `UI/`, `Backend/`, and `Runtime/` for new code and docs.
Keep `Apps/`, `Core/`, `System/`, and `Quickshell/` working until all live imports and launchers have migrated.
Do not move an app-owned backend out of its app directory.
Do not put new user-owned libraries inside the installed runtime tree; use `~/.local/share/AstreaOS` for durable user data.

## Current Compatibility Links

- `UI/shell -> ../Quickshell`
- `UI/components -> ../Core/components`
- `UI/assets -> ../Assets/ui`
- `Assets/audio -> ../audio`
- `Backend/bridge -> ../Core/bridge`
- `Backend/services -> ../System/services`
- `Backend/portal -> ../System/portal`
- `Backend/auth -> ../System/auth`
- `Runtime/bin -> ../bin`
- `Runtime/scripts -> ../System/scripts`
- `Runtime/config -> ../System/config`
- `Runtime/i18n -> ../System/i18n`

These links make the intended architecture visible without breaking the live shell.
