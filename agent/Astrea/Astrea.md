---
aliases:
  - Astrea Brain
  - Astrea Project
---

# Astrea

This is the main project brain for the live Astrea runtime at `/home/agony/.local/share/Astrea`.

Use this note as the first stop before reading subsystem notes.

## Start Here
- [[Astrea - AI Project Brain]]
- [[Astrea - Code Agent Guide]]
- [[Astrea - Agent Working Rules]]
- [[Astrea - Design Rules]]
- [[Astrea - Project Overview]]
- [[Astrea - Runtime Snapshot]]
- [[Astrea - Entry Points]]
- [[Astrea - Structure Breakdown]]
- [[Astrea - Data Flow]]
- [[Astrea - Patterns]]
- [[Astrea - Unknowns]]

## Domain MOCs
- [[MOC - Architecture]]
- [[MOC - UI]]
- [[MOC - Apps]]
- [[MOC - Core]]
- [[MOC - Bridges and Backends]]
- [[MOC - System]]
- [[MOC - Data]]
- [[MOC - Meta]]
- [[MOC - Dependencies]]

## Architecture Domains
- Architecture: [[Astrea - Project Overview]], [[Astrea - Runtime Snapshot]], [[Astrea - Structure Breakdown]], [[Astrea - Entry Points]], [[Astrea - Data Flow]], [[Astrea - Patterns]]
- UI runtime: [[Astrea - Quickshell Runtime]], [[Astrea - Desktop Icons]], [[Astrea - Top Bar]], [[Astrea - Island]], [[Astrea - Spotlight]], [[Astrea - Notifications]]
- Apps: [[Astrea - About App]], [[Astrea - Settings App]], [[Astrea - Explorer App]], [[Astrea - Weather App]]
- Core: [[Astrea - Core Components]], [[Astrea - Features]]
- Bridges and backends: [[Astrea - Core Bridge]], [[Astrea - Explorer Backend]], [[Astrea - FileChooser Portal]], [[Astrea - Weather Bridge]], [[Astrea - Audio Bridge]], [[Astrea - Display Bridge]], [[Astrea - Wallpaper Bridge]]
- System: [[Astrea - System Layer]], [[Astrea - Launcher and Latency]], [[Astrea - Bluetooth Manager]]
- Data and assets: [[Astrea - Assets and Data]]
- Meta: [[Astrea - AI Project Brain]], [[Astrea - Agent Working Rules]], [[Astrea - Design Rules]], [[Astrea - Unknowns]], [[Astrea - External Dependencies]]

## Runtime Map
- [[Astrea - Quickshell Runtime]]
- [[Astrea - Desktop Icons]]
- [[Astrea - Top Bar]]
- [[Astrea - Island]]
- [[Astrea - Spotlight]]
- [[Astrea - Notifications]]

## App Map
- [[Astrea - Settings App]]
- [[Astrea - Explorer App]]
- [[Astrea - Weather App]]
- [[Astrea - About App]]

## Backend Map
- [[Astrea - Core Bridge]]
- [[Astrea - Explorer Backend]]
- [[Astrea - Weather Bridge]]
- [[Astrea - Audio Bridge]]
- [[Astrea - Display Bridge]]
- [[Astrea - Wallpaper Bridge]]
- [[Astrea - Bluetooth Manager]]
- [[Astrea - Launcher and Latency]]

## Open Questions
- [[Astrea - Unknowns]]
- [[Astrea - External Dependencies]]

## AI Reading Order
For code agents:
1. [[Astrea - AI Project Brain]]
2. [[Astrea - Code Agent Guide]]
3. [[Astrea - Agent Working Rules]]
4. [[Astrea - Agent Task Recipes]]
5. [[Astrea - Runtime Snapshot]]
6. [[Astrea - Entry Points]]
7. [[Astrea - Data Flow]]
8. The matching domain MOC.
9. The specific app, UI, bridge, system, or data note.

For a broad understanding:
1. [[Astrea - Project Overview]]
2. [[Astrea - Structure Breakdown]]
3. [[Astrea - Runtime Snapshot]]
4. [[Astrea - Entry Points]]
5. [[Astrea - Data Flow]]
6. [[Astrea - Patterns]]
7. The domain MOC that matches the task.

For bug investigation:
1. Identify the domain from [[Astrea - Entry Points]].
2. Check [[Astrea - AI Project Brain]] for ownership.
3. Check [[Astrea - Agent Working Rules]] for scope and import boundaries.
4. Read the matching domain MOC.
5. Read the component note.
6. Follow bridge/backend links.
7. Check [[Astrea - Unknowns]] before assuming behavior.
