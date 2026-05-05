#!/usr/bin/env python3
import json
import os
import signal
import subprocess
import sys
from pathlib import Path

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib


APP_NAME = "Bench Notifications"
BUS_NAME = "org.freedesktop.Notifications"
OBJECT_PATH = "/org/freedesktop/Notifications"
IFACE = "org.freedesktop.Notifications"

BASE_DIR = Path(__file__).resolve().parent
STATE_PATH = BASE_DIR / "state.json"
SHELL_PATH = BASE_DIR / "Shell.qml"
LOG_PATH = BASE_DIR / "notifications.log"


def _variant_to_plain(value):
    if isinstance(value, dbus.String):
        return str(value)
    if isinstance(value, dbus.Boolean):
        return bool(value)
    if isinstance(value, (dbus.Byte, dbus.Int16, dbus.Int32, dbus.Int64,
                          dbus.UInt16, dbus.UInt32, dbus.UInt64)):
        return int(value)
    if isinstance(value, dbus.Double):
        return float(value)
    if isinstance(value, (dbus.Array, list, tuple)):
        return [_variant_to_plain(item) for item in value]
    if isinstance(value, (dbus.Dictionary, dict)):
        return {str(key): _variant_to_plain(item) for key, item in value.items()}
    return str(value)


class NotificationDaemon(dbus.service.Object):
    def __init__(self):
        DBusGMainLoop(set_as_default=True)
        self.bus = dbus.SessionBus()
        self.bus_name = dbus.service.BusName(
            BUS_NAME,
            bus=self.bus,
            do_not_queue=True,
            allow_replacement=True,
            replace_existing=True,
        )
        super().__init__(self.bus_name, OBJECT_PATH)
        self.next_id = 1
        self.notifications = {}
        self.timeouts = {}
        self.shell_process = None
        self._ensure_state()
        self._start_shell()

    def _ensure_state(self):
        STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
        if not STATE_PATH.exists():
            self._write_state()

    def _start_shell(self):
        if self.shell_process and self.shell_process.poll() is None:
            return
        qs = os.environ.get("BENCH_NOTIFICATIONS_QS", "quickshell")
        env = os.environ.copy()
        env["QML_XHR_ALLOW_FILE_READ"] = "1"
        try:
            self.shell_process = subprocess.Popen(
                [qs, "-p", str(SHELL_PATH)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                env=env,
                start_new_session=True,
            )
        except OSError as exc:
            self._log(f"failed to start quickshell UI: {exc}")

    def _log(self, message):
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with LOG_PATH.open("a", encoding="utf-8") as log_file:
            log_file.write(f"{GLib.DateTime.new_now_local().format('%F %T')} {message}\n")

    def _write_state(self):
        payload = {
            "server": APP_NAME,
            "notifications": list(self.notifications.values()),
        }
        temp_path = STATE_PATH.with_suffix(".json.tmp")
        temp_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        temp_path.replace(STATE_PATH)

    def _next_notification_id(self):
        notification_id = self.next_id
        self.next_id += 1
        return notification_id

    def _schedule_expiry(self, notification_id, expire_timeout):
        old_source = self.timeouts.pop(notification_id, None)
        if old_source:
            GLib.source_remove(old_source)

        timeout_ms = int(expire_timeout)
        if timeout_ms == 0:
            return
        if timeout_ms < 0:
            timeout_ms = 7000

        source_id = GLib.timeout_add(timeout_ms, self._expire_notification, notification_id)
        self.timeouts[notification_id] = source_id

    def _expire_notification(self, notification_id):
        self.timeouts.pop(notification_id, None)
        if notification_id in self.notifications:
            self.notifications.pop(notification_id, None)
            self._write_state()
            self.NotificationClosed(notification_id, 1)
        return GLib.SOURCE_REMOVE

    @dbus.service.method(IFACE, in_signature="", out_signature="as")
    def GetCapabilities(self):
        return [
            "actions",
            "body",
            "body-markup",
            "body-hyperlinks",
            "icon-static",
            "persistence",
        ]

    @dbus.service.method(IFACE, in_signature="susssasa{sv}i", out_signature="u")
    def Notify(self, app_name, replaces_id, app_icon, summary, body, actions, hints, expire_timeout):
        notification_id = int(replaces_id) if int(replaces_id) > 0 else self._next_notification_id()
        plain_hints = _variant_to_plain(hints)
        urgency = int(plain_hints.get("urgency", 1))

        self.notifications[notification_id] = {
            "id": notification_id,
            "appName": str(app_name) or "Application",
            "appIcon": str(app_icon),
            "summary": str(summary) or "Notification",
            "body": str(body),
            "actions": [str(action) for action in actions],
            "hints": plain_hints,
            "urgency": urgency,
            "createdAt": GLib.DateTime.new_now_local().format("%H:%M"),
        }

        self._start_shell()
        self._write_state()
        self._schedule_expiry(notification_id, expire_timeout)
        self._log(f"notify id={notification_id} app={app_name!s} summary={summary!s}")
        return dbus.UInt32(notification_id)

    @dbus.service.method(IFACE, in_signature="u", out_signature="")
    def CloseNotification(self, notification_id):
        notification_id = int(notification_id)
        old_source = self.timeouts.pop(notification_id, None)
        if old_source:
            GLib.source_remove(old_source)
        if notification_id in self.notifications:
            self.notifications.pop(notification_id, None)
            self._write_state()
            self.NotificationClosed(notification_id, 3)

    @dbus.service.method(IFACE, in_signature="", out_signature="ssss")
    def GetServerInformation(self):
        return (APP_NAME, "Astrea Bench", "0.1.0", "1.2")

    @dbus.service.signal(IFACE, signature="uu")
    def NotificationClosed(self, notification_id, reason):
        pass

    @dbus.service.signal(IFACE, signature="us")
    def ActionInvoked(self, notification_id, action_key):
        pass


def main():
    daemon = NotificationDaemon()
    loop = GLib.MainLoop()

    def stop(*_args):
        daemon._write_state()
        loop.quit()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    loop.run()


if __name__ == "__main__":
    try:
        main()
    except dbus.exceptions.NameExistsException:
        print(f"{BUS_NAME} is already owned by another notification daemon.", file=sys.stderr)
        sys.exit(2)
