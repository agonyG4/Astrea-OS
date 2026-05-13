# Astrea - External Dependencies

Related notes: [[Astrea]], [[Astrea - Explorer App]], [[Astrea - Settings App]], [[Astrea - Unknowns]]

## External Project Paths
Observed dependencies outside `/home/agony/.local/share/Astrea`:

- `/home/agony/GitHub/Bench/Look/quicklook.qml`
  - referenced by [[Astrea - Explorer App]] Quick Look.

- `/home/agony/GitHub/Bench/StorageSense/sense.py`
  - optional StorageSense scanner source used by `Core/bridge/system/storage.py` when present.
  - the bridge should also support bundled or alternate scanner locations and a JSON cache fallback.
  - consumed by [[Astrea - Settings App]] Storage page.

## External Config and State
- `~/.config/AstreaOS`
- `~/.local/state/Astrea`
- `~/.local/state/Astrea/weather/settings.json`
- `~/.local/state/Astrea/weather/alerts-seen.json`
- `~/.local/state/Astrea/weather/current.json`
- `~/.cache/weather`
- `~/.config/wireplumber`
- `~/.config/hypr`
- `~/.config/xdg-desktop-portal`
- `~/.local/share/xdg-desktop-portal/portals/astrea.portal`
- `~/.local/share/dbus-1/services/org.freedesktop.Notifications.service`
- `~/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.astrea.service`
- `/tmp/explorer-quicklook-*`

## External System Services and Commands
- Hyprland / `hyprctl`
- PipeWire/WirePlumber / `wpctl`
- Bluetooth / `bluetoothctl`
- DBus / `gdbus`
- XDG Desktop Portal / `xdg-desktop-portal`
- systemd user units
- `playerctl`
- `notify-send`
- `gsettings`
- `hyprsunset`
- `nvibrant`

## Risk Boundary
Astrea is not fully self-contained because some runtime paths point to Bench project files.
