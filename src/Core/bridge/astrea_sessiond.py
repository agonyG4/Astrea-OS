#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import signal
import sys
import time
from pathlib import Path

APP_NAME = "Astrea"
STATE_ROOT = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")).expanduser() / APP_NAME
RUNTIME_ROOT = Path(os.environ.get("XDG_RUNTIME_DIR", STATE_ROOT / "runtime")).expanduser() / APP_NAME
STATUS_PATH = STATE_ROOT / "sessiond-status.json"
SOCKET_PATH = RUNTIME_ROOT / "sessiond.sock"
DEFAULT_DOMAIN_PAYLOAD = {
    "health": {"ok": True, "domain": "health", "version": 1},
}


def _now() -> float:
    return time.time()


def ensure_dirs() -> None:
    STATE_ROOT.mkdir(parents=True, exist_ok=True)
    RUNTIME_ROOT.mkdir(parents=True, exist_ok=True)


def read_status() -> dict:
    try:
        return json.loads(STATUS_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def write_status(payload: dict) -> None:
    ensure_dirs()
    tmp = STATUS_PATH.with_suffix(".tmp")
    tmp.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    os.replace(tmp, STATUS_PATH)


def is_running(status: dict | None = None) -> bool:
    status = status or read_status()
    pid = int(status.get("pid") or 0)
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def status_payload() -> dict:
    status = read_status()
    running = is_running(status)
    return {
        "ok": True,
        "service": "astrea-sessiond",
        "running": running,
        "pid": int(status.get("pid") or 0),
        "updated_at": status.get("updated_at"),
        "socket_path": str(SOCKET_PATH),
        "status_path": str(STATUS_PATH),
        "domains": sorted(DEFAULT_DOMAIN_PAYLOAD.keys()),
    }


def domain_state(name: str) -> dict:
    if name in DEFAULT_DOMAIN_PAYLOAD:
        payload = dict(DEFAULT_DOMAIN_PAYLOAD[name])
        payload["timestamp"] = _now()
        return {"ok": True, "domain": name, "state": payload}
    return {"ok": False, "code": "unknown_domain", "message": f"unknown domain: {name}"}


def run_foreground(interval: float = 2.0) -> int:
    ensure_dirs()
    running = True

    def _stop(_sig, _frame):
        nonlocal running
        running = False

    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)

    while running:
        write_status({"pid": os.getpid(), "updated_at": _now(), "socket_path": str(SOCKET_PATH)})
        time.sleep(max(0.2, interval))

    write_status({"pid": 0, "updated_at": _now(), "socket_path": str(SOCKET_PATH)})
    return 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Astrea lightweight session daemon scaffold")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("status")
    health = sub.add_parser("state")
    health.add_argument("domain", nargs="?", default="health")
    run = sub.add_parser("run")
    run.add_argument("--interval", type=float, default=2.0)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.command == "status":
        print(json.dumps(status_payload(), ensure_ascii=False))
        return 0
    if args.command == "state":
        payload = domain_state(args.domain)
        print(json.dumps(payload, ensure_ascii=False))
        return 0 if payload.get("ok") else 1
    if args.command == "run":
        return run_foreground(args.interval)
    return 1


if __name__ == "__main__":
    sys.exit(main())
