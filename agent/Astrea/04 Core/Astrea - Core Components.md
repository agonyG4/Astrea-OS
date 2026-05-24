# Astrea - Core Components

Related notes: [[Astrea]], [[Astrea - Settings App]], [[Astrea - Patterns]]

## Folder
`Core/components/`

## Responsibility
Shared QML component library.

It is used by Settings and several standalone apps.

Observed local links:
- `Apps/Settings/AstreaComponents -> Core/components`
- `Apps/Explorer/AstreaComponents -> Core/components`
- `Apps/MediaViewer/AstreaComponents -> Core/components`
- `Apps/Wallpapers/AstreaComponents -> Core/components`
- `Apps/Weather/AstreaComponents -> Core/components`

Prefer app-local links instead of direct absolute imports.

## Module
`Core/components/qmldir` declares module `components`.

Exposed areas include:
- theme
- navigation
- sidebar
- text labels
- form controls
- menu controls
- feedback/status cards
- sidebar
- scroll page
- toggle switch
- setting row
- reusable cards
- reorderable stacks

When adding a shared control:
1. put the implementation in the appropriate component area
2. export it from `Core/components/qmldir`
3. consume it through the app's local module link
4. avoid changing existing controls for an app-only need

## Shared Menu Components
Generic menu visuals live under:
- `Core/components/menu/ContextMenu.qml`
- `Core/components/menu/ContextMenuAction.qml`
- `Core/components/menu/ContextMenuDivider.qml`

They are exported at the module root as:
- `ContextMenu`
- `ContextMenuAction`
- `ContextMenuDivider`

Domain modules can wrap these controls, but should not copy their styling. For example, `Features/Files` keeps compatibility wrappers while delegating the visual implementation to Core.

## Shared Feedback Components
Generic progress feedback lives under:
- `Core/components/feedback/ProgressCard.qml`

It is exported as:
- `ProgressCard`

Domain modules can wrap it with semantic names, such as `Features/Files.OperationProgressCard`, while keeping operation state and placement in the consuming app.

## Shared Text Components
Generic text and separator visuals live under:
- `Core/components/typography/TextLabel.qml`
- `Core/components/typography/DisplayLabel.qml`
- `Core/components/typography/Divider.qml`

They are exported at the module root as:
- `TextLabel`
- `DisplayLabel`
- `Divider`

Apps should consume these through their local `AstreaComponents` link instead of keeping app-local label or divider styling.

## Theme
`Core/components/theme/Theme.qml` is the singleton theme source.

It reads:
- `~/.config/AstreaOS/ui/theme.json`

It references:
- `System/services/apply_theme_decoration.sh`
- theme/application side effects from Settings and System service paths

## Unknown
Top-level component files are compatibility/public-entry wrappers for categorized implementations. New generic components should keep the implementation in a subfolder and expose a small root wrapper through `qmldir`.
