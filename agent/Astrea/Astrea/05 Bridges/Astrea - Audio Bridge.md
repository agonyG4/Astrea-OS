# Astrea - Audio Bridge

Related notes: [[Astrea - Core Bridge]], [[Astrea - Settings App]], [[Astrea - Island]], [[Astrea - Top Bar]]

## File
`Core/bridge/system/audio.py`

## Responsibility
Audio backend for Settings.

It provides:
- device information
- app audio information
- default sink changes
- app volume/mute changes
- sample rate/buffer configuration
- device aliases

## Consumers
- `Apps/Settings/pages/connectivity/Audio.qml`
- [[Astrea - Island]] indirectly for music bars through `music_bars_backend`
- [[Astrea - Top Bar]] uses `wpctl` directly for volume state

## Dependencies
- PipeWire/WirePlumber.
- `wpctl`.
- WirePlumber config under `~/.config/wireplumber`.
- `System/config/audio-aliases.json`.

## Related Native Backend
`Core/bridge/audio/music_bars_backend` is used by [[Astrea - Island]] through `System/services/music_bars.sh`.

