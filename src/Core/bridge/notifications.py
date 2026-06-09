#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from typing import Any


BUS_NAME = "org.freedesktop.Notifications"
OBJECT_PATH = "/org/freedesktop/Notifications"
IFACE = "org.freedesktop.Notifications"

PRESENTATIONS = {"banner", "list", "silent", "none"}
INTERRUPTION_LEVELS = {"passive", "active", "time-sensitive", "critical"}
URGENCY_VALUES = {
    "low": 0,
    "passive": 0,
    "normal": 1,
    "active": 1,
    "time-sensitive": 1,
    "critical": 2,
}


def clean(value: Any) -> str:
    return str(value or "").strip()


def normalize_presentation(value: Any) -> str:
    presentation = clean(value).lower()
    return presentation if presentation in PRESENTATIONS else "banner"


def normalize_interruption_level(value: Any) -> str:
    level = clean(value).lower()
    return level if level in INTERRUPTION_LEVELS else "active"


def normalize_urgency(value: Any) -> int:
    if isinstance(value, int):
        return max(0, min(2, value))
    return URGENCY_VALUES.get(clean(value).lower(), 1)


def build_hints(
    event_id: str = "",
    thread_id: str = "",
    collapse_key: str = "",
    presentation: str = "banner",
    interruption_level: str = "active",
    urgency: str | int = "normal",
) -> dict[str, Any]:
    hints: dict[str, Any] = {
        "urgency": normalize_urgency(urgency),
        "x-astrea-presentation": normalize_presentation(presentation),
        "x-astrea-interruption-level": normalize_interruption_level(interruption_level),
    }
    if clean(event_id):
        hints["x-astrea-event-id"] = clean(event_id)
    if clean(thread_id):
        hints["x-astrea-thread-id"] = clean(thread_id)
    if clean(collapse_key):
        hints["x-astrea-collapse-key"] = clean(collapse_key)
    return hints


def notify_send_urgency(urgency: str | int) -> str:
    value = normalize_urgency(urgency)
    if value <= 0:
        return "low"
    if value >= 2:
        return "critical"
    return "normal"


def send_via_dbus(payload: dict[str, Any]) -> int:
    import dbus

    bus = dbus.SessionBus()
    obj = bus.get_object(BUS_NAME, OBJECT_PATH)
    iface = dbus.Interface(obj, IFACE)
    return int(iface.Notify(
        payload["app"],
        int(payload.get("replaces_id", 0) or 0),
        payload.get("icon", ""),
        payload["summary"],
        payload.get("body", ""),
        [],
        payload["hints"],
        int(payload.get("expire_timeout", -1) or -1),
    ))


def send_via_notify_send(payload: dict[str, Any]) -> int:
    if not shutil.which("notify-send"):
        raise RuntimeError("notify-send is not available")
    command = [
        "notify-send",
        "-a",
        payload["app"],
        "-u",
        notify_send_urgency(payload.get("urgency", "normal")),
        payload["summary"],
        payload.get("body", ""),
    ]
    subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2, check=True)
    return 0


def send_notification(payload: dict[str, Any]) -> dict[str, Any]:
    try:
        notification_id = send_via_dbus(payload)
        return {"ok": True, "notificationId": notification_id, "transport": "dbus"}
    except Exception as dbus_error:
        try:
            notification_id = send_via_notify_send(payload)
            return {
                "ok": True,
                "notificationId": notification_id,
                "transport": "notify-send",
                "warning": str(dbus_error),
            }
        except Exception as fallback_error:
            return {
                "ok": False,
                "notificationId": 0,
                "transport": "",
                "message": str(fallback_error),
                "dbusError": str(dbus_error),
            }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Send an Astrea notification")
    parser.add_argument("--app", default="Astrea")
    parser.add_argument("--summary", required=True)
    parser.add_argument("--body", default="")
    parser.add_argument("--icon", default="")
    parser.add_argument("--event-id", default="")
    parser.add_argument("--thread-id", default="")
    parser.add_argument("--collapse-key", default="")
    parser.add_argument("--presentation", default="banner")
    parser.add_argument("--interruption-level", default="active")
    parser.add_argument("--urgency", default="normal")
    parser.add_argument("--expire-timeout", default=-1, type=int)
    parser.add_argument("--replaces-id", default=0, type=int)
    return parser


def payload_from_args(args: argparse.Namespace) -> dict[str, Any]:
    hints = build_hints(
        event_id=args.event_id,
        thread_id=args.thread_id,
        collapse_key=args.collapse_key,
        presentation=args.presentation,
        interruption_level=args.interruption_level,
        urgency=args.urgency,
    )
    return {
        "app": args.app,
        "summary": args.summary,
        "body": args.body,
        "icon": args.icon,
        "urgency": args.urgency,
        "expire_timeout": args.expire_timeout,
        "replaces_id": args.replaces_id,
        "hints": hints,
    }


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    result = send_notification(payload_from_args(args))
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
