# MOC - Bridges and Backends

Parent: [[Astrea]]

## Purpose
Bridge notes describe how QML reaches system state, native helpers, and external services.

## Bridge Layer
- [[Astrea - Core Bridge]]
- [[Astrea - App Manager Bridge]]
- [[Astrea - Session Daemon]]
- [[Astrea - State JSON Bridge]]

## Domain Bridges
- [[Astrea - Audio Bridge]]
- [[Astrea - Display Bridge]]
- [[Astrea - FileChooser Portal]]
- [[Astrea - Launcher and Latency]]
- [[Astrea - Network Bridge]]
- [[Astrea - Weather Bridge]]
- [[Astrea - Wallpaper Bridge]]

## Native Backends
- [[Astrea - Explorer Backend]]
- `Core/bridge/audio/music_bars_backend`
- `System/launch/target/release/astrea-launch`
- `Apps/Weather/backend`

## Related System Notes
- [[Astrea - Bluetooth Manager]]
- [[Astrea - System Layer]]
- [[Astrea - Polkit Auth]]
- [[Astrea - I18n]]

## Common Pattern
1. QML starts a `Process`.
2. A Python, Bash, or native command runs.
3. The command returns JSON or applies a side effect.
4. QML updates models/properties.
