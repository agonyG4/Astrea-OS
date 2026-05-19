# MOC - Bridges and Backends

Parent: [[Astrea]]

## Purpose
Bridge notes describe how QML reaches system state, native helpers, and external services.

## Bridge Layer
- [[Astrea - Core Bridge]]

## Domain Bridges
- [[Astrea - Audio Bridge]]
- [[Astrea - Display Bridge]]
- [[Astrea - FileChooser Portal]]
- [[Astrea - Launcher and Latency]]
- [[Astrea - Weather Bridge]]
- [[Astrea - Wallpaper Bridge]]

## Native Backends
- [[Astrea - Explorer Backend]]

## Related System Notes
- [[Astrea - Bluetooth Manager]]
- [[Astrea - System Layer]]

## Common Pattern
1. QML starts a `Process`.
2. A Python, Bash, or native command runs.
3. The command returns JSON or applies a side effect.
4. QML updates models/properties.
