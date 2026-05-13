# Astrea - Project Overview

Source analyzed: `/home/agony/.local/share/Astrea`

Related notes: [[Astrea]], [[Astrea - Structure Breakdown]], [[Astrea - Entry Points]], [[Astrea - Data Flow]]

## Purpose
Astrea is a local desktop environment/runtime stack for Hyprland and Quickshell.

Live runtime path:
- `/home/agony/.local/share/Astrea`

Documentation vault:
- `/home/agony/Documentos/Astrea/Astrea`

It provides:
- persistent shell surfaces
- standalone desktop apps
- shared QML UI components
- system configuration pages
- wallpaper and lockscreen features
- notification handling
- command bridges to Linux desktop services

## Tech Stack
- QML / Qt Quick for UI.
- Quickshell for shell surfaces and standalone desktop windows.
- Python for bridge scripts and JSON-producing backends.
- Bash for system service wrappers.
- Native executables for Explorer and music bars.
- Hyprland, PipeWire/WirePlumber, bluetoothctl, playerctl, systemd user units, DBus, gsettings, hyprsunset, and nvibrant.

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
- [[Astrea - Core Bridge]]
- [[Astrea - System Layer]]
