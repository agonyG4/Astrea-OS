# Astrea - Explorer Backend

Related notes: [[Astrea - Explorer App]], [[Astrea - Core Bridge]], [[Astrea - Unknowns]]

## File
`Core/bridge/apps/explorer_backend`

## Responsibility
Native backend used by Explorer.

Responsibilities were inferred from QML command usage:
- directory listing
- search
- device listing
- mount
- unmount
- remount
- preview metadata
- thumbnail warmup
- file operations
- archive extraction
- folder compression
- AppImage installation

## Consumers
- `Apps/Explorer/state/NavigationState.qml`
- `Apps/Explorer/state/DeviceNetworkState.qml`
- `Apps/Explorer/state/FileOperationsState.qml`
- `Apps/Explorer/state/PreviewState.qml`

## AppImage Install
Command: `install-appimage <path>`

Behavior:
- copies the selected `.AppImage` to `~/.local/bin/`
- makes the copied file executable
- writes a `.desktop` launcher to `~/.local/share/applications/`

## Folder Compression
Expected command shape:
- `compress-folder <path> <format>`

Supported formats should include:
- `zip`
- `rar`
- `tar`
- `tar.gz`
- `tar.xz`

Behavior:
- creates the archive beside the source folder
- preserves the source folder
- reports progress through the same file-operation channel used by extraction, copy, and move
- returns a clear unsupported-tool error when an external compressor is missing

`rar` support is optional because it depends on the system package. The QML side should only expose it as enabled when the backend reports support or when the command can resolve the required tool.

## Unknown
The executable is compiled. Internal implementation was not inspected in this pass.
