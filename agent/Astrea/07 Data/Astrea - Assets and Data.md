# Astrea - Assets and Data

Related notes: [[Astrea]], [[Astrea - Weather App]], [[Astrea - Settings App]], [[Astrea - Features]]

## Assets
Folder: `Assets/`

Role:
- static visual assets used by apps and shell components.

Observed assets:
- `Assets/icons/display`
- `Assets/icons/settings`
- `Assets/images/brand/astrea-logo.png`
- `Assets/images/weather/backgrounds/cloudy.mp4`
- `Assets/ui/quickshell/bar/astrea.png`
- `Assets/ui/quickshell/island/*`
- `Apps/Weather/assets/icons/weather/*`
- `audio/hrir.wav`

## Data
Folder: `Data/`

Role:
- Astrea-owned user data inside the runtime tree.

Observed data:
- `Data/user/wallpapers/Persona_3`
- `Data/user/wallpapers/Persona_5`

Current wallpaper user data has moved toward:
- `~/.local/share/AstreaOS/user/wallpapers`

The wallpaper bridge can migrate legacy user wallpapers from the runtime tree.

## Related External State
Astrea also stores state/config outside this tree:
- `~/.config/AstreaOS`
- `~/.local/state/Astrea`
- `~/.local/state/Astrea/weather/settings.json`
- `~/.local/state/Astrea/weather/current.json`
- `~/.local/state/Astrea/weather/alerts-seen.json`
- `~/.local/state/Astrea/sessiond-status.json`
- `~/.cache/Astrea/media-viewer/previews`
- `~/.cache/weather`

See [[Astrea - Data Flow]] and [[Astrea - Unknowns]].
