#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import subprocess
import time
from pathlib import Path

DEFAULT_CONFIG = {
    "enabled": True,
    "always_on_top": True,
    "music": True,
    "show_gamemode_notify": False,
    "style": "Notch",
}


def emit(payload: str) -> None:
    print(payload, flush=True)


def compact_json(text: str) -> str:
    return json.dumps(json.loads(text or "{}"), ensure_ascii=False, separators=(",", ":"))


def ensure_config(path: Path, legacy: Path) -> str:
    path = path.expanduser()
    legacy = legacy.expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        return compact_json(path.read_text(encoding="utf-8"))
    if legacy.exists():
        payload = compact_json(legacy.read_text(encoding="utf-8"))
    else:
        payload = json.dumps(DEFAULT_CONFIG, ensure_ascii=False, separators=(",", ":"))
    path.write_text(payload + "\n", encoding="utf-8")
    return payload


def monitor_config(path_text: str, legacy_text: str) -> None:
    path = Path(path_text)
    legacy = Path(legacy_text)
    last_payload = ""
    last_mtime: int | None = None

    while True:
        try:
            stat = path.expanduser().stat()
            mtime = stat.st_mtime_ns
        except OSError:
            mtime = -1

        if mtime != last_mtime:
            try:
                payload = ensure_config(path, legacy)
                if payload != last_payload:
                    emit(payload)
                    last_payload = payload
                last_mtime = path.expanduser().stat().st_mtime_ns
            except Exception:
                last_mtime = mtime

        time.sleep(1)


def gamemode_state() -> str:
    try:
        proc = subprocess.run(["gamemoded", "-s"], text=True, capture_output=True, timeout=2, check=False)
        if "is active" in proc.stdout:
            return "active"
    except Exception:
        pass
    return "inactive"


def monitor_gamemode(status_path_text: str = "/tmp/gamemode_status") -> None:
    status_path = Path(status_path_text)
    last = ""
    last_mtime: int | None = None

    initial = gamemode_state()
    emit(initial)
    last = initial

    while True:
        try:
            stat = status_path.stat()
            mtime = stat.st_mtime_ns
        except OSError:
            mtime = -1

        if mtime != last_mtime:
            last_mtime = mtime
            try:
                current = status_path.read_text(encoding="utf-8").strip() if status_path.exists() else gamemode_state()
            except OSError:
                current = gamemode_state()
            current = "active" if current == "active" else "inactive"
            if current != last:
                emit(current)
                last = current

        time.sleep(1)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Monitor Astrea Island state.")
    sub = parser.add_subparsers(dest="command", required=True)

    ensure = sub.add_parser("ensure-config", help="ensure island config JSON exists")
    ensure.add_argument("path")
    ensure.add_argument("legacy")

    config = sub.add_parser("config", help="monitor island config JSON")
    config.add_argument("path")
    config.add_argument("legacy")

    gamemode = sub.add_parser("gamemode", help="monitor gamemode state")
    gamemode.add_argument("status_path", nargs="?", default="/tmp/gamemode_status")

    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.command == "ensure-config":
        emit(ensure_config(Path(args.path), Path(args.legacy)))
    elif args.command == "config":
        monitor_config(args.path, args.legacy)
    elif args.command == "gamemode":
        monitor_gamemode(args.status_path)


if __name__ == "__main__":
    main()
