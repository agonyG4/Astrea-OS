# Astrea - System Layer

Related notes: [[Astrea]], [[Astrea - Core Bridge]], [[Astrea - Display Bridge]], [[Astrea - Bluetooth Manager]]

## Folder
`System/`

## Responsibility
Local system integration.

It contains:
- auth helper
- config files
- portal backend
- service scripts
- cache files
- metadata
- helper scripts

## Important Files
- `System/auth/auth_helper`
- `System/auth/auth_helper.c`
- `System/config/audio-aliases.json`
- `System/config/display/monitor-settings.conf`
- `System/portal/astrea_filechooser_portal.py`
- `System/services/display_apply.sh`
- `System/services/display_night_shift_color.sh`
- `System/services/display_night_shift_schedule.sh`
- `System/services/music_bars.sh`
- `System/services/astrea_statusd.py`
- `Apps/Weather/backend/target/release/astrea-weatherd`
- `System/services/astrea-services.sh`
- `System/services/theme/apply_color_scheme.sh`
- `System/services/theme/apply_decoration_style.sh`
- `System/scripts/bluetooth_manager.py`

Hyprland starts display settings from
`~/.config/hypr/system/autostart.conf`.
That file runs `System/services/display_apply.sh`, so the saved saturation
percentage is restored when the session starts.

## User Services
`astrea-services.sh` installs user services.

`astrea-status.service` runs `System/services/astrea_statusd.py`.
It owns low-frequency system status polling for shell UI:
- audio
- network
- Bluetooth status
- Bluetooth autoconnect

It writes stable JSON under `~/.local/state/Astrea/status`.
It should only rewrite files when semantic state changes.
Quickshell may request an immediate refresh with `SIGUSR1`.

The daemon should sleep until the next scheduled refresh instead of waking on a fixed short interval. The sleep is capped so manual refreshes remain responsive.

`astrea-weatherd.service` runs `Apps/Weather/backend/target/release/astrea-weatherd`.
It owns Weather refresh monitoring and desktop notifications independently from
the Weather QML app.

## External System Tools
Observed dependencies:
- `hyprctl`
- `hyprsunset`
- `nvibrant`
- `systemctl --user`
- `wpctl`
- `ip`
- `nmcli`
- `bluetoothctl`
- `gsettings`
- `jq`
- `gdbus`
- `xdg-desktop-portal`

## Security Boundary
`System/auth/auth_helper` is setuid and has source at `System/auth/auth_helper.c`.

Its behavior was not audited in this pass.
