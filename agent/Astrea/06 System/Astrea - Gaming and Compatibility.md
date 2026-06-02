# Astrea - Gaming and Compatibility

Related notes: [[Astrea - Settings App]], [[Astrea - System Layer]], [[Astrea - Launcher and Latency]], [[Astrea - External Dependencies]]

## Responsibility
Gaming and compatibility paths configure Gamescope sessions, Proton launch flags, and Windows `.exe` or `.msi` execution.

## Settings Pages
- `Apps/Settings/pages/gaming/Gamescope.qml`
- `Apps/Settings/pages/gaming/Proton.qml`
- `Apps/Settings/pages/gaming/Compatibility.qml`

All three pages call:
- `System/scripts/astrea-gaming-settings`

## Config Files
- `~/.config/AstreaOS/gaming/gamescope.json`
- `~/.config/AstreaOS/gaming/proton.json`
- `~/.config/AstreaOS/gaming/compatibility.json`
- `~/.config/environment.d/gamescope-session-plus.conf`

## Generated Launchers
- `~/.local/bin/astrea-gamescope-session`
- `/home/agony/.local/share/Astrea/bin/astrea-gamescope-session`
- `/home/agony/.local/share/Astrea/bin/astrea-gaming`

The Settings helper writes the local-bin Gamescope launcher and environment file. The runtime also ships app-facing wrappers under `bin/`.

## Gamescope Contract
Gamescope settings include:
- follow focused monitor
- width, height, refresh
- fullscreen
- Steam integration
- DRM backend
- immediate flips
- cursor hiding
- fancy scaling
- color management
- virtual white
- multiple XWaylands
- HDR
- output connector
- extra args

Saving Gamescope settings regenerates the command used for Steam gamepad UI.

## Proton Contract
Proton settings include:
- preset: recommended, nvidia, hdr, diagnostic, or custom
- GameMode and MangoHud
- optional Gamescope wrapper
- optional shared Gamescope profile
- NVAPI and NVIDIA visibility flags
- Esync/Fsync mode
- DXVK async/HDR
- VKD3D DXR
- WineD3D
- Wine FSR
- custom environment and command prefix

`bin/astrea-gaming` reads `~/.config/AstreaOS/gaming/proton.json` and prepends the configured environment/prefix to the launched command.

## Windows Runner
`System/scripts/astrea-windows-run` supports:
- `.exe`
- `.msi`

It reads Compatibility and Proton settings, then chooses Proton, Wine, or auto mode. Proton candidates include Steam compatibility tools and CachyOS Proton. It uses a shared prefix under:
- `~/.local/share/AstreaOS/windows-prefixes/shared/proton`

Logs go under:
- `~/.local/state/AstreaOS/windows-prefixes/logs`

## External Dependencies
Optional tools:
- `gamescope`
- `steam`
- `gamemoderun`
- `mangohud`
- Proton-GE or other Steam compatibility tools
- `umu-run`
- `wine`

Do not make Settings crash if one optional tool is absent. Report capability/status through the helper payload and keep the saved config intact.

## Validation
- `python3 -m py_compile /home/agony/.local/share/Astrea/System/scripts/astrea-gaming-settings`
- `python3 -m py_compile /home/agony/.local/share/Astrea/System/scripts/astrea-windows-run`
- `/home/agony/.local/share/Astrea/System/scripts/astrea-gaming-settings get`
- `/home/agony/.local/share/Astrea/System/scripts/astrea-gaming-settings apply`
- `/home/agony/.local/share/Astrea/System/scripts/astrea-windows-run --dry-run --json <file.exe>`
