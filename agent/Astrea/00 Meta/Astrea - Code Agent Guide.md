# Astrea - Code Agent Guide

Related notes: [[Astrea]], [[Astrea - AI Project Brain]], [[Astrea - Agent Working Rules]], [[Astrea - Design Rules]], [[Astrea - Entry Points]], [[Astrea - Data Flow]], [[Astrea - Patterns]], [[Astrea - Unknowns]]

## Purpose
This note is the fast path for code agents working on Astrea.

It explains where to start, which paths are live, and how to choose the next note without reading the full vault first.

For the shortest project brain, read [[Astrea - AI Project Brain]] first.

## Source Of Truth
Use the live runtime tree for implementation:
- `/home/agony/.local/share/Astrea`

Use this vault for architecture context:
- `/home/agony/GitHub/Astrea-Dev/agent/Astrea`

Current inspected runtime:
- `/home/agony/.local/share/Astrea-Rolling`

`~/.local/share/Astrea` currently resolves to Rolling. Keep app code pointed at `~/.local/share/Astrea` or `ASTREA_ROOT`; do not bake channel names into app logic.

When documentation and inspected code disagree:
1. Trust the inspected live code.
2. Make the code change in the live runtime tree.
3. Update the affected note in this vault.

## Work Rules Summary
Read [[Astrea - Agent Working Rules]] before editing.

The short version:
- solve the requested behavior with the smallest scoped change
- preserve the existing visual language unless the task is visual
- reuse the app's current shared components and module imports
- add new behavior at the owning layer
- validate the changed layer with the smallest practical local command

For app work, add functionality without changing style.

For example:
- Settings pages should use `AstreaComponents`.
- Explorer file UI should use `AstreaFiles`.
- Explorer context menu actions should be added inside the existing wrapper around `AstreaFiles.FileContextMenu`.
- Apps that need translations should use the app-local `AstreaI18n` link or `System/i18n/i18n.py`.
- New reusable visuals should live in the matching shared module and be exported through that module's `qmldir`.

## Reading Order
For broad context:
1. [[Astrea]]
2. [[Astrea - AI Project Brain]]
3. [[Astrea - Agent Working Rules]]
4. [[Astrea - Project Overview]]
5. [[Astrea - Runtime Snapshot]]
6. [[Astrea - Structure Breakdown]]
7. [[Astrea - Entry Points]]
8. [[Astrea - Data Flow]]
9. [[Astrea - Patterns]]

For a targeted bug or feature:
1. Identify the domain from [[Astrea - Entry Points]].
2. Read [[Astrea - AI Project Brain]] for ownership.
3. Read [[Astrea - Agent Working Rules]] for scope and import boundaries.
4. Read [[Astrea - Design Rules]] if visuals are involved.
5. Read the matching MOC.
6. Read the specific component note.
7. Follow bridge/backend links.
8. Use [[Astrea - Agent Task Recipes]] for validation.
9. Check [[Astrea - Unknowns]] for unresolved ownership or stale assumptions.

## Task Routing
| Task area | Start with | Then read |
| --- | --- | --- |
| Shell runtime | [[MOC - UI]] | [[Astrea - Quickshell Runtime]] |
| Top bar | [[MOC - UI]] | [[Astrea - Top Bar]] |
| Island | [[MOC - UI]] | [[Astrea - Island]] |
| Spotlight | [[MOC - UI]] | [[Astrea - Spotlight]], [[Astrea - Weather Bridge]] |
| Notifications | [[MOC - UI]] | [[Astrea - Notifications]] |
| Settings app | [[MOC - Apps]] | [[Astrea - Settings App]], [[Astrea - Core Components]] |
| Explorer app | [[MOC - Apps]] | [[Astrea - Explorer App]], [[Astrea - Explorer Backend]] |
| Weather app | [[MOC - Apps]] | [[Astrea - Weather App]], [[Astrea - Weather Bridge]] |
| Media Viewer app | [[MOC - Apps]] | [[Astrea - Media Viewer App]] |
| Wallpapers app | [[MOC - Apps]] | [[Astrea - Wallpapers App]], [[Astrea - Wallpaper Bridge]] |
| About app | [[MOC - Apps]] | [[Astrea - About App]], [[Astrea - Core Bridge]] |
| Shared QML controls | [[MOC - Core]] | [[Astrea - Core Components]] |
| Python bridge | [[MOC - Bridges and Backends]] | [[Astrea - Core Bridge]] |
| App manager bridge | [[MOC - Bridges and Backends]] | [[Astrea - App Manager Bridge]] |
| Session/state JSON helpers | [[MOC - Bridges and Backends]] | [[Astrea - Session Daemon]], [[Astrea - State JSON Bridge]] |
| Audio | [[MOC - Bridges and Backends]] | [[Astrea - Audio Bridge]] |
| Display | [[MOC - Bridges and Backends]] | [[Astrea - Display Bridge]] |
| Wallpaper | [[MOC - Bridges and Backends]] | [[Astrea - Wallpaper Bridge]] |
| I18n/language | [[MOC - System]] | [[Astrea - I18n]] |
| Polkit/auth prompts | [[MOC - System]] | [[Astrea - Polkit Auth]] |
| Bluetooth | [[MOC - System]] | [[Astrea - Bluetooth Manager]] |
| Launch and latency | [[MOC - System]] | [[Astrea - Launcher and Latency]] |
| Runtime state/data | [[MOC - Data]] | [[Astrea - Assets and Data]] |
| External tools | [[MOC - Dependencies]] | [[Astrea - External Dependencies]] |

## Common Live Paths
- Runtime root: `/home/agony/.local/share/Astrea`
- Current Rolling tree: `/home/agony/.local/share/Astrea-Rolling`
- Apps: `/home/agony/.local/share/Astrea/Apps`
- Quickshell runtime: `/home/agony/.local/share/Astrea/Quickshell`
- Shared QML components: `/home/agony/.local/share/Astrea/Core/components`
- Bridges: `/home/agony/.local/share/Astrea/Core/bridge`
- I18n catalogs: `/home/agony/.local/share/Astrea/System/i18n`
- Media Viewer cache: `~/.cache/Astrea/media-viewer/previews`
- User config: `~/.config/AstreaOS`
- Runtime state: `~/.local/state/Astrea`
- Weather cache: `~/.cache/weather`
- Launch history: `~/.local/state/Astrea/launch/history.jsonl`
- Latency history: `~/.local/state/Astrea/latencyd/history.jsonl`

## Validation Commands
Use the smallest command that proves the change.

QML:
- `qmllint <file.qml>`
- `qs -p <entry.qml>`
- `quickshell -p <entry.qml>`

Python:
- `python3 -m py_compile <file.py>`
- run the bridge command with `--json` when available

Rust:
- `cargo check`
- `cargo build --release` when the runtime uses release binaries

Services and DBus:
- `systemctl --user status <unit>`
- `journalctl --user -u <unit>`
- `gdbus call --session ...`
- `notify-send "Astrea test" "message"`

Hyprland/runtime:
- `hyprctl layers`
- `hyprctl clients`
- `hyprctl monitors -j`
- `quickshell list --all`

## Documentation Update Rule
After changing live code, update docs only where the behavior changed:
- component note
- bridge/backend note
- data flow note
- dependency/data note if paths, commands, services, or state files changed

Keep updates short and concrete.
