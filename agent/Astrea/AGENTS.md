# Astrea Code Agent Guide

This vault documents the live Astrea runtime.

Primary runtime path:
- `/home/agony/.local/share/Astrea`

Current inspected live target:
- `/home/agony/.local/share/Astrea-Rolling`

Primary documentation path:
- `/home/agony/GitHub/Astrea-Dev/agent/Astrea`

User-facing documentation mirror:
- `/home/agony/Documentos/Astrea`

Use the live runtime path for implementation work unless the user explicitly asks for documentation-only changes.

## First Reads
1. `AGENT_START_HERE.md`
2. `Astrea.md`
3. `00 Meta/Astrea - AI Project Brain.md`
4. `00 Meta/Astrea - Code Agent Guide.md`
5. `00 Meta/Astrea - Agent Working Rules.md`
6. `00 Meta/Astrea - Design Rules.md`
7. `00 Meta/Astrea - Agent Task Recipes.md`
8. `01 Architecture/Astrea - Runtime Snapshot.md`
9. `01 Architecture/Astrea - Entry Points.md`
10. `01 Architecture/Astrea - Data Flow.md`
11. The app, bridge, UI, or system note that matches the task.

## Core Rule
Astrea is a live desktop runtime.

Solve the requested behavior with the smallest scoped change.

Do not restyle, reorganize, rename, or redesign while adding functionality unless the user explicitly asks for that.

For the shortest full context, read `00 Meta/Astrea - AI Project Brain.md`.

For visual work, read `00 Meta/Astrea - Design Rules.md`.

## App Feature Rule
When adding features to apps, reuse the existing app imports and shared modules.

Examples:
- Settings pages should use `AstreaComponents` from `Apps/Settings/AstreaComponents -> Core/components`.
- Explorer file UI should use `AstreaFiles` from `Apps/Explorer/AstreaFiles -> Features/Files`.
- Explorer context menu work should add actions inside the existing wrapper around `AstreaFiles.FileContextMenu`.
- App translations should use `AstreaI18n` links into `System/i18n` instead of hardcoding parallel language maps.
- Shared file UI belongs in `Features/Files` and must be exported through `Features/Files/qmldir`.
- Shared Settings controls belong in `Core/components` and must be exported through `Core/components/qmldir`.
- Launch behavior belongs in `System/launch`, `bin/astrea-launch`, `System/services/astrea_latencyd.py`, and the `astrea-launchd`/`astrea-latencyd` services.
- Media Viewer behavior belongs in `Apps/MediaViewer/Main.qml` and `Apps/MediaViewer/media_viewer_helper.py`; previews cache under `~/.cache/Astrea/media-viewer/previews`.
- Standalone Wallpapers behavior belongs in `Apps/Wallpapers/main.qml`; wallpaper side effects stay in `Core/bridge/wallpaper/wallpaper_manager.py`.

Keep page density, spacing, colors, typography, and control shape consistent with the nearby UI.

Use `Theme.*` tokens before introducing any hardcoded colors.

## High-Signal Task Routing
- Shell/topbar/island/spotlight/notifications: read `02 UI/MOC - UI.md`.
- Settings, Explorer, Weather: read `03 Apps/MOC - Apps.md`.
- Media Viewer or Wallpapers: read `03 Apps/MOC - Apps.md` plus the specific app note.
- Python, Rust, Bash, DBus, portal, or CLI behavior: read `05 Bridges/MOC - Bridges and Backends.md`.
- Bluetooth, system services, display, theme side effects: read `06 System/MOC - System.md`.
- Language/i18n or Polkit prompts: read `06 System/MOC - System.md`.
- App launch, latency burst, or runtime service install: read `06 System/Astrea - Launcher and Latency.md`.
- Paths, cache, generated state, assets: read `07 Data/MOC - Data.md` and `08 Dependencies/MOC - Dependencies.md`.

## Validation Bias
Prefer practical local validation:
- QML: `qmllint`, `qs -p`, `quickshell -p`
- Python: `python3 -m py_compile`
- Rust: `cargo check`
- Services: `systemctl --user`, `journalctl --user`
- Desktop/runtime state: `hyprctl`, `gdbus`, `notify-send`, app-specific backend commands

When shell behavior depends on the running instance, check `quickshell list --all` before assuming which tree is active.

## Boundaries
- Do not assume repo mirrors are live.
- Do not rewrite unrelated docs while fixing a narrow task.
- Treat `00 Meta/Astrea - Unknowns.md` as a warning list, not a source of truth.
- When docs conflict with inspected code, inspect the live code and update the docs.
