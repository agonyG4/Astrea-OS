# Bench ScreenTime

Focused-app usage tracker for Hyprland.

It samples the active window with `hyprctl activewindow -j`, groups apps through `app_rules.json`, and writes usage state outside the repo:

```text
~/.local/state/Bench/ScreenTime/usage.json
~/.local/state/Bench/ScreenTime/events.jsonl
```

## Run

```bash
./screentime.py monitor
```

The monitor uses a lock file so only one collector writes state at a time. It reloads `app_rules.json` while running, records collector health in `usage.json`, and splits samples across midnight instead of assigning the whole sample to the current day.

Print the current summary:

```bash
./screentime.py report
./screentime.py report --day 2026-05-01
./screentime.py snapshot --json
```

Show the state/config paths:

```bash
./screentime.py path
```

Reset collected data:

```bash
./screentime.py reset
```

## Categories

Edit `app_rules.json` to change the logic. It is intentionally separate from the monitor code.

Current examples:

```text
steam -> games
brave, zen, firefox, chrome -> browser
```

Matching is based on the focused window class first, with title matching as a fallback.

## Optional user service

```bash
mkdir -p ~/.config/systemd/user
ln -sf ~/GitHub/Bench/ScreenTime/bench-screentime.service ~/.config/systemd/user/bench-screentime.service
systemctl --user import-environment HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
systemctl --user daemon-reload
systemctl --user enable --now bench-screentime.service
```

The script also tries to discover the current Hyprland socket under `/run/user/$UID/hypr` if the service environment is incomplete.

## UI

```bash
QML_XHR_ALLOW_FILE_READ=1 quickshell -p ScreenTimeApp.qml
```

The UI refreshes the JSON snapshot every five seconds and follows the same compact card style used by the Astrea Weather app.
