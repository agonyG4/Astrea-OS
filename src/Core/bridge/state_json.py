#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from astrea_shared import atomic_write_text


def read_json_text(path_text: str) -> str:
    path = Path(path_text).expanduser()
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return ""


def write_json_text(path_text: str, payload: str) -> None:
    json.loads(payload or "{}")
    atomic_write_text(Path(path_text).expanduser(), payload + "\n")


def read_or_init_json_text(path_text: str, default_payload: str, legacy_path_text: str = "") -> str:
    path = Path(path_text).expanduser()
    if path.exists():
        return read_json_text(path_text)

    payload = default_payload
    legacy_path = Path(legacy_path_text).expanduser() if legacy_path_text else None
    if legacy_path and legacy_path.exists():
        legacy_text = legacy_path.read_text(encoding="utf-8")
        json.loads(legacy_text or "{}")
        payload = legacy_text.strip()
    else:
        json.loads(default_payload or "{}")

    atomic_write_text(path, payload.strip() + "\n")
    return payload


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Read or atomically write JSON state files.")
    sub = parser.add_subparsers(dest="command", required=True)

    read = sub.add_parser("read", help="print a JSON state file if it exists")
    read.add_argument("path")

    write = sub.add_parser("write", help="atomically write a JSON payload")
    write.add_argument("path")
    write.add_argument("payload", nargs="?", default=None)
    write.add_argument("--stdin", action="store_true", dest="use_stdin")

    read_or_init = sub.add_parser("read-or-init", help="print a JSON file, creating it from defaults when missing")
    read_or_init.add_argument("path")
    read_or_init.add_argument("default_payload")
    read_or_init.add_argument("legacy_path", nargs="?")

    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.command == "read":
        text = read_json_text(args.path).strip()
        if text:
            print(text)
        return
    if args.command == "write":
        payload = sys.stdin.read() if args.use_stdin else (args.payload or "")
        write_json_text(args.path, payload)
        return
    if args.command == "read-or-init":
        text = read_or_init_json_text(args.path, args.default_payload, args.legacy_path or "").strip()
        if text:
            print(text)


if __name__ == "__main__":
    main()
