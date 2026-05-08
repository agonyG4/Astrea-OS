# Astrea - Wallpaper Bridge

Related notes: [[Astrea - Settings App]], [[Astrea - Features]], [[Astrea - Assets and Data]]

## Folder
`Core/bridge/wallpaper/`

## Responsibility
Wallpaper, lockscreen image cache, blur, and paper-library orchestration.

## Main Files
- `wallpaper_manager.py`
- `img_cache.py`
- `blur_lockscreen.py`

## Consumers
- `Apps/Settings/pages/paper/Paper.qml`
- `Apps/Settings/pages/paper/Wallpaper.qml`
- `Apps/Settings/pages/paper/Lockscreen.qml`

## Config/Data
- user config under `~/.config/AstreaOS/user`
- wallpaper user data under `Data/user/wallpapers`
- paper libraries under `Features/Paper/library`

## Unknown
The exact image-processing commands used by every path were not fully audited in this pass.

