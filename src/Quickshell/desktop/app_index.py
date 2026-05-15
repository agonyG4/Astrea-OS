#!/usr/bin/env python3

from __future__ import annotations

import argparse
import ctypes
import json
import os
import select
import sys
import time
from pathlib import Path

BRIDGE_DIR = Path(__file__).resolve().parents[2] / "Core" / "bridge"
if str(BRIDGE_DIR) not in sys.path:
    sys.path.insert(0, str(BRIDGE_DIR))

from astrea_shared import FALLBACK_ICON, atomic_write_json, atomic_write_text, parse_desktop_file, xdg_desktop_dir

MAX_APPS = 64
IN_CLOSE_WRITE = 0x00000008
IN_MOVED_TO = 0x00000080
IN_CREATE = 0x00000100
IN_DELETE = 0x00000200
IN_DELETE_SELF = 0x00000400
IN_MOVE_SELF = 0x00000800
IN_ONLYDIR = 0x01000000
IN_NONBLOCK = 0x00000800
IN_CLOEXEC = 0x00080000
WATCH_MASK = IN_CLOSE_WRITE | IN_MOVED_TO | IN_CREATE | IN_DELETE | IN_DELETE_SELF | IN_MOVE_SELF


def collect_apps() -> list[dict[str, str]]:
    items: list[dict[str, str]] = []
    seen: set[str] = set()
    desktop_dir = xdg_desktop_dir()

    if not desktop_dir.exists():
        return items

    for path in sorted(desktop_dir.glob("*.desktop")):
        parsed = parse_desktop_file(path, source="desktop", skip_terminal=True, require_exec=True)
        if not parsed:
            continue

        key = Path(parsed["desktop_file"]).name
        if key in seen:
            continue

        seen.add(key)
        desktop_file = str(parsed.get("desktop_file") or path)
        home_prefix = str(Path.home())
        if desktop_file == home_prefix:
            desktop_file = "$HOME"
        elif desktop_file.startswith(home_prefix + "/"):
            desktop_file = "$HOME/" + desktop_file[len(home_prefix) + 1:]

        items.append({
            "name": str(parsed.get("name") or ""),
            "generic": str(parsed.get("generic") or ""),
            "icon": str(parsed.get("icon") or FALLBACK_ICON),
            "desktop": desktop_file,
        })

    items.sort(key=lambda item: item["name"].casefold())
    return items


def desktop_signature() -> list[list[object]]:
    desktop_dir = xdg_desktop_dir()
    items: list[list[object]] = []
    if not desktop_dir.exists():
        return items
    for path in sorted(desktop_dir.glob("*.desktop")):
        try:
            stat = path.stat()
        except OSError:
            continue
        items.append([path.name, stat.st_mtime_ns, stat.st_size])
    return items


def signature_json() -> str:
    return json.dumps(desktop_signature(), ensure_ascii=False, separators=(",", ":"))


def emit_signature(last: str | None = None) -> str:
    current = signature_json()
    if current != last:
        print(current, flush=True)
    return current


def inotify_watch() -> int | None:
    desktop_dir = xdg_desktop_dir()
    if not desktop_dir.exists():
        return None
    try:
        libc = ctypes.CDLL("libc.so.6", use_errno=True)
        fd = libc.inotify_init1(IN_NONBLOCK | IN_CLOEXEC)
        if fd < 0:
            return None
        wd = libc.inotify_add_watch(fd, os.fsencode(desktop_dir), WATCH_MASK | IN_ONLYDIR)
        if wd < 0:
            os.close(fd)
            return None
        return fd
    except (AttributeError, OSError):
        return None


def drain_inotify(fd: int) -> None:
    try:
        while os.read(fd, 4096):
            pass
    except BlockingIOError:
        return
    except OSError:
        return


def watch_signatures() -> None:
    last = emit_signature(None)
    fd = inotify_watch()
    if fd is None:
        while True:
            time.sleep(5)
            last = emit_signature(last)

    poller = select.poll()
    poller.register(fd, select.POLLIN | select.POLLERR | select.POLLHUP)
    try:
        while True:
            events = poller.poll(30000)
            if not events:
                last = emit_signature(last)
                continue
            drain_inotify(fd)
            time.sleep(0.08)
            last = emit_signature(last)
    finally:
        os.close(fd)


def write_js(items: list[dict[str, str]], output_path: Path) -> None:
    payload = json.dumps(items, ensure_ascii=False, indent=2)
    atomic_write_text(output_path, f"var APPS = {payload};\n")


def write_json(items: list[dict[str, str]], output_path: Path) -> None:
    atomic_write_json(output_path, items, indent=2)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate or watch the desktop icon list from the XDG desktop folder.")
    parser.add_argument("--json", action="store_true", help="print the generated app list as JSON")
    parser.add_argument("--write", action="store_true", help="write apps.js and apps.json")
    parser.add_argument("--signature", action="store_true", help="print the current desktop shortcut signature as JSON")
    parser.add_argument("--watch-signature", action="store_true", help="stream desktop shortcut signatures when the desktop folder changes")
    parser.add_argument("--max-apps", type=int, default=MAX_APPS, help="maximum number of apps to emit")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.watch_signature:
        watch_signatures()
        return
    if args.signature:
        print(signature_json())
        return

    items = collect_apps()[:max(1, args.max_apps)]
    script_dir = Path(__file__).resolve().parent

    if args.write or not args.json:
        js_path = script_dir / "apps.js"
        json_path = script_dir / "apps.json"
        write_js(items, js_path)
        write_json(items, json_path)
        if not args.json:
            print(f"{js_path} ({len(items)} apps)")

    if args.json:
        print(json.dumps(items, ensure_ascii=False))


if __name__ == "__main__":
    main()
