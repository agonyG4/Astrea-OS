# Astrea - Wallpapers App

Related notes: [[Astrea]], [[Astrea - Wallpaper Bridge]], [[Astrea - Settings App]], [[Astrea - Assets and Data]]

## Folder
`Apps/Wallpapers/`

## Main Entry
`Apps/Wallpapers/main.qml`

## Responsibility
Wallpapers is the standalone wallpaper-library manager.

It lets the user:
- list user wallpapers
- select a wallpaper
- apply it to wallpaper or lockscreen scope
- rename a user wallpaper
- delete a user wallpaper after confirmation

## Backend
The app calls:
- `Core/bridge/wallpaper/wallpaper_manager.py list-user`
- `Core/bridge/wallpaper/wallpaper_manager.py apply --scope wallpaper|lockscreen --src <path> --name <name>`
- `Core/bridge/wallpaper/wallpaper_manager.py rename-user --slug <slug> --name <name>`
- `Core/bridge/wallpaper/wallpaper_manager.py delete-user --slug <slug>`

Keep wallpaper side effects in [[Astrea - Wallpaper Bridge]]. Do not reimplement wallpaper application logic in QML.

## Data
Current bridge-owned user wallpaper location:
- `~/.local/share/AstreaOS/user/wallpapers`

Legacy wallpapers may be migrated from:
- `/home/agony/.local/share/Astrea/Data/user/wallpapers`

Wallpaper config lives under:
- `~/.config/AstreaOS/user/paper/wallpaper`
- `~/.config/AstreaOS/user/paper/lockscreen`

## Shared UI
The app uses:
- `Apps/Wallpapers/AstreaComponents -> Core/components`

It should stay visually aligned with Settings: compact sidebar, theme tokens, small typography, and simple cards.

## Backups
`Backups/wallpapers-app` contains timestamped local backups from previous edits. Treat it as historical recovery material, not active app code.

## Validation
- `qmllint /home/agony/.local/share/Astrea/Apps/Wallpapers/main.qml`
- `python3 /home/agony/.local/share/Astrea/Core/bridge/wallpaper/wallpaper_manager.py list-user`
- `qs -p /home/agony/.local/share/Astrea/Apps/Wallpapers/main.qml`
