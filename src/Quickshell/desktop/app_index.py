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
DESKTOP_CONFIG_DEFAULT = {"enabled": True}
DESKTOP_STATE_DEFAULT = {"sortMode": "name", "iconPreset": "medium", "iconsHidden": False, "positions": {}}
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


def display_path(path: Path) -> str:
    raw = str(path)
    home_prefix = str(Path.home())
    if raw == home_prefix:
        return "$HOME"
    if raw.startswith(home_prefix + "/"):
        return "$HOME/" + raw[len(home_prefix) + 1:]
    return raw


def next_folder_path(desktop_dir: Path, base_name: str = "Nova Pasta") -> Path:
    candidate = desktop_dir / base_name
    if not candidate.exists():
        return candidate

    index = 2
    while True:
        candidate = desktop_dir / f"{base_name} {index}"
        if not candidate.exists():
            return candidate
        index += 1


def create_folder() -> Path:
    desktop_dir = xdg_desktop_dir()
    desktop_dir.mkdir(parents=True, exist_ok=True)
    path = next_folder_path(desktop_dir)
    path.mkdir()
    return path


def load_state(paths: list[str]) -> dict:
    for raw in paths:
        path = Path(raw).expanduser()
        try:
            if path.exists():
                data = json.loads(path.read_text(encoding="utf-8") or "{}")
                return data if isinstance(data, dict) else {}
        except (OSError, json.JSONDecodeError):
            continue
    return {}


def save_state(path_text: str, payload_text: str) -> None:
    path = Path(path_text).expanduser()
    payload = json.loads(payload_text or "{}")
    if not isinstance(payload, dict):
        raise ValueError("desktop state payload must be a JSON object")
    atomic_write_json(path, payload)


def load_desktop_config(path_text: str) -> dict:
    path = Path(path_text).expanduser()
    cfg = dict(DESKTOP_CONFIG_DEFAULT)
    if path.exists():
        data = load_state([path_text])
        if isinstance(data, dict):
            cfg.update(data)
    else:
        atomic_write_json(path, cfg, indent=4)
    return cfg


def save_desktop_config(path_text: str, payload_text: str) -> None:
    path = Path(path_text).expanduser()
    payload = json.loads(payload_text or "{}")
    if not isinstance(payload, dict):
        raise ValueError("desktop config payload must be a JSON object")
    cfg = dict(DESKTOP_CONFIG_DEFAULT)
    cfg.update(payload)
    atomic_write_json(path, cfg, indent=4)


def load_desktop_layout(path_text: str) -> dict:
    path = Path(path_text).expanduser()
    state = dict(DESKTOP_STATE_DEFAULT)
    state["positions"] = {}
    if path.exists():
        data = load_state([path_text])
        if isinstance(data, dict):
            state.update(data)
    else:
        atomic_write_json(path, state, indent=None)
    if not isinstance(state.get("positions"), dict):
        state["positions"] = {}
    return state


def update_desktop_layout(path_text: str, sort_mode: str, icon_preset: str, icons_hidden: str, clear_positions: str) -> None:
    state = load_desktop_layout(path_text)
    state["sortMode"] = sort_mode
    state["iconPreset"] = icon_preset
    state["iconsHidden"] = icons_hidden == "1"
    if clear_positions == "1":
        state["positions"] = {}
    elif not isinstance(state.get("positions"), dict):
        state["positions"] = {}
    atomic_write_json(Path(path_text).expanduser(), state, indent=None)


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
        desktop_file = display_path(Path(parsed.get("desktop_file") or path))

        items.append({
            "name": str(parsed.get("name") or ""),
            "generic": str(parsed.get("generic") or ""),
            "icon": str(parsed.get("icon") or FALLBACK_ICON),
            "desktop": desktop_file,
            "kind": "app",
        })

    for path in sorted((p for p in desktop_dir.iterdir() if p.is_dir()), key=lambda p: p.name.casefold()):
        key = display_path(path)
        if key in seen:
            continue
        seen.add(key)
        items.append({
            "name": path.name,
            "generic": "Folder",
            "icon": "folder",
            "desktop": key,
            "kind": "folder",
        })

    items.sort(key=lambda item: item["name"].casefold())
    return items


def desktop_signature() -> list[list[object]]:
    desktop_dir = xdg_desktop_dir()
    items: list[list[object]] = []
    if not desktop_dir.exists():
        return items
    for path in sorted(desktop_dir.iterdir()):
        if not (path.is_dir() or path.suffix == ".desktop"):
            continue
        try:
            stat = path.stat()
        except OSError:
            continue
        items.append([path.name, "dir" if path.is_dir() else "desktop", stat.st_mtime_ns, stat.st_size])
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
    parent_pid = os.getppid()

    def parent_alive() -> bool:
        return os.getppid() == parent_pid

    last = emit_signature(None)
    fd = inotify_watch()
    if fd is None:
        while parent_alive():
            time.sleep(5)
            last = emit_signature(last)
        return

    poller = select.poll()
    poller.register(fd, select.POLLIN | select.POLLERR | select.POLLHUP)
    try:
        while parent_alive():
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
    parser.add_argument("--create-folder", action="store_true", help="create a new folder on the desktop")
    parser.add_argument("--load-state", nargs="+", metavar="PATH", help="print the first readable desktop icon state file")
    parser.add_argument("--save-state", nargs=2, metavar=("PATH", "JSON"), help="atomically write desktop icon state JSON")
    parser.add_argument("--load-config", metavar="PATH", help="print Desktop Icons config JSON, creating defaults when missing")
    parser.add_argument("--save-config", nargs=2, metavar=("PATH", "JSON"), help="atomically write Desktop Icons config JSON")
    parser.add_argument("--load-layout-state", metavar="PATH", help="print Desktop Icons layout state JSON, creating defaults when missing")
    parser.add_argument("--update-layout-state", nargs=5, metavar=("PATH", "SORT", "PRESET", "HIDDEN", "CLEAR"), help="update Desktop Icons layout state")
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
    if args.create_folder:
        print(display_path(create_folder()))
        return
    if args.load_state:
        print(json.dumps(load_state(args.load_state), ensure_ascii=False, separators=(",", ":")))
        return
    if args.save_state:
        save_state(args.save_state[0], args.save_state[1])
        return
    if args.load_config:
        print(json.dumps(load_desktop_config(args.load_config), ensure_ascii=False, separators=(",", ":")))
        return
    if args.save_config:
        save_desktop_config(args.save_config[0], args.save_config[1])
        return
    if args.load_layout_state:
        print(json.dumps(load_desktop_layout(args.load_layout_state), ensure_ascii=False, separators=(",", ":")))
        return
    if args.update_layout_state:
        update_desktop_layout(*args.update_layout_state)
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
