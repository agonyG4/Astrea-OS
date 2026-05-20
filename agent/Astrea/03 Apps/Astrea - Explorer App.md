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
- Quick Look
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
When a folder is targeted from the context menu, Explorer should show a `Compress` action.

Hovering `Compress` opens a compact submenu with archive format choices:
- `ZIP`
- `RAR`
- `TAR`
- `TAR.GZ`
- `TAR.XZ`

The submenu should stay inside the existing Explorer context-menu wrapper around `AstreaFiles.FileContextMenu`; do not create a separate popup style for this action.

Each format action should route through `AppState` and `FileOperationsState`, then call the Explorer backend. The generated archive should appear beside the source folder unless the user chooses a destination in a future flow.

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
- Quick Look temp files under `/tmp/explorer-quicklook-*`

## External Dependency
Quick Look references `/home/agony/GitHub/Bench/Look/quicklook.qml`.

See [[Astrea - External Dependencies]].
