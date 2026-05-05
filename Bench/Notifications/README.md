# Bench Notifications

Small freedesktop notification daemon for Astrea/Bench.

It owns `org.freedesktop.Notifications` on the session bus, so normal apps can send notifications through `notify-send`, GTK, Electron, browsers, and anything else that follows the desktop notification spec.

## Install DBus activation

```bash
./install.sh
```

That writes:

```text
~/.local/share/dbus-1/services/org.freedesktop.Notifications.service
```

After that, apps can auto-start the daemon by sending a notification.

## Run manually

```bash
./notification_daemon.py
```

The daemon starts the Quickshell UI with local state-file reads enabled.
For direct UI-only testing, use:

```bash
QML_XHR_ALLOW_FILE_READ=1 quickshell -p Shell.qml
```

## Test

```bash
notify-send -a "Bench Test" "Bench Notifications" "If this appears, apps can reach our notification server."
```

You can also check the registered server:

```bash
gdbus call --session \
  --dest org.freedesktop.Notifications \
  --object-path /org/freedesktop/Notifications \
  --method org.freedesktop.Notifications.GetServerInformation
```
