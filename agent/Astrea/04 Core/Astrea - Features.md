# Astrea - Features

Related notes: [[Astrea]], [[Astrea - Explorer App]], [[Astrea - Wallpaper Bridge]]

## Folder
`Features/`

## Responsibility
Reusable domain modules that are not standalone apps.

## Files Feature
Folder: `Features/Files/`

Provides:
- file context menu wrapper
- file operation progress wrapper
- sidebar frame
- drag/drop support

Public exports are declared in:
- `Features/Files/qmldir`

Current exports:
- `FileContextMenu`
- `ContextMenuAction`
- `ContextMenuDivider`
- `SidebarFrame`
- `OperationProgressCard`

`ContextMenuAction`, `ContextMenuDivider`, and `OperationProgressCard` are compatibility exports that delegate their visual implementation to [[Astrea - Core Components]]. New non-file-specific menu or progress UI should be added to `Core/components`, not `Features/Files`.

Because `AstreaFiles` is consumed through local symlinks in Explorer and Desktop Icons, these wrappers use stable absolute `file:/home/agony/.local/share/Astrea/Core/...` imports when crossing from `Features/Files` back into Core. Relative imports from inside a symlinked module can resolve against the consuming app path instead of the canonical feature path.

Consumed by:
- [[Astrea - Explorer App]]
- [[Astrea - Desktop Icons]]

Explorer consumes this module through:
- `Apps/Explorer/AstreaFiles -> Features/Files`

This keeps shared file UI reusable without using brittle app-local absolute imports.

### File Context Menu Rule
`Features/Files/ui/FileContextMenu.qml` is the Files-domain menu entrypoint.

The generic menu frame lives in `Core/components/menu/ContextMenu.qml` and owns:
- overlay fill
- open/close state
- positioning
- backdrop close
- escape handling
- frame color, border, radius, and padding

Apps should not copy that frame.

Apps should wrap it and add app-specific actions inside it.

For Explorer, action logic belongs in the app wrapper and should call `AppState` or the backend instead of bypassing the established file-operation flow.

Folder compression belongs in that Explorer wrapper as a folder-only action. The `Compress` row may open a hover submenu for `ZIP`, `RAR`, `TAR`, `TAR.GZ`, and `TAR.XZ`, but the frame, colors, padding, and close behavior should still come from the shared context-menu components.

Desktop Icons uses the same shared menu frame/actions so the desktop overlay does not carry a second context-menu style.

### Operation Progress Rule
Generic progress-card visuals live in `Core/components/feedback/ProgressCard.qml`.

`Features/Files/ui/OperationProgressCard.qml` wraps that Core component so file-operation surfaces can continue to consume `AstreaFiles.OperationProgressCard`.

Explorer should keep extraction/copy/move state in `AppState` and file-operation state objects, then bind that state into the shared card.

## Paper Feature
Folder: `Features/Paper/`

Provides:
- wallpaper libraries
- lockscreen QML
- paper/lockscreen assets

Consumed by:
- [[Astrea - Settings App]]
- [[Astrea - Wallpaper Bridge]]
- lockscreen runtime paths

## Unknown
There are multiple lockscreen paths:
- `Features/Paper/app/lockscreen/lockscreen.qml`
- `Features/Paper/lockscreen/Lockscreen.qml`
- `Features/Paper/lockscreen/lockscreen.qml`

It is unclear which are active and which are legacy.
