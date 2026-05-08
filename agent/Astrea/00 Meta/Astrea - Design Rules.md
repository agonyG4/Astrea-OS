# Astrea - Design Rules

Related notes: [[Astrea - AI Project Brain]], [[Astrea - Agent Working Rules]], [[Astrea - Core Components]], [[Astrea - Top Bar]]

## Purpose
This note captures Astrea's design rules for AI agents.

It is based on the live tree at `/home/agony/.local/share/Astrea`.

## Design Principle
Astrea is a desktop system UI.

It should feel clean, native, calm, and useful.

Prefer practical polish over decoration.

## Default Visual Direction
- professional, no fluff
- macOS-like clarity, Linux-native behavior
- translucent only where the existing surface already uses it
- compact controls
- readable density
- subtle hover and motion
- no marketing blocks
- no decorative redesign during functional work

## Theme Sources
Settings theme:
- `Core/components/theme/Theme.qml`

Settings pages should use:
- `Theme.accent`
- `Theme.textPrimary`
- `Theme.textSecondary`
- `Theme.cardBg`
- `Theme.cardBorder`
- `Theme.popupBg`
- `Theme.windowBackground`
- `Theme.windowWash`

Topbar and shell popup theme:
- `Quickshell/bar/Theme.qml`

Shell surfaces should use:
- `Theme.background`
- `Theme.surface`
- `Theme.border`
- `Theme.separator`
- `Theme.text*`
- `Theme.icon*`
- `Theme.radius*`

Do not invent popup-local colors when a `Theme.*` token already exists.

## Typography
Use the local theme font.

Settings currently uses:
- `Theme.fontFamily`
- `Theme.fontSize*`
- `Theme.fontWeight*`

Topbar currently uses:
- `Theme.fontFamily`
- `Theme.fontFamilyDisplay`
- `Theme.fontSize*`

Rules:
- keep text crisp and small
- use `Text.NativeRendering` when nearby text uses it
- keep letter spacing at `0` unless the existing component uses a label style
- avoid heavy outlines or decorative shadows on small text

## Settings Rules
Settings is a control panel, not a dashboard.

Use:
- `ScrollPage` for page containers
- `SectionHeader` for groups
- `FormCard` for grouped settings
- `SettingRow` for label + control rows
- `SelectButton` for choices
- `ToggleSwitch` for boolean settings

Keep:
- sidebar + content layout
- fixed app sizing behavior from `Apps/Settings/main.qml`
- scrollbar at the outer right edge through `ScrollPage`
- page content centered and constrained

Avoid:
- full-page decorative cards
- nested cards inside cards
- oversized hero typography
- changing app background from one page
- ad hoc controls when an exported component exists

## Explorer Rules
Explorer is file-work UI.

Use:
- `Apps/Explorer/Theme.qml` for Explorer colors
- `AstreaFiles.FileContextMenu` for menu frames
- `AstreaFiles.OperationProgressCard` for file progress
- `AppState` for app workflow calls

Keep:
- Finder-like directness
- compact menus
- visible file-operation progress in the file area
- file actions routed through backend/state ownership

Avoid:
- generic modals for file-menu flows
- duplicating the shared context menu frame
- changing file hover or drag visuals while adding unrelated actions

## Weather Rules
Weather is a compact visual app.

Use:
- existing section components
- current `Theme.qml`
- bottom sheets for details
- `WeatherState` and the Weather bridge for data

Keep:
- current summary first
- alerts as summary then details
- long alert text scrollable
- refresh/data logic outside visual sections

## Shell Rules
Topbar, island, spotlight, and notifications are resident shell surfaces.

Use the existing resident component pattern.

For topbar:
- keep left/right visual groups separate unless the user asks to merge them
- use `TopbarPopup` for popup shape and placement
- use shell `Theme.*` tokens

For island:
- make geometry changes tiny
- preserve compact/expanded lifecycle behavior
- keep music bars as bars unless the user asks otherwise

For Control Center:
- use theme-driven colors
- keep detached accessories detached
- do not put customization controls inside the main card unless asked

## Motion
Motion should be subtle and functional.

Good motion:
- hover fade
- short scale feedback
- smooth width/height changes
- restrained popup transitions
- music bars that feel alive

Avoid:
- animation that changes layout boundaries unexpectedly
- motion refactors during bug fixes
- broad easing changes across unrelated components

## Visual Change Checklist
Before editing:
1. inspect the target component
2. find the local theme source
3. identify the nearest matching existing pattern
4. decide whether the task is functional or visual

After editing:
1. run `qmllint` on touched QML
2. smoke the app or shell entry when practical
3. make rollback obvious if the change is experimental
