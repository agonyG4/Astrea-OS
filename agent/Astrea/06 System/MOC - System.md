# MOC - System

Parent: [[Astrea]]

## Purpose
System notes describe OS integration, local scripts, privileged helpers, and machine-level dependencies.

## Notes
- [[Astrea - System Layer]]
- [[Astrea - Bluetooth Manager]]
- [[Astrea - Launcher and Latency]]
- [[Astrea - Gaming and Compatibility]]
- [[Astrea - Polkit Auth]]
- [[Astrea - I18n]]

## Related Bridges
- [[Astrea - Display Bridge]]
- [[Astrea - Audio Bridge]]
- [[Astrea - Core Bridge]]
- [[Astrea - Session Daemon]]
- [[Astrea - State JSON Bridge]]

## Important Boundaries
- Hyprland integration lives here.
- PipeWire/WirePlumber integration crosses this domain and [[Astrea - Audio Bridge]].
- Bluetooth is a system helper consumed by both UI and Settings.
- Privileged helpers should be treated as a security boundary.
