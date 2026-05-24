# MOC - Apps

Parent: [[Astrea]]

## Purpose
App notes describe standalone Astrea applications.

## Apps
- [[Astrea - About App]]
- [[Astrea - Settings App]]
- [[Astrea - Explorer App]]
- [[Astrea - Weather App]]
- [[Astrea - Media Viewer App]]
- [[Astrea - Wallpapers App]]

## App Backends
- About: [[Astrea - Core Bridge]]
- Settings: [[Astrea - Core Bridge]], [[Astrea - App Manager Bridge]], [[Astrea - Display Bridge]], [[Astrea - Audio Bridge]], [[Astrea - Bluetooth Manager]], [[Astrea - Wallpaper Bridge]], [[Astrea - I18n]]
- Explorer: [[Astrea - Explorer Backend]]
- Weather: [[Astrea - Weather Bridge]]
- Media Viewer: `Apps/MediaViewer/media_viewer_helper.py`
- Wallpapers: [[Astrea - Wallpaper Bridge]]

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
- Weather uses `AstreaComponents`, app-local components, and [[Astrea - Weather Bridge]] for data.
- Media Viewer and Wallpapers use `AstreaComponents`.

Do not duplicate a shared context menu, row, card, sidebar, or theme object inside an app.

## Before Editing An App
Check:
1. the app note
2. [[Astrea - Agent Working Rules]]
3. [[Astrea - Design Rules]] if visuals are involved
4. [[Astrea - Patterns]]
5. the related bridge/backend note if system state or file operations are involved
