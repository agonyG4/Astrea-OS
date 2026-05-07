# AstreaOS design-system standardization audit

## Scope

This pass reviewed the current design-token split and Settings UI consistency before any larger theme refactor. It intentionally avoids a risky global rewrite and favors additive compatibility tokens plus small shared-component cleanup.

Reviewed areas:

- `src/Quickshell/bar/Theme.qml`
- `src/Core/components/theme/Theme.qml`
- `src/Core/components/Theme.qml`
- app-local `Theme.qml` files under `src/Apps/**`
- Settings pages under `src/Apps/Settings/**`
- reusable Settings/Core form components under `src/Core/components/form/**`

## Theme architecture findings

### Current theme/token files

| File | Current responsibility | Notes |
| --- | --- | --- |
| `src/Core/components/theme/Theme.qml` | Persisted app UI theme state, Settings/app colors, typography, and now additive compatibility tokens for layout/motion/opacity. | Best candidate for the eventual global app design-token source because it already owns user theme persistence and is imported by Settings shared components. |
| `src/Core/components/Theme.qml` | Compatibility wrapper around `components/theme/Theme.qml`. | Keep this wrapper so existing imports do not break while token names are consolidated. |
| `src/Quickshell/bar/Theme.qml` | Shell/bar-specific colors, typography, spacing/radius/motion tokens, workspace values. | Should remain shell-local short term because the shell has different contrast, alpha, and layout constraints from app windows. Later it can alias a shared Core token module where values match. |
| `src/Apps/Explorer/Theme.qml` | Explorer-specific color palette. | Largely color-only and app-specific; can stay local until Explorer is migrated onto shared app colors. |
| `src/Apps/Weather/Theme.qml` | Weather-specific colors, font sizes, and card radius. | Contains one-off app typography and a larger `cardRadius: 18`; keep local until Weather receives a dedicated visual pass. |

### Duplicate/conflicting tokens to unify later

- **Font families:** Core uses `Inter`; Quickshell uses `Inter Variable`, `Inter Display`, and `Inter Regular`; several feature/app files still use literal `Inter` or Nerd Font strings. Recommendation: introduce `fontFamilyUi`, `fontFamilyDisplay`, `fontFamilyMono`, and `fontFamilyIcon` globally, then keep `fontFamily` as a compatibility alias.
- **Corner radii:** Quickshell standardizes around `6/8/10/12/14`; Core shared Settings controls now expose `8/10/12`; Weather uses `18`. Recommendation: globalize semantic tokens (`radiusSmall`, `controlRadius`, `cardRadius`, `radiusLarge`) and allow app-specific hero/media radius overrides.
- **Spacing:** Core/Settings pages use repeated `4/6/8/12/16/18/28`; Quickshell has a denser shell scale including `3/7/9/10/14/20`. Recommendation: globalize common page/control spacing in Core and keep shell-only micro offsets local.
- **Motion:** Common Settings values are `100/120/150/200/250/300`; Quickshell also has shell-specific pulse/spin values. Recommendation: globalize short interaction durations (`animationMicro`, `animationFast`, `animationNormal`, `animationSlow`) and keep long-running/status animation durations component-local unless reused.
- **Text sizes:** Core has app-window sizes (`9/10/11/12/13/15/16/20/22/24`); Quickshell bar uses compact shell sizes (`9/10/11/12/13/16/18`). Recommendation: keep separate app and shell typography scales for now, but align naming (`fontSizeBody`, `fontSizeCaption`, `fontSizeTitle`) through aliases.

### Safe migration path

1. Keep existing theme entry points and add compatibility aliases instead of renaming/removing tokens.
2. Migrate shared components first (`SettingRow`, `FormCard`, `ToggleSwitch`, `SelectButton`, etc.) so pages inherit consistency without many page edits.
3. Migrate Settings pages only where they duplicate shared component patterns.
4. After shared components and Settings pages settle, consider a read-only global token singleton that both Core and Quickshell can import for values that truly match.
5. Leave app-specific colors and hero component dimensions local until each app receives a dedicated visual QA pass.

## Settings UI consistency audit

### Highest priority safe fixes

1. **Replace custom toggles with the shared `ToggleSwitch` where behavior matches.**
   - `src/Apps/Settings/pages/display/Island.qml` and `src/Apps/Settings/pages/display/Display.qml` both define local switch visuals with the same `36x20` track and `14x14` thumb pattern already available in `src/Core/components/form/ToggleSwitch.qml`.
   - Safe path: replace visuals only when the click/toggle behavior can be preserved exactly.

2. **Use `FormCard` + `SettingRow` for option rows that already follow the standard label/control pattern.**
   - Some Settings pages define ad-hoc cards/rows with duplicated `radius: 12`, `spacing: 8/10/12`, and `duration: 150` values.
   - Safe path: migrate one page section at a time, starting with rows that have no custom drag/preview behavior.

3. **Standardize card and row radii through Core theme tokens.**
   - Shared form components now use `Theme.cardRadius`, `Theme.controlRadius`, and `Theme.cornerRadiusSmall`.
   - Safe path: update page-local `radius: 12/10/8` only where the component is clearly a normal card, control, or row hover background.

4. **Normalize section spacing through `ScrollPage`, `SectionHeader`, and shared spacing tokens.**
   - Settings pages mix `spacing: 4/6/8/10/12/14/16` and margins like `28` directly.
   - Safe path: prefer `ScrollPage.contentMargins`, `Theme.pageMargin`, and `Theme.spacing*` aliases instead of changing layout structure.

5. **Normalize labels/subtitles/disabled states.**
   - Shared rows use Core text colors, font sizes, and opacity tokens; some page-local labels use hardcoded `#ffffff`, inline alpha values, or custom font sizes.
   - Safe path: use Core text tokens (`textPrimary`, `textSecondary`, `opacityDisabled`, `opacitySecondary`) in local custom controls before replacing the controls themselves.

### Medium priority fixes

- Move recurring chip/button styles in personalization and display pages into small reusable components or extend `SelectButton` where behavior matches.
- Audit pages using direct icon font names and decide whether an explicit `fontFamilyIcon` token should replace literal Nerd Font strings.
- Align Settings page animation durations with Core motion tokens after the shared components are stable.

### Should remain local for now

- Preview canvases and monitor layout visuals in Display settings.
- Wallpaper/lockscreen preview-specific dimensions.
- App-specific status cards with unique data visualization needs.
- Long-running progress/spinner timings that communicate state rather than ordinary UI interaction.
