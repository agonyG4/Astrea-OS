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
- Astrea Spatial Audio state and target routing

## Consumers
- `Apps/Settings/pages/connectivity/Audio.qml`
- [[Astrea - Island]] indirectly for music bars through `music_bars_backend`
- [[Astrea - Top Bar]] uses `wpctl` directly for volume state

## Dependencies
- PipeWire/WirePlumber.
- `wpctl`.
- WirePlumber config under `~/.config/wireplumber`.
- `System/config/audio-aliases.json`.
- Spatial HRIR asset: `audio/hrir.wav`.
- PipeWire spatial config reference: `System/config/pipewire/astrea-audio-engine.conf`.

## Spatial Audio Contract
Current Astrea Spatial Audio sink:
- `effect_input.virtual-surround-7.1-astrea`

Legacy sink name still accepted by the bridge:
- `effect_input.virtual-surround-7.1-hesuvi`

The bridge should discover the loaded spatial sink and report the active sink name in `spatial.sink`. Do not hardcode new UI actions to the legacy `hesuvi` name only.

The current packaged HRIR is:
- `audio/hrir.wav`

It is a 48 kHz, 16-channel, 50 ms WAV. The 16 channels represent 7.1 HRIR data as 8 speaker positions times 2 ears:
- `FL FR FC LFE RL RR SL SR`

The live user PipeWire config at `~/.config/pipewire/pipewire.conf.d/astrea-audio-engine.conf` points to `/home/agony/.local/share/Astrea/audio/hrir.wav`, not to a file under `Downloads`.

## Related Native Backend
`Core/bridge/audio/music_bars_backend` is used by [[Astrea - Island]] through `System/services/music_bars.sh`.
