# Astrea - I18n

Related notes: [[Astrea - System Layer]], [[Astrea - Settings App]], [[Astrea - Polkit Auth]]

## Folder
`System/i18n/`

## Files
- `System/i18n/I18n.qml`
- `System/i18n/i18n.py`
- `System/i18n/en_US.json`
- `System/i18n/pt_BR.json`
- `System/i18n/qmldir`
- `System/i18n/validate_i18n.py`
- `System/i18n/test_i18n.py`

## Responsibility
Astrea's shared translation layer.

Default language:
- `en_US`

Current catalogs:
- `en_US`
- `pt_BR`

## Python Helper
`i18n.py` supports:
- `dump`
- `tr <key> [fallback] --params <json>`
- `list-languages`

It reads language settings from:
- `~/.config/AstreaOS/system/settings.json`
- `~/.config/AstreaOS/system/system.json`

Recognized keys include:
- `language`
- `locale`
- `ui_language`
- `lang`

`dump` returns the active strings plus the fallback catalog. QML merges fallback first, then active strings.

## QML Module
`System/i18n/qmldir` declares:
- `module AstreaI18n`
- `singleton I18n 1.0 I18n.qml`

Observed symlinks:
- `Apps/About/AstreaI18n -> ../../System/i18n`
- `Apps/Explorer/AstreaI18n -> ../../System/i18n`
- `Apps/Settings/AstreaI18n -> ../../System/i18n`
- `Apps/Weather/AstreaI18n -> ../../System/i18n`
- `Core/components/AstreaI18n -> ../../System/i18n`
- `Quickshell/AstreaI18n -> ../System/i18n`
- `Features/Paper/lockscreen/AstreaI18n -> ../../../System/i18n`

Add a local symlink for new apps instead of importing the system folder through fragile absolute paths.

## Rules
- Add keys to `en_US.json` first.
- Keep `pt_BR.json` in sync for visible UI.
- Use `I18n.tr(key, fallback, params)` in QML.
- Do not put large app-local language maps in QML.

## Validation
- `python3 /home/agony/.local/share/Astrea/System/i18n/validate_i18n.py`
- `python3 /home/agony/.local/share/Astrea/System/i18n/test_i18n.py`
- `python3 /home/agony/.local/share/Astrea/System/i18n/i18n.py dump`
- `python3 /home/agony/.local/share/Astrea/System/i18n/i18n.py list-languages`
