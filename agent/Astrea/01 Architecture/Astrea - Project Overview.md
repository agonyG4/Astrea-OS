# Astrea - Project Overview

Source analyzed: `/home/agony/.local/share/Astrea-Rolling`

Related notes: [[Astrea]], [[Astrea - Structure Breakdown]], [[Astrea - Entry Points]], [[Astrea - Data Flow]]

## Purpose
Astrea is a local desktop environment/runtime stack for Hyprland and Quickshell.

Live runtime path:
- `/home/agony/.local/share/Astrea`

Documentation vault:
- `/home/agony/GitHub/Astrea-Dev/agent/Astrea`
- `/home/agony/Documentos/Astrea`

Current path relationship:
- `/home/agony/.local/share/Astrea` resolves to `/home/agony/.local/share/Astrea-Rolling`

It provides:
- persistent shell surfaces
- standalone desktop apps
- shared QML UI components
- shared translation catalogs
- system configuration pages
- Polkit/authentication integration
- wallpaper and lockscreen features
- notification handling
- app launch routing and temporary latency burst
- network, Wi-Fi, DNS, WARP, Gamescope, Proton, and Windows-app compatibility controls
- command bridges to Linux desktop services

## Tech Stack
- QML / Qt Quick for UI.
- Quickshell for shell surfaces and standalone desktop windows.
- Python for bridge scripts and JSON-producing backends.
- Bash for system service wrappers.
- Rust native executables for Explorer, Weather, app launch, and music bars.
- Hyprland, PipeWire/WirePlumber, bluetoothctl, playerctl, systemd user units, DBus, gsettings, hyprsunset, and nvibrant.
- NetworkManager/nmcli, Cloudflare WARP when installed, Gamescope, Steam/Proton, Wine, umu, GameMode, MangoHud, XDG portals, ImageMagick, and ffmpeg are optional or domain-specific integrations.

## Architecture Style
Astrea is a modular desktop stack.

The main pattern is:
1. QML renders UI and owns interaction state.
2. Quickshell `Process` calls Python, Bash, or native backends.
3. Backends read system state, return JSON, or apply system changes.
4. QML parses stdout and updates properties/models.

Connected notes:
- [[Astrea - Quickshell Runtime]]
- [[Astrea - Settings App]]
- [[Astrea - Explorer App]]
- [[Astrea - Media Viewer App]]
- [[Astrea - Wallpapers App]]
- [[Astrea - Core Bridge]]
- [[Astrea - System Layer]]
