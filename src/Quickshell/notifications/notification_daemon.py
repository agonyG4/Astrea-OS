#!/usr/bin/env python3
import json
import os
import signal
import sys
from pathlib import Path

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib


APP_NAME = "Astrea Notifications"
BUS_NAME = "org.freedesktop.Notifications"
OBJECT_PATH = "/org/freedesktop/Notifications"
IFACE = "org.freedesktop.Notifications"

BASE_DIR = Path(__file__).resolve().parent
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME") or (Path.home() / ".local/state")).expanduser() / "Astrea/notifications"
STATE_PATH = STATE_DIR / "state.json"
LOG_PATH = STATE_DIR / "notifications.log"
IDLE_TIMEOUT_MS = 30000
MAX_HISTORY = 80
MAX_DELIVERED_EVENTS = 500
ASTREA_EVENT_HINT = "x-astrea-event-id"
ASTREA_THREAD_HINT = "x-astrea-thread-id"
ASTREA_COLLAPSE_HINT = "x-astrea-collapse-key"
ASTREA_PRESENTATION_HINT = "x-astrea-presentation"
ASTREA_INTERRUPTION_HINT = "x-astrea-interruption-level"
PRESENTATIONS = {"banner", "list", "silent", "none"}
INTERRUPTION_LEVELS = {"passive", "active", "time-sensitive", "critical"}


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


def _clean_metadata_value(value):
    return str(value or "").strip()


def _normalized_astrea_presentation(value):
    presentation = _clean_metadata_value(value).lower()
    return presentation if presentation in PRESENTATIONS else "banner"


def _normalized_interruption_level(value):
    level = _clean_metadata_value(value).lower()
    return level if level in INTERRUPTION_LEVELS else "active"


