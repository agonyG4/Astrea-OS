# Astrea - Explorer Backend

Related notes: [[Astrea - Explorer App]], [[Astrea - Core Bridge]], [[Astrea - Unknowns]]

## File
Primary helper:
- `Apps/Explorer/explorer_helper.py`

Native listing/backend paths may still exist for heavier Explorer operations, but archive extraction, folder compression, Open With, trash restore, and several shell integration commands are handled by the Python helper.

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
Implemented command shape:
- `compress-folder <path> <format>`

Supported formats should include:
- `zip`
- `rar`
- `tar`
- `tar.gz`
- `tar.xz`

Behavior:
- creates the archive beside the source folder
- uses a unique destination name when the default archive path already exists
- preserves the source folder
- emits JSON `start`, `progress`, `done`, and `error` events for the file-operation surface
- returns a clear unsupported-tool error when an external compressor is missing

`rar` support is optional because it depends on the system package. The QML side should only expose it as enabled when the backend reports support or when the command can resolve the required tool.

## Future Preview Work
Quick Look is disabled in the current Explorer runtime.

There is no active quicklook helper command or override contract. Reintroducing this should be treated as a future feature with new UI, helper, and smoke coverage.
