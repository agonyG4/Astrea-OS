# Astrea - Display Bridge

Related notes: [[Astrea - Core Bridge]], [[Astrea - Settings App]], [[Astrea - System Layer]]

## File
`Core/bridge/system/display.py`

## Responsibility
Display backend for Settings.

It reads monitor information and saved display configuration.

`saturation` is stored as a percentage from `0` to `100`.
Legacy raw `nvibrant` values from `0` to `1023` are converted when read.

## Consumer
`Apps/Settings/pages/display/Display.qml`

## Inputs
- `hyprctl monitors -j`
- `System/config/display/monitor-settings.conf`

## Apply Path
Settings calls:
- `System/services/display_apply.sh`

That script:
- writes Hyprland monitor config
- optionally applies monitor settings immediately
- reloads Hyprland
- applies night shift state/schedule
- converts saturation percentage to the `nvibrant` raw range and applies it

## Dependencies
- Hyprland.
- `hyprctl`.
- `hyprsunset`.
- `nvibrant`.
- systemd user timers for night shift.
