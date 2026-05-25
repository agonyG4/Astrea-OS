# Astrea - Media Viewer App

Related notes: [[Astrea]], [[Astrea - Explorer App]], [[Astrea - Assets and Data]]

## Folder
`Apps/MediaViewer/`

## Main Entry
`Apps/MediaViewer/Main.qml`

`Apps/MediaViewer/shell.qml` exists as the Quickshell wrapper entrypoint.

## Responsibility
Media Viewer is a standalone image viewer for local files and folders.

It supports:
- opening a target from `ASTREA_MEDIA_TARGET`
- scanning sibling images in the target directory
- thumbnail strip navigation
- fit-to-window and actual-size zoom modes
- smooth zoom/pan behavior
- direct Qt image display when possible
- cached preview conversion for image formats Qt cannot read directly

## Backend
`Apps/MediaViewer/media_viewer_helper.py`

Commands:
- `scan <directory>`
- `open <target>`
- `preview <image>`

The helper returns compact JSON for QML. It recognizes common raster, raw, vector, and high-dynamic-range extensions.

## Preview Cache
Direct Qt-compatible formats use the original file URI.

Other image formats are converted with:
- ImageMagick `magick` or `convert`
- `ffmpeg` as a fallback

Converted previews are stored under:
- `~/.cache/Astrea/media-viewer/previews`

The cache key includes a preview version, path, size, and mtime.

## Shared UI
The app uses:
- `Apps/MediaViewer/AstreaComponents -> Core/components`

Keep viewer controls in this app unless they are generic enough for [[Astrea - Core Components]].

## Validation
- `python3 -m py_compile /home/agony/.local/share/Astrea/Apps/MediaViewer/media_viewer_helper.py`
- `python3 /home/agony/.local/share/Astrea/Apps/MediaViewer/media_viewer_helper.py open <image-or-directory>`
- `qs -p /home/agony/.local/share/Astrea/Apps/MediaViewer/shell.qml`
