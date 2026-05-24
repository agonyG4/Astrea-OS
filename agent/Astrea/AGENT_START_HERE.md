# Astrea Agent Start Here

This vault is the operating guide for future agents changing Astrea.

## Absolute Source Of Truth
Implement code in the live runtime:
- `/home/agony/.local/share/Astrea`

Current live target inspected for this sync:
- `/home/agony/.local/share/Astrea-Rolling`

On this machine:
- `/home/agony/.local/share/Astrea -> /home/agony/.local/share/Astrea-Rolling`

Guide copies may exist at:
- `/home/agony/GitHub/Astrea-Dev/agent/Astrea`
- `/home/agony/Documentos/Astrea`

If docs conflict with live code, inspect live code and update the affected doc.

## First 5 Reads
1. [[Astrea]]
2. [[Astrea - AI Project Brain]]
3. [[Astrea - Code Agent Guide]]
4. [[Astrea - Agent Working Rules]]
5. [[Astrea - Entry Points]]

Then read the domain MOC and the specific note for the task.

## Fast Routing
| If the user mentions | Read |
| --- | --- |
| shell, bar, island, spotlight, notifications, desktop icons | [[MOC - UI]] |
| Settings, Explorer, Weather, Media Viewer, Wallpapers, About | [[MOC - Apps]] |
| shared controls, file UI, paper/lockscreen modules | [[MOC - Core]] |
| Python/Rust/Bash backend, JSON bridge, portal, weather daemon | [[MOC - Bridges and Backends]] |
| systemd, Polkit, i18n, Bluetooth, launch, display side effects | [[MOC - System]] |
| paths, caches, state, assets, generated files | [[MOC - Data]] |
| external tools or outside-project dependency | [[MOC - Dependencies]] |

## Agent Contract
- Make the smallest change that solves the requested behavior.
- Change the owning layer, not a convenient neighbor.
- Reuse existing app imports and shared modules.
- Keep visuals unchanged unless the user asked for visual work.
- Validate the touched layer with the smallest useful command.
- Update only the docs affected by behavior/path/contract changes.

## High-Risk Areas
- `System/auth`: privileged/authentication boundary.
- `System/launch` and `System/services/astrea_latencyd.py`: launch daemon and performance burst behavior.
- `System/portal`: DBus/XDG portal contract.
- `Core/bridge/apps/explorer_backend`: compiled Explorer backend.
- `Apps/Weather/backend`: Rust Weather CLI/daemon contract.

## Current App Map
- About: [[Astrea - About App]]
- Settings: [[Astrea - Settings App]]
- Explorer: [[Astrea - Explorer App]]
- Weather: [[Astrea - Weather App]]
- Media Viewer: [[Astrea - Media Viewer App]]
- Wallpapers: [[Astrea - Wallpapers App]]

## Before Final Answer
Run or explain the relevant verification:
- QML: `qmllint <file.qml>` or `qs -p <entry.qml>`
- Python: `python3 -m py_compile <file.py>`
- Rust: `cargo check --manifest-path <Cargo.toml>`
- Services: `systemctl --user status <unit>` and `journalctl --user -u <unit>`
- Docs-only: link/index scan and `git status --short`
