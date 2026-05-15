# Quickshell Memory/Runtime Optimization

Optimize `src/Quickshell` for lower RAM usage and fewer runtime costs without changing the visible UI.

Focus on these areas:

- `shell.qml`: avoid duplicated services per monitor. Keep status backends global/shared and pass them into each `Bar`.
- `bar/Bar.qml`: do not instantiate network/bluetooth/audio watchers separately for every screen.
- `desktop/DesktopIcons.qml`: move backend-like work out of QML. Avoid inline Python, repeated process spawning, and the 5s desktop polling timer. Prefer a persistent watcher/helper using inotify or an existing backend command.
- `notifications/Notifications.qml`: cap live rendered notification cards, e.g. latest 5-8, so notification spam cannot create unlimited QML delegates.
- `bar/modules/bluetooth/BluetoothProcess.qml`: avoid duplicated JSON string + array state. Use arrays/objects internally and stringify only at compatibility boundaries.
- `island/MusicMonitor.qml`: reduce process churn. Only run music bars while needed, cache cover/dominant-color results, avoid restarting processes unnecessarily.
- `spotlight/Spotlight.qml`: keep debounce/result limit, but avoid duplicating Exec parsing in QML when `astrea-launch` or a shared helper can handle it.

Rules:

- Do not redesign the UI.
- Do not rewrite everything.
- Keep behavior compatible.
- Prefer small, reviewable changes.
- Quickshell should mostly render UI and consume state, not act as a backend.

Validate:

- Quickshell starts without QML errors.
- Bar, Control Center, Spotlight, Notifications, Desktop Icons, Bluetooth, volume, network, and Music Island still work.
- Multi-monitor does not duplicate status watcher processes unnecessarily.
- Desktop icon positions still persist.
- Idle shell should have fewer timers/process spawns and better long-session RAM stability.
