# Astrea - External Dependencies

Related notes: [[Astrea]], [[Astrea - Explorer App]], [[Astrea - Settings App]], [[Astrea - Unknowns]]

## External Project Paths
Observed dependencies outside `/home/agony/.local/share/Astrea`:

- `/home/agony/GitHub/Bench/StorageSense/sense.py`
  - optional StorageSense scanner source used by `Core/bridge/system/storage.py` when present.
  - the bridge should also support bundled or alternate scanner locations and a JSON cache fallback.
  - consumed by [[Astrea - Settings App]] Storage page.

Explorer Quick Look is disabled and should not depend on an external Bench checkout.

## External Config and State
- `~/.config/AstreaOS`
- `~/.local/state/Astrea`
- `~/.local/state/Astrea/launch/history.jsonl`
- `~/.local/state/Astrea/latencyd/history.jsonl`
- `~/.local/state/Astrea/weather/settings.json`
- `~/.local/state/Astrea/weather/alerts-seen.json`
- `~/.local/state/Astrea/weather/current.json`
- `~/.config/AstreaOS/ui/components.json`
- `~/.config/AstreaOS/gaming/gamescope.json`
- `~/.config/AstreaOS/gaming/proton.json`
- `~/.config/AstreaOS/gaming/compatibility.json`
- `~/.config/environment.d/gamescope-session-plus.conf`
- `~/.local/share/AstreaOS/user/wallpapers`
- `~/.local/share/AstreaOS/windows-prefixes/shared/proton`
- `~/.local/state/AstreaOS/windows-prefixes/logs`
- `~/.cache/weather`
- `~/.config/wireplumber`
- `~/.config/hypr`
- `~/.config/xdg-desktop-portal`
- `~/.local/share/xdg-desktop-portal/portals/astrea.portal`
- `~/.local/share/dbus-1/services/org.freedesktop.Notifications.service`
- `~/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.astrea.service`
- `~/.cache/Astrea/media-viewer/previews`
- `/run/user/1000/Astrea/astrea-launchd.sock`
- `/run/user/1000/Astrea/astrea-latencyd.sock`
- `$XDG_RUNTIME_DIR/Astrea/sessiond.sock`
- `/usr/local/libexec/astrea-latency-burst-helper`

## External System Services and Commands
- Hyprland / `hyprctl`
- PipeWire/WirePlumber / `wpctl`
- Bluetooth / `bluetoothctl`
- DBus / `gdbus`
- XDG Desktop Portal / `xdg-desktop-portal`
- NetworkManager / `nmcli`
- Cloudflare WARP / `warp-cli`
- systemd user units
- Cargo for rebuilding Rust helpers
- `gio` for desktop launch fallback through `astrea-launch`
- `playerctl`
- `notify-send`
- `gsettings`
- `hyprsunset`
- `nvibrant`
- ImageMagick `magick` or `convert`
- `ffmpeg`
- Python GI / GTK / Polkit bindings
- Gamescope
- Steam / Proton compatibility tools
- Wine
- umu
- GameMode
- MangoHud

## Risk Boundary
Astrea is not fully self-contained because StorageSense can still use an optional Bench scanner source, launch burst behavior depends on a privileged helper outside the runtime tree, and gaming/network integrations depend on optional host tools.
