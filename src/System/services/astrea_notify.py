#!/usr/bin/env python3
import argparse
import json
import sys

import dbus


BUS_NAME = "org.freedesktop.Notifications"
OBJECT_PATH = "/org/freedesktop/Notifications"
IFACE = "org.freedesktop.Notifications"

URGENCY = {
    "low": 0,
    "normal": 1,
    "critical": 2,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Send notifications through Astrea's notification service.")
    parser.add_argument("--app", default="Astrea", help="Application name shown in the notification.")
    parser.add_argument("--icon", default="", help="Icon name or path.")
    parser.add_argument("--urgency", choices=sorted(URGENCY), default="normal")
    parser.add_argument("--expire-timeout", type=int, default=-1, help="Notification timeout in milliseconds.")
    parser.add_argument("--category", default="", help="Freedesktop notification category hint.")
    parser.add_argument("--desktop-entry", default="", help="Desktop entry hint without .desktop suffix.")
    parser.add_argument("--dry-run", action="store_true", help="Validate input without touching DBus.")
    parser.add_argument("--json", action="store_true", help="Print a JSON result.")
    parser.add_argument("summary")
    parser.add_argument("body", nargs="?", default="")
    return parser.parse_args()


def print_result(args: argparse.Namespace, payload: dict) -> None:
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))


def main() -> int:
    args = parse_args()
    hints = {
        "urgency": dbus.Byte(URGENCY[args.urgency]),
    }
    if args.category:
        hints["category"] = dbus.String(args.category)
    if args.desktop_entry:
        hints["desktop-entry"] = dbus.String(args.desktop_entry)

    if args.dry_run:
        print_result(args, {"sent": True, "dry_run": True, "id": 0})
        return 0

    try:
        bus = dbus.SessionBus()
        obj = bus.get_object(BUS_NAME, OBJECT_PATH)
        notify = obj.get_dbus_method("Notify", IFACE)
        notification_id = notify(
            args.app,
            dbus.UInt32(0),
            args.icon,
            args.summary,
            args.body,
            dbus.Array([], signature="s"),
            dbus.Dictionary(hints, signature="sv"),
            dbus.Int32(args.expire_timeout),
        )
    except Exception as err:
        print(f"astrea-notify: {err}", file=sys.stderr)
        print_result(args, {"sent": False, "dry_run": False, "error": str(err)})
        return 1

    print_result(
        args,
        {
            "sent": True,
            "dry_run": False,
            "id": int(notification_id),
            "backend": BUS_NAME,
        },
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
