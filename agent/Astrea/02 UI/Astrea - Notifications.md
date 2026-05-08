# Astrea - Notifications

Related notes: [[Astrea - Quickshell Runtime]], [[Astrea - System Layer]]

## Folder
`Quickshell/notifications/`

## Responsibility
Astrea provides a freedesktop-compatible notification daemon and a QML notification overlay.

## Main Files
- `notification_daemon.py`
- `Notifications.qml`
- `state.json`
- `notifications.log`

## System Registration
Astrea registers the notification daemon as the session notification server through:
- `~/.local/share/dbus-1/services/org.freedesktop.Notifications.service`

That service executes:
- `/home/agony/.local/share/Astrea/Quickshell/notifications/notification_daemon.py`

The QML overlay is resident in the main shell through `Quickshell/shell.qml`.

Layer namespace:
- `astrea-notifications`

## Data Flow
1. Applications send notifications to `org.freedesktop.Notifications`.
2. `notification_daemon.py` receives DBus calls.
3. The daemon normalizes notifications.
4. It writes notification state to `state.json`.
5. `Notifications.qml` watches `state.json` with `FileView`.
6. QML renders notification cards.
7. Dismissals call DBus close through `gdbus`.

## Weather Notifications
[[Astrea - Weather App]] can emit INMET alert notifications through [[Astrea - Weather Bridge]].

The Weather app owns its notification preference:
- `~/.local/state/Astrea/weather/settings.json`

The Weather bridge owns alert deduplication:
- `~/.local/state/Astrea/weather/inmet-notified.json`

Delivery uses `notify-send`, so the notification enters the same freedesktop notification path as other applications.

## Dependencies
- Python DBus bindings.
- DBus session bus.
- Quickshell `FileView`.
- `gdbus`.
- `notify-send` for app-originated notifications such as Weather alerts.

## Validation
- `python3 -m py_compile /home/agony/.local/share/Astrea/Quickshell/notifications/notification_daemon.py`
- `gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.GetServerInformation`
- `notify-send "Astrea test" "message"`
- `hyprctl layers` should show `astrea-notifications` when cards are visible.
