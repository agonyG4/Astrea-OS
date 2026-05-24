# Astrea - Wallpaper Bridge

Related notes: [[Astrea - Settings App]], [[Astrea - Wallpapers App]], [[Astrea - Features]], [[Astrea - Assets and Data]]

## Folder
`Core/bridge/wallpaper/`

## Responsibility
Wallpaper, lockscreen image cache, blur, and paper-library orchestration.

## Main Files
- `wallpaper_manager.py`
- `img_cache.py`
- `blur_lockscreen.py`

## Consumers
- `Apps/Wallpapers/main.qml`
- `Apps/Settings/pages/paper/Paper.qml`
- `Apps/Settings/pages/paper/Wallpaper.qml`
- `Apps/Settings/pages/paper/Lockscreen.qml`

## Config/Data
- user config under `~/.config/AstreaOS/user`
- current wallpaper user data under `~/.local/share/AstreaOS/user/wallpapers`
- legacy wallpaper user data under `Data/user/wallpapers`
- paper libraries under `Features/Paper/library`

## Commands
- `scan-library`
- `list-user`
- `add-user --src <path> --name <name>`
- `rename-user --slug <slug> --name <name>`
- `delete-user --slug <slug>`
- `state --scope wallpaper|lockscreen`
- `set-transition --index <number>`
- `set-blurred --enabled 0|1`
- `apply --scope wallpaper|lockscreen --src <path> --name <name>`
- `refresh-assets --scope wallpaper|lockscreen --expected-src <path>`

## Unknown
The exact image-processing commands used by every path were not fully audited in this pass.
