# Astrea - Launcher and Latency

Related notes: [[Astrea]], [[Astrea - System Layer]], [[Astrea - Spotlight]], [[Astrea - Desktop Icons]], [[Astrea - Explorer App]]

## Folders
- `System/launch`
- `System/services`
- `bin`

## Responsibility
Astrea-owned app launching is centralized through `bin/astrea-launch`.

The launch stack provides:
- desktop ID launches
- shell command launches
- argv JSON launches
- file, URL, and Steam URI launches
- launch history
- optional temporary latency burst through `astrea-latencyd`

## CLI
`bin/astrea-launch` supports:
- `--desktop <desktop-id>`
- `--command <cmd>`
- `--argv-json '["program","arg"]'`
- `--file <path>`
- `--url <url>`
- `--steam <steam-uri>`
- `daemon`
- `doctor`
- `history`

## Daemons
`astrea-services.sh` installs:
- `astrea-launchd.service`
- `astrea-latencyd.service`

`astrea-launchd.service` must run under `graphical-session.target` so launched Qt/Quickshell children inherit the correct Wayland and Hyprland environment.

`astrea-latencyd.service` exposes:
- `/run/user/1000/Astrea/astrea-latencyd.sock`

`astrea-launchd.service` exposes:
- `/run/user/1000/Astrea/astrea-launchd.sock`

## Latency Burst
`System/services/astrea_latencyd.py` owns the burst lifecycle.

It snapshots before applying a burst, writes history under `~/.local/state/Astrea/latencyd`, and rolls back after the short launch window.

The narrow privileged helper path is:
- `/usr/local/libexec/astrea-latency-burst-helper`

The helper is installed from:
- `System/services/install-latency-burst-helper.sh`

## Consumers
- [[Astrea - Spotlight]]
- [[Astrea - Desktop Icons]]
- [[Astrea - Explorer App]]
- [[Astrea - Top Bar]] through `~/.local/bin/astrea-settings-open` for Settings placement on the active workspace
- `Core/bridge/apps/manager.py`
- island helper scripts that launch music/app actions

## Validation
- `bin/astrea-launch doctor`
- `bin/astrea-launch history`
- `System/services/astrea-services.sh doctor core`
- `cargo check --manifest-path System/launch/Cargo.toml`
- `python3 -m py_compile System/services/astrea_latencyd.py`
