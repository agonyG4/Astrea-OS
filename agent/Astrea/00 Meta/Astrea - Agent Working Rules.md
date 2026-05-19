# Astrea - Agent Working Rules

Related notes: [[Astrea]], [[Astrea - AI Project Brain]], [[Astrea - Code Agent Guide]], [[Astrea - Design Rules]], [[Astrea - Agent Task Recipes]], [[Astrea - Patterns]]

## Purpose
This note defines the working rules for AI code agents changing Astrea.

Use it before editing apps, shared QML modules, shell surfaces, bridges, or runtime state.

## Operating Principle
Astrea is a live desktop runtime, not a prototype.

Make the smallest useful change that solves the requested behavior.

Preserve the existing visual language unless the user explicitly asks for visual redesign.

## Source Of Truth
Implementation work starts in:
- `/home/agony/.local/share/Astrea`

Documentation lives in:
- `/home/agony/GitHub/Astrea-Dev/agent/Astrea`

Current inspected runtime source:
- `/home/agony/.local/share/Astrea-Rolling`

Repo mirrors are not the live runtime unless the user explicitly says so.

If a mirror and the live tree both matter, say that clearly and keep the two copies aligned only when the task asks for it.

When shell behavior depends on the active instance, verify it before assuming paths:
- `quickshell list --all`
- `hyprctl layers`

## Scope Rules
- Change behavior in the owning app, feature module, bridge, or shell surface.
- Do not redesign a page while adding a backend action.
- Do not change colors, radius, spacing, typography, or animations unless the task is visual.
- Do not move files or rename public commands as a side effect of a narrow fix.
- Do not duplicate a shared component inside an app to make a quick local variant.
- Do not add a new dependency when an existing bridge, helper, component, or module already covers the need.

## App Extension Rule
When adding functionality to an app, import and reuse the app's existing shared surface.

Add only the new action, state binding, process call, or backend method needed for the feature.

Keep the existing app style untouched.

Examples:
- Settings pages should use `Apps/Settings/AstreaComponents -> Core/components`.
- Explorer file UI should use `Apps/Explorer/AstreaFiles -> Features/Files`.
- Weather UI should use `Apps/Weather/AstreaComponents -> Core/components` plus Weather-local section components.
- Explorer context menus should wrap `AstreaFiles.FileContextMenu` and add app-specific actions inside it.
- Settings controls should prefer `SectionHeader`, `SettingRow`, `SelectButton`, `ToggleSwitch`, `FormCard`, and other exported core controls.

If the feature needs a new reusable visual primitive, add it to the matching shared module and register it in that module's `qmldir`.

If the feature is app-only, keep it app-local.

## Shared Module Boundaries
`Core/components` owns reusable generic controls:
- theme
- navigation
- forms
- rows
- cards
- feedback/status pieces

`Features/Files` owns reusable file-manager UI:
- file context menu frame
- operation progress card
- file sidebar frame
- drag/drop support

`Features/Paper` owns wallpaper, lockscreen, and paper-related reusable pieces.

`Apps/*` owns app workflows, page state, page-specific delegates, and process calls.

`Quickshell/*` owns shell surfaces: bar, island, spotlight, notifications, and conditional desktop icons.

`Core/bridge` owns command wrappers and JSON-producing bridge scripts.

`System` owns local services, system config, auth helpers, scripts, cache, and metadata.

`System/launch`, `bin/astrea-launch`, and `System/services/astrea_latencyd.py` own Astrea app-launch routing and temporary launch bursts.

## Import Rules
Use local module links already present in the app.

Do:
- `import "AstreaComponents"` from `Apps/Settings/main.qml`.
- `import "../../AstreaComponents"` from Settings pages.
- `import "AstreaFiles" as AstreaFiles` from Explorer entrypoints.
- `import "../../AstreaFiles" as AstreaFiles` from nested Explorer components.
- `import "../AstreaComponents" as UI` from Weather UI files.

Avoid:
- new absolute QML imports to `/home/agony/.local/share/Astrea/...`
- copying shared QML into an app folder
- creating a second style system inside one page
- bypassing a `qmldir` when the module already exports the component

## Bridge Rules
QML should call a bridge or backend through `Process` when system state is involved.

Prefer JSON stdout for state reads.

Prefer explicit command names for side effects.

Keep bridge output stable for existing consumers.

Astrea-owned app launch calls should use `bin/astrea-launch` so launcher history and latency burst behavior stay centralized.

When changing a JSON contract, update:
- the bridge note
- the consuming app note
- validation examples when useful

## State And Config Rules
Persistent user-facing config belongs under:
- `~/.config/AstreaOS`

Runtime/application state belongs under:
- `~/.local/state/Astrea`

Caches belong under:
- `~/.cache`

Some older runtime state still exists inside the Astrea tree. Treat those paths as current only after inspecting the consumer.

Do not silently move state files unless the task is a migration and all readers/writers are updated.

## UI Style Rules
Astrea UI should feel native to the existing surface.

See [[Astrea - Design Rules]] before visual edits.

For app feature work:
- match the local page density
- reuse the page's existing row/card/control pattern
- keep text hierarchy consistent
- keep controls aligned with nearby controls
- avoid adding marketing copy or explanatory blocks
- avoid decorative containers when the current app uses functional rows

For visual work:
- inspect the target page before editing
- make small reversible changes
- validate at the real app entrypoint

## Runtime Safety Rules
- Never assume `.config/quickshell` is the active shell when Astrea has a live `Quickshell` tree.
- Avoid killing or restarting the whole shell for a setting unless that is the established runtime behavior.
- For resident shell components, validate with the real shell path when possible.
- For package or system-level fixes, document the exact command and smoke test if root approval is outside the current task.

## Validation Rule
Use the smallest validation that proves the changed layer.

Typical checks:
- QML file: `qmllint <file.qml>`
- standalone app: `qs -p <entry.qml>` or `quickshell -p <entry.qml>`
- Python bridge: `python3 -m py_compile <file.py>`
- bridge behavior: run the command and inspect JSON
- Rust backend: `cargo check`
- shell runtime: `quickshell list --all`, `hyprctl layers`
- notification path: `notify-send`, `gdbus`
- systemd user path: `systemctl --user`, `journalctl --user`

If validation cannot run, document why and list the next exact check.

## Documentation Rule
When code behavior changes, update only the affected note.

Good documentation changes:
- name the real path
- name the entrypoint
- name the owner module
- name the state/config path
- name the validation command
- describe the behavior, not the intention

Avoid broad rewrites that make the vault harder to diff.