def _astrea_metadata_from_hints(hints):
    plain_hints = hints if isinstance(hints, dict) else {}
    return {
        "eventId": _clean_metadata_value(plain_hints.get(ASTREA_EVENT_HINT)),
        "threadId": _clean_metadata_value(plain_hints.get(ASTREA_THREAD_HINT)),
        "collapseKey": _clean_metadata_value(plain_hints.get(ASTREA_COLLAPSE_HINT)),
        "presentation": _normalized_astrea_presentation(plain_hints.get(ASTREA_PRESENTATION_HINT)),
        "interruptionLevel": _normalized_interruption_level(plain_hints.get(ASTREA_INTERRUPTION_HINT)),
    }


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
        self.history = {}
        self.delivered_events = {}
        self.history_event_index = {}
        self.active_event_index = {}
        self.active_collapse_index = {}
        self.timeouts = {}
        self.idle_source = None
        self.loop = None
        self._load_state()
        self._ensure_state()
        self._schedule_idle_exit()

    def _ensure_state(self):
        STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
        self._write_state()

    def _log(self, message):
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with LOG_PATH.open("a", encoding="utf-8") as log_file:
            log_file.write(f"{GLib.DateTime.new_now_local().format('%F %T')} {message}\n")

    def _normalize_saved_notification(self, item):
        notification_id = int(item.get("id") or item.get("notificationId") or 0)
        if notification_id <= 0:
            return None

        return {
            "id": notification_id,
            "appName": str(item.get("appName") or "Application"),
            "appIcon": str(item.get("appIcon") or ""),
            "summary": str(item.get("summary") or "Notification"),
            "body": str(item.get("body") or ""),
            "actions": [str(action) for action in item.get("actions", [])],
            "hints": item.get("hints") if isinstance(item.get("hints"), dict) else {},
            "urgency": int(item.get("urgency") or 1),
            "createdAt": str(item.get("createdAt") or ""),
            "eventId": str(item.get("eventId") or ""),
            "threadId": str(item.get("threadId") or ""),
            "collapseKey": str(item.get("collapseKey") or ""),
            "presentation": _normalized_astrea_presentation(item.get("presentation")),
            "interruptionLevel": _normalized_interruption_level(item.get("interruptionLevel")),
        }

    def _load_state(self):
        try:
            payload = json.loads(STATE_PATH.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return

        saved_delivered = payload.get("deliveredEvents", {})
        if isinstance(saved_delivered, dict):
            for event_id, notification_id in saved_delivered.items():
                self._remember_event_delivery(event_id, notification_id)

        saved_history = payload.get("history") or payload.get("notifications") or []
        for item in saved_history[-MAX_HISTORY:]:
            if not isinstance(item, dict):
                continue
            notification = self._normalize_saved_notification(item)
            if not notification:
                continue
            self.history[notification["id"]] = notification
            self._index_history_notification(notification)
            self.next_id = max(self.next_id, notification["id"] + 1)

    def _index(self, name):
        index = getattr(self, name, None)
        if index is None:
            index = {}
            setattr(self, name, index)
        return index

    def _notification_id(self, notification):
        try:
            notification_id = int(notification.get("id") or notification.get("notificationId") or 0)
        except (AttributeError, TypeError, ValueError):
            return 0
        return notification_id if notification_id > 0 else 0

    def _drop_index_entry(self, index_name, key, notification_id):
        if not key:
            return
        index = self._index(index_name)
        if int(index.get(key) or 0) == int(notification_id):
            index.pop(key, None)

    def _remember_event_delivery(self, event_id, notification_id):
        event_id = _clean_metadata_value(event_id)
        try:
            notification_id = int(notification_id or 0)
        except (TypeError, ValueError):
            notification_id = 0
        if not event_id or notification_id <= 0:
            return

        delivered = self._index("delivered_events")
        delivered.pop(event_id, None)
        delivered[event_id] = notification_id
        while len(delivered) > MAX_DELIVERED_EVENTS:
            oldest_event = next(iter(delivered))
            delivered.pop(oldest_event, None)

    def _forget_event_delivery(self, event_id, notification_id=0):
        event_id = _clean_metadata_value(event_id)
        if not event_id:
            return
        delivered = self._index("delivered_events")
        if notification_id and int(delivered.get(event_id) or 0) != int(notification_id):
            return
        delivered.pop(event_id, None)

    def _index_history_notification(self, notification):
        notification_id = self._notification_id(notification)
        if notification_id <= 0:
            return
        event_id = _clean_metadata_value(notification.get("eventId"))
        if event_id:
            self._index("history_event_index")[event_id] = notification_id
            self._remember_event_delivery(event_id, notification_id)

    def _drop_history_indexes(self, notification, forget_delivery=False):
        notification_id = self._notification_id(notification)
        if notification_id <= 0:
            return
        event_id = _clean_metadata_value(notification.get("eventId"))
        self._drop_index_entry("history_event_index", event_id, notification_id)
        if forget_delivery:
            self._forget_event_delivery(event_id, notification_id)

    def _drop_active_indexes(self, notification):
        notification_id = self._notification_id(notification)
        if notification_id <= 0:
            return
        self._drop_index_entry("active_event_index", _clean_metadata_value(notification.get("eventId")), notification_id)
        self._drop_index_entry("active_collapse_index", _clean_metadata_value(notification.get("collapseKey")), notification_id)

    def _store_active_notification(self, notification):
        notification_id = self._notification_id(notification)
        if notification_id <= 0:
            return
        previous = self.notifications.get(notification_id)
        if previous:
            self._drop_active_indexes(previous)
        self.notifications[notification_id] = dict(notification)

        event_id = _clean_metadata_value(notification.get("eventId"))
        collapse_key = _clean_metadata_value(notification.get("collapseKey"))
        if event_id:
            self._index("active_event_index")[event_id] = notification_id
        if collapse_key:
            self._index("active_collapse_index")[collapse_key] = notification_id

    def _remove_active_notification(self, notification_id):
        try:
            notification_id = int(notification_id or 0)
        except (TypeError, ValueError):
            return None
        notification = self.notifications.pop(notification_id, None)
        if notification:
            self._drop_active_indexes(notification)
        return notification

    def _remember_history(self, notification):
        notification_id = int(notification["id"])
        previous = self.history.pop(notification_id, None)
        if previous:
            self._drop_history_indexes(previous)
        self.history[notification_id] = dict(notification)
        self._index_history_notification(notification)

        while len(self.history) > MAX_HISTORY:
            oldest_id = next(iter(self.history))
            oldest = self.history.pop(oldest_id, None)
            if oldest:
                self._drop_history_indexes(oldest)

    def _write_state(self):
        payload = {
            "server": APP_NAME,
            "notifications": list(self.notifications.values()),
            "history": list(self.history.values()),
            "deliveredEvents": dict(self.delivered_events),
        }
        state = json.dumps(payload, ensure_ascii=False, indent=2)
        if STATE_PATH.exists():
            try:
                if STATE_PATH.read_text(encoding="utf-8") == state:
                    return
            except OSError:
                pass
        temp_path = STATE_PATH.with_suffix(".json.tmp")
        temp_path.write_text(state, encoding="utf-8")
        temp_path.replace(STATE_PATH)

    def _cancel_idle_exit(self):
        if self.idle_source:
            GLib.source_remove(self.idle_source)
            self.idle_source = None

    def _schedule_idle_exit(self):
        if self.notifications:
            return
        self._cancel_idle_exit()
        self.idle_source = GLib.timeout_add(IDLE_TIMEOUT_MS, self._idle_exit)

    def _idle_exit(self):
        self.idle_source = None
        if self.notifications:
            return GLib.SOURCE_REMOVE
        self._write_state()
        self._log("idle exit")
        if self.loop:
            self.loop.quit()
        return GLib.SOURCE_REMOVE

    def _next_notification_id(self):
        notification_id = self.next_id
        self.next_id += 1
        return notification_id

    def _find_notification_by_field(self, collection, field, value):
        if not value:
            return 0
        for notification_id, notification in collection.items():
            if notification.get(field) == value:
                return int(notification_id)
        return 0

    def _find_indexed_notification(self, collection, index_name, field, value):
        value = _clean_metadata_value(value)
        if not value:
            return 0

        index = self._index(index_name)
        indexed_id = int(index.get(value) or 0)
        indexed_notification = collection.get(indexed_id)
        if indexed_notification and indexed_notification.get(field) == value:
            return indexed_id
        if indexed_id:
            index.pop(value, None)

        notification_id = self._find_notification_by_field(collection, field, value)
        if notification_id:
            index[value] = notification_id
        return notification_id

    def _delivered_event_notification_id(self, event_id):
        event_id = _clean_metadata_value(event_id)
        if not event_id:
            return 0
        try:
            return int(self._index("delivered_events").get(event_id) or 0)
        except (TypeError, ValueError):
            return 0

    def _resolve_notification_request(self, replaces_id, event_id="", collapse_key=""):
        requested_id = int(replaces_id or 0)
        if requested_id > 0:
            return requested_id, False

        active_event_id = self._find_indexed_notification(
            self.notifications,
            "active_event_index",
            "eventId",
            event_id,
        )
        if active_event_id:
            return active_event_id, False

        delivered_event_id = self._delivered_event_notification_id(event_id)
        if delivered_event_id:
            return delivered_event_id, True

        history_event_id = self._find_indexed_notification(
            self.history,
            "history_event_index",
            "eventId",
            event_id,
        )
        if history_event_id:
            return history_event_id, True

        active_collapse_id = self._find_indexed_notification(
            self.notifications,
            "active_collapse_index",
            "collapseKey",
            collapse_key,
        )
        if active_collapse_id:
            return active_collapse_id, False

        return self._next_notification_id(), False

    def _presentation_shows_banner(self, presentation):
        return _normalized_astrea_presentation(presentation) == "banner"

    def _cancel_expiry(self, notification_id):
        old_source = self.timeouts.pop(notification_id, None)
        if old_source:
            GLib.source_remove(old_source)

    def _schedule_expiry(self, notification_id, expire_timeout):
        self._cancel_expiry(notification_id)

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
            self._remove_active_notification(notification_id)
            self._write_state()
            self.NotificationClosed(notification_id, 1)
            self._schedule_idle_exit()
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
        plain_hints = _variant_to_plain(hints)
        metadata = _astrea_metadata_from_hints(plain_hints)
        notification_id, history_only = self._resolve_notification_request(
            replaces_id,
            metadata["eventId"],
            metadata["collapseKey"],
        )
        urgency = int(plain_hints.get("urgency", 1))

        notification = {
            "id": notification_id,
            "appName": str(app_name) or "Application",
            "appIcon": str(app_icon),
            "summary": str(summary) or "Notification",
            "body": str(body),
            "actions": [str(action) for action in actions],
            "hints": plain_hints,
            "urgency": urgency,
            "createdAt": GLib.DateTime.new_now_local().format("%H:%M"),
            "eventId": metadata["eventId"],
            "threadId": metadata["threadId"],
            "collapseKey": metadata["collapseKey"],
            "presentation": metadata["presentation"],
            "interruptionLevel": metadata["interruptionLevel"],
        }

        if history_only:
            self._write_state()
            self._schedule_idle_exit()
            self._log(
                "notify suppressed "
                f"id={notification_id} app={app_name!s} summary={summary!s} "
                f"event={metadata['eventId']} collapse={metadata['collapseKey']}"
            )
            return dbus.UInt32(notification_id)

        self._remember_history(notification)

        show_banner = self._presentation_shows_banner(metadata["presentation"]) and not history_only
        if show_banner:
            self._store_active_notification(notification)
            self._cancel_idle_exit()
            self._schedule_expiry(notification_id, expire_timeout)
        else:
            self._cancel_expiry(notification_id)
            self._remove_active_notification(notification_id)

        self._write_state()
        self._schedule_idle_exit()
        self._log(
            "notify "
            f"id={notification_id} app={app_name!s} summary={summary!s} "
            f"event={metadata['eventId']} collapse={metadata['collapseKey']} "
            f"presentation={metadata['presentation']}"
        )
        return dbus.UInt32(notification_id)

    @dbus.service.method(IFACE, in_signature="u", out_signature="")
    def CloseNotification(self, notification_id):
        notification_id = int(notification_id)
        self._cancel_expiry(notification_id)
        if notification_id in self.notifications:
            self._remove_active_notification(notification_id)
            self._write_state()
            self.NotificationClosed(notification_id, 3)
            self._schedule_idle_exit()

    @dbus.service.method(IFACE, in_signature="u", out_signature="")
    def ClearHistoryItem(self, notification_id):
        notification_id = int(notification_id)
        self._cancel_expiry(notification_id)

        if notification_id in self.notifications:
            self._remove_active_notification(notification_id)
            self.NotificationClosed(notification_id, 3)

        history_item = self.history.pop(notification_id, None)
        if history_item:
            self._drop_history_indexes(history_item, forget_delivery=True)
        self._write_state()
        self._schedule_idle_exit()

    @dbus.service.method(IFACE, in_signature="", out_signature="")
    def ClearHistory(self):
        for notification_id in list(self.timeouts):
            old_source = self.timeouts.pop(notification_id, None)
            if old_source:
                GLib.source_remove(old_source)

        for notification_id in list(self.notifications):
            self.NotificationClosed(notification_id, 3)

        self.notifications = {}
        self.history = {}
        self.delivered_events = {}
        self.history_event_index = {}
        self.active_event_index = {}
        self.active_collapse_index = {}
        self._write_state()
        self._schedule_idle_exit()

    @dbus.service.method(IFACE, in_signature="", out_signature="ssss")
    def GetServerInformation(self):
        return (APP_NAME, "Astrea", "0.1.0", "1.2")

    @dbus.service.signal(IFACE, signature="uu")
    def NotificationClosed(self, notification_id, reason):
        pass

    @dbus.service.signal(IFACE, signature="us")
    def ActionInvoked(self, notification_id, action_key):
        pass


def main():
    daemon = NotificationDaemon()
    loop = GLib.MainLoop()
    daemon.loop = loop

    def stop(*_args):
        daemon._cancel_idle_exit()
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
