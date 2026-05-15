# MOC - Apps

Parent: [[Astrea]]

## Purpose
App notes describe standalone Astrea applications.

## Apps
- [[Astrea - Settings App]]
- [[Astrea - Explorer App]]
- [[Astrea - Weather App]]

## App Backends
- Settings: [[Astrea - Core Bridge]], [[Astrea - Display Bridge]], [[Astrea - Audio Bridge]], [[Astrea - Bluetooth Manager]], [[Astrea - Wallpaper Bridge]]
- Explorer: [[Astrea - Explorer Backend]]
- Weather: [[Astrea - Weather Bridge]]

## Shared Dependencies
- [[Astrea - Core Components]]
- [[Astrea - Features]]
- [[Astrea - Assets and Data]]

## App Extension Rule
When adding functionality to an app, keep the app's current style and module boundaries.

Add the new behavior where the app already owns similar behavior.

Reuse shared imports:
- Settings uses `AstreaComponents`.
- Explorer uses `AstreaFiles`.
- Weather uses app-local components plus [[Astrea - Weather Bridge]] for data.

Do not duplicate a shared context menu, row, card, sidebar, or theme object inside an app.

## Before Editing An App
Check:
1. the app note
2. [[Astrea - Agent Working Rules]]
3. [[Astrea - Design Rules]] if visuals are involved
4. [[Astrea - Patterns]]
5. the related bridge/backend note if system state or file operations are involved
