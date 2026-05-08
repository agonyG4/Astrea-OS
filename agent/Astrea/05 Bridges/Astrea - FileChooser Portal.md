# Astrea - FileChooser Portal

Related notes: [[Astrea - Explorer App]], [[Astrea - System Layer]], [[Astrea - External Dependencies]]

## Folder
`System/portal/`

## Responsibility
Astrea provides an XDG Desktop Portal FileChooser backend that opens the Explorer/Finder dialog.

The portal owns system file-picker integration.

Explorer owns the visible dialog UI.

## Main Files
- `System/portal/astrea_filechooser_portal.py`
- `Apps/Explorer/PortalDialog.qml`
- `Apps/Explorer/FileDialog.qml`

## DBus
Portal implementation bus name:
- `org.freedesktop.impl.portal.desktop.astrea`

Object path:
- `/org/freedesktop/portal/desktop`

Interface:
- `org.freedesktop.impl.portal.FileChooser`

## Registration
Portal descriptor:
- `~/.local/share/xdg-desktop-portal/portals/astrea.portal`

DBus service:
- `~/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.astrea.service`

Optional user unit:
- `~/.config/systemd/user/astrea-filechooser-portal.service`

Portal preference:
- `~/.config/xdg-desktop-portal/hyprland-portals.conf`
- `~/.config/xdg-desktop-portal/portals.conf`

Both should prefer:
- `org.freedesktop.impl.portal.FileChooser=astrea;gtk`

## Dialog Contract
The portal backend launches:
- `/home/agony/.local/share/Astrea/Apps/Explorer/PortalDialog.qml`

Environment inputs:
- `ASTREA_FILE_DIALOG_OPTIONS`
- `ASTREA_FILE_DIALOG_RESULT_FILE`

Compatibility inputs still accepted:
- `BENCH_FILE_DIALOG_OPTIONS`
- `BENCH_FILE_DIALOG_RESULT_FILE`

Stdout result prefix:
- `__ASTREA_FILE_DIALOG__`

Compatibility prefix still emitted:
- `__BENCH_FILE_DIALOG__`

## Modes
The portal maps FileChooser requests to Explorer dialog modes:
- `OpenFile` -> `open_file`
- `OpenFile` with `directory=true` -> `select_folder`
- `SaveFile` -> `save_file`
- `SaveFiles` -> `select_folder`

## Validation
- `python3 -m py_compile /home/agony/.local/share/Astrea/System/portal/astrea_filechooser_portal.py`
- `bash /home/agony/.local/share/Astrea/System/services/astrea-services.sh verify`
- `gdbus introspect --session --dest org.freedesktop.impl.portal.desktop.astrea --object-path /org/freedesktop/portal/desktop`
- `journalctl --user -u xdg-desktop-portal.service`

If apps still show GTK dialogs after the portal is selected, verify whether that app actually uses the FileChooser portal.
