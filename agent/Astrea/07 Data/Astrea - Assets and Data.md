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
- `audio/astrea_sidefix_7p1_16ch_50ms_safe_-10dB.wav`

## Audio Assets
`audio/hrir.wav` is the canonical packaged Astrea Spatial Audio HRIR.

Current format:
- 48 kHz
- 16 channels
- 50 ms
- 7.1 layout represented as 8 speaker positions times 2 ears

The named sidefix file is kept beside it as a provenance/readability copy. Runtime PipeWire config should point to `/home/agony/.local/share/Astrea/audio/hrir.wav`.

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
