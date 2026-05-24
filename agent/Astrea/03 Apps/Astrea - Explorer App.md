# Astrea - Explorer App

Related notes: [[Astrea]], [[Astrea - Explorer Backend]], [[Astrea - Features]], [[Astrea - External Dependencies]], [[Astrea - Launcher and Latency]]

## Folder
`Apps/Explorer/`

## Main Entry
`Apps/Explorer/Main.qml`

Portal entry:
- `Apps/Explorer/PortalDialog.qml`

## Responsibility
Explorer is a Finder-like file manager.

It handles:
- folder navigation
- tabs
- list/icon views
- preview panel
- selection
- clipboard actions
- drag/drop
- archive extraction
- folder compression
- trash operations
- AppImage install action
- device listing/mounting
- network browsing
- recents
- portal mode

## Central State
`AppState.qml` is a singleton facade.

It exposes aliases and wrapper functions for:
- `NavigationState`
- `SelectionState`
- `FileOperationsState`
- `PreviewState`
- `DeviceNetworkState`
- `RecentState`

## Backend
Explorer calls [[Astrea - Explorer Backend]] through `app.backendPath`.

## Launching
Explorer keeps an `astreaLaunch` path pointed at `bin/astrea-launch`.

Use that launcher path for app/file launch behavior owned by Astrea so Explorer stays aligned with Spotlight, Desktop Icons, and launcher history.

## AppImage Install
When a `.AppImage` file is targeted from the context menu, Explorer shows an `Install` action.

The action is exposed through `AppState.installAppImage(path)` and handled by `FileOperationsState`.

## Folder Compression
Folder compression is implemented. When a folder is targeted from the context menu, Explorer shows a `Compress` action.

Hovering `Compress` opens a compact submenu with archive format choices:
- `ZIP`
- `RAR`
- `TAR`
- `TAR.GZ`
- `TAR.XZ`

The submenu should stay inside the existing Explorer context-menu wrapper around `AstreaFiles.FileContextMenu`; do not create a separate popup style for this action.

Each format action routes through `AppState` and `FileOperationsState`, then calls the Explorer helper/backend command. The generated archive appears beside the source folder, using a unique name when an archive with the default name already exists.

Format support should be availability-aware:
- `ZIP` and `TAR` are baseline options.
- `RAR` should be disabled or hidden if the backend cannot find a compatible `rar` tool.
- compressed tar variants should use the system tools already available to the backend.

Compression progress should reuse the same visible file-operation progress surface used by copy, move, and extraction.

## UI Components
- `components/common`
- `components/layout`
- `components/views`
- shared file UI from [[Astrea - Features]]

## Shared File Module Import
Explorer uses a local module link:
- `Apps/Explorer/AstreaFiles -> Features/Files`

The app imports this link with relative paths instead of scanning the shared module through absolute imports.

`Features/Files/ui/SidebarFrame.qml` uses a stable `Core/components/navigation` import so the feature can be consumed through that local link.

## Portal Integration
Explorer provides the visible dialog for [[Astrea - FileChooser Portal]].

`PortalDialog.qml` wraps `FileDialog.qml` and reads:
- `ASTREA_FILE_DIALOG_OPTIONS`
- `ASTREA_FILE_DIALOG_RESULT_FILE`

It still accepts the older `BENCH_*` variables for compatibility.

The portal backend lives in:
- `System/portal/astrea_filechooser_portal.py`

## Persistent State
- Qt `Settings` at `/home/agony/.config/explorer.conf`
- recents at `~/.local/state/Astrea/finder-recents.json`

## Future Preview Work
Quick Look is not an active Astrea feature in the current runtime.

It was removed from the Explorer shortcut/helper path because the current implementation is unreliable. Treat it as future work, not as shipped behavior. Do not wire Space, `explorer_helper.py quicklook`, or external Bench QML back into Explorer without a fresh design and validation pass.

For current image browsing, use [[Astrea - Media Viewer App]] directly.

See [[Astrea - External Dependencies]].
