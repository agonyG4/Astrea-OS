#!/usr/bin/env python3
"""
Bench ScreenTime.

Tracks focused app usage on Hyprland by sampling `hyprctl activewindow -j`.
State is stored under ~/.local/state/Bench/ScreenTime.
"""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import signal
import subprocess
import sys
import time
from datetime import datetime, time as datetime_time, timedelta, timezone
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
RULES_PATH = SCRIPT_DIR / "app_rules.json"
STATE_DIR = Path.home() / ".local" / "state" / "Bench" / "ScreenTime"
STATE_PATH = STATE_DIR / "usage.json"
EVENTS_PATH = STATE_DIR / "events.jsonl"
LOCK_PATH = STATE_DIR / "monitor.lock"
DEFAULT_INTERVAL = 5.0
MAX_SAMPLE_SECONDS = 60.0
STATE_SCHEMA_VERSION = 2


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def today_key() -> str:
    return datetime.now().strftime("%Y-%m-%d")


def day_key_from_timestamp(timestamp: float) -> str:
    return datetime.fromtimestamp(timestamp).strftime("%Y-%m-%d")


def next_local_midnight(timestamp: float) -> float:
    current = datetime.fromtimestamp(timestamp)
    next_day = datetime.combine(current.date() + timedelta(days=1), datetime_time.min)
    return next_day.timestamp()


def load_json(path: Path, fallback: dict[str, Any]) -> dict[str, Any]:
    if not path.exists():
        return fallback
    try:
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else fallback
    except (OSError, json.JSONDecodeError):
        return fallback


def atomic_write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp, path)


def load_rules(path: Path = RULES_PATH) -> dict[str, Any]:
    rules = load_json(path, {})
    categories = rules.get("categories", {})
    if not isinstance(categories, dict):
        categories = {}
    return {"categories": categories, "loaded_at": now_iso()}


def normalize(value: str | None) -> str:
    return (value or "").strip().lower()


def rule_aliases(app_id: str, raw_rule: Any) -> tuple[list[str], list[str], list[str]]:
    class_aliases = [normalize(app_id)]
    title_aliases: list[str] = []
    exact_titles: list[str] = []

    if isinstance(raw_rule, list):
        class_aliases.extend(normalize(alias) for alias in raw_rule)
    elif isinstance(raw_rule, dict):
        class_aliases.extend(normalize(alias) for alias in raw_rule.get("aliases", []))
        title_aliases.extend(normalize(alias) for alias in raw_rule.get("title_aliases", []))
        exact_titles.extend(normalize(alias) for alias in raw_rule.get("exact_titles", []))

    return class_aliases, title_aliases, exact_titles


def resolve_app(raw_class: str, title: str, rules: dict[str, Any]) -> tuple[str, str, str]:
    class_key = normalize(raw_class)
    title_key = normalize(title)

    for category_id, category in rules["categories"].items():
        apps = category.get("apps", {})
        if not isinstance(apps, dict):
            continue
        for app_id, raw_rule in apps.items():
            class_aliases, title_aliases, exact_titles = rule_aliases(str(app_id), raw_rule)

            for exact_title in exact_titles:
                if exact_title and title_key == exact_title:
                    return str(app_id), str(category_id), category.get("label", str(category_id))

            for alias in title_aliases:
                if alias and title_key and alias in title_key:
                    return str(app_id), str(category_id), category.get("label", str(category_id))

            for alias in class_aliases:
                if alias and (alias == class_key or alias in class_key):
                    return str(app_id), str(category_id), category.get("label", str(category_id))

    app_id = class_key or "unknown"
    return app_id, "other", rules["categories"].get("other", {}).get("label", "Other")


def hyprctl_env() -> dict[str, str]:
    env = os.environ.copy()
    if env.get("HYPRLAND_INSTANCE_SIGNATURE"):
        return env

    runtime_dir = Path(env.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    hypr_dir = runtime_dir / "hypr"
    try:
        instances = [
            path
            for path in hypr_dir.iterdir()
            if path.is_dir() and (path / ".socket.sock").exists()
        ]
    except OSError:
        return env

    if instances:
        newest = max(instances, key=lambda path: path.stat().st_mtime)
        env["HYPRLAND_INSTANCE_SIGNATURE"] = newest.name
    return env


def focused_window() -> dict[str, Any]:
    try:
        proc = subprocess.run(
            ["hyprctl", "activewindow", "-j"],
            check=False,
            capture_output=True,
            text=True,
            timeout=2.0,
            env=hyprctl_env(),
        )
    except (FileNotFoundError, subprocess.SubprocessError):
        return {"app": "unknown", "class": "", "title": "", "address": "", "ok": False, "error": "hyprctl unavailable"}

    if proc.returncode != 0 or not proc.stdout.strip():
        err = proc.stderr.strip() or f"hyprctl exited {proc.returncode}"
        return {"app": "unknown", "class": "", "title": "", "address": "", "ok": False, "error": err}

    try:
        window = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return {"app": "unknown", "class": "", "title": "", "address": "", "ok": False, "error": "invalid hyprctl json"}

    raw_class = window.get("class") or window.get("initialClass") or ""
    title = window.get("title") or window.get("initialTitle") or ""
    return {
        "class": str(raw_class),
        "title": str(title),
        "address": str(window.get("address") or ""),
        "workspace": window.get("workspace", {}).get("name", ""),
        "ok": bool(raw_class or title),
        "error": "",
    }


def empty_state() -> dict[str, Any]:
    return {
        "schema_version": STATE_SCHEMA_VERSION,
        "created_at": now_iso(),
        "updated_at": now_iso(),
        "total_seconds": 0.0,
        "active_seconds": 0.0,
        "unknown_seconds": 0.0,
        "sample_count": 0,
        "error_count": 0,
        "days": {},
        "apps": {},
        "categories": {},
        "current": {},
        "health": {
            "running": False,
            "last_error": "",
            "last_sample_at": "",
        },
    }


def ensure_bucket(root: dict[str, Any], key: str, label: str | None = None) -> dict[str, Any]:
    bucket = root.setdefault(key, {"seconds": 0.0})
    if label:
        bucket["label"] = label
    return bucket


def migrate_state(state: dict[str, Any]) -> dict[str, Any]:
    fresh = empty_state()
    for key, value in fresh.items():
        state.setdefault(key, value)
    state["schema_version"] = STATE_SCHEMA_VERSION
    state.setdefault("health", fresh["health"])
    total = float(state.get("total_seconds", 0.0))
    if total > 0 and float(state.get("active_seconds", 0.0)) == 0 and float(state.get("unknown_seconds", 0.0)) == 0:
        state["active_seconds"] = total
    for day_bucket in state.get("days", {}).values():
        day_total = float(day_bucket.get("seconds", 0.0))
        if day_total > 0 and float(day_bucket.get("active_seconds", 0.0)) == 0 and float(day_bucket.get("unknown_seconds", 0.0)) == 0:
            day_bucket["active_seconds"] = day_total
    return state


def increment_bucket(bucket: dict[str, Any], seconds: float) -> None:
    bucket["seconds"] = round(float(bucket.get("seconds", 0.0)) + seconds, 3)


def add_seconds_to_day(state: dict[str, Any], sample: dict[str, Any], seconds: float, timestamp: float) -> None:
    if seconds <= 0:
        return

    day = day_key_from_timestamp(timestamp)
    app = sample["app"]
    category = sample["category"]

    state["total_seconds"] = round(float(state.get("total_seconds", 0.0)) + seconds, 3)
    if sample.get("ok", False):
        state["active_seconds"] = round(float(state.get("active_seconds", 0.0)) + seconds, 3)
    else:
        state["unknown_seconds"] = round(float(state.get("unknown_seconds", 0.0)) + seconds, 3)

    day_bucket = ensure_bucket(state.setdefault("days", {}), day)
    increment_bucket(day_bucket, seconds)
    if sample.get("ok", False):
        day_bucket["active_seconds"] = round(float(day_bucket.get("active_seconds", 0.0)) + seconds, 3)
    else:
        day_bucket["unknown_seconds"] = round(float(day_bucket.get("unknown_seconds", 0.0)) + seconds, 3)

    day_apps = day_bucket.setdefault("apps", {})
    day_categories = day_bucket.setdefault("categories", {})
    day_app_bucket = ensure_bucket(day_apps, app)
    increment_bucket(day_app_bucket, seconds)
    day_app_bucket["category"] = category
    day_app_bucket["class"] = sample.get("class", "")
    cat_bucket = ensure_bucket(day_categories, category, sample["category_label"])
    increment_bucket(cat_bucket, seconds)

    app_bucket = ensure_bucket(state.setdefault("apps", {}), app)
    increment_bucket(app_bucket, seconds)
    app_bucket["category"] = category
    app_bucket["class"] = sample.get("class", "")
    app_bucket["last_title"] = sample.get("title", "")
    app_bucket["last_seen_at"] = now_iso()

    category_bucket = ensure_bucket(state.setdefault("categories", {}), category, sample["category_label"])
    increment_bucket(category_bucket, seconds)


def add_elapsed(state: dict[str, Any], sample: dict[str, Any], start_ts: float, end_ts: float) -> None:
    if end_ts <= start_ts:
        return

    cursor = start_ts
    while cursor < end_ts:
        boundary = min(next_local_midnight(cursor), end_ts)
        add_seconds_to_day(state, sample, boundary - cursor, cursor)
        cursor = boundary


def append_event(previous: dict[str, Any] | None, current: dict[str, Any]) -> None:
    EVENTS_PATH.parent.mkdir(parents=True, exist_ok=True)
    event = {
        "at": now_iso(),
        "from": previous,
        "to": current,
    }
    with EVENTS_PATH.open("a", encoding="utf-8") as f:
        f.write(json.dumps(event, sort_keys=True) + "\n")


def build_sample(rules: dict[str, Any]) -> dict[str, Any]:
    window = focused_window()
    app, category, category_label = resolve_app(window.get("class", ""), window.get("title", ""), rules)
    return {
        "app": app,
        "category": category,
        "category_label": category_label,
        "class": window.get("class", ""),
        "title": window.get("title", ""),
        "address": window.get("address", ""),
        "workspace": window.get("workspace", ""),
        "ok": window.get("ok", False),
        "error": window.get("error", ""),
        "sampled_at": now_iso(),
    }


def rules_mtime(path: Path = RULES_PATH) -> float:
    try:
        return path.stat().st_mtime
    except OSError:
        return 0.0


def acquire_lock() -> Any:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    lock_file = LOCK_PATH.open("w", encoding="utf-8")
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        print("ScreenTime monitor is already running.", file=sys.stderr)
        sys.exit(2)
    lock_file.write(str(os.getpid()))
    lock_file.flush()
    return lock_file


def run_monitor(interval: float) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    _lock_file = acquire_lock()
    state = migrate_state(load_json(STATE_PATH, empty_state()))
    rules = load_rules()
    loaded_rules_mtime = rules_mtime()
    stop = False

    def handle_stop(_signum: int, _frame: Any) -> None:
        nonlocal stop
        stop = True

    signal.signal(signal.SIGINT, handle_stop)
    signal.signal(signal.SIGTERM, handle_stop)

    previous_sample = build_sample(rules)
    previous_monotonic = time.monotonic()
    previous_wall = time.time()
    state["current"] = previous_sample
    state["health"] = {
        "running": True,
        "last_error": previous_sample.get("error", ""),
        "last_sample_at": previous_sample.get("sampled_at", ""),
        "interval_seconds": interval,
        "pid": os.getpid(),
    }
    atomic_write_json(STATE_PATH, state)
    append_event(None, previous_sample)

    while not stop:
        time.sleep(interval)
        current_rules_mtime = rules_mtime()
        if current_rules_mtime != loaded_rules_mtime:
            rules = load_rules()
            loaded_rules_mtime = current_rules_mtime

        current_monotonic = time.monotonic()
        current_wall = time.time()
        elapsed = min(current_monotonic - previous_monotonic, MAX_SAMPLE_SECONDS)
        end_wall = previous_wall + elapsed
        current_sample = build_sample(rules)

        add_elapsed(state, previous_sample, previous_wall, end_wall)
        state["sample_count"] = int(state.get("sample_count", 0)) + 1
        if current_sample.get("error"):
            state["error_count"] = int(state.get("error_count", 0)) + 1
        if current_sample.get("app") != previous_sample.get("app") or current_sample.get("title") != previous_sample.get("title"):
            append_event(previous_sample, current_sample)

        state["updated_at"] = now_iso()
        state["current"] = current_sample
        state["health"] = {
            "running": True,
            "last_error": current_sample.get("error", ""),
            "last_sample_at": current_sample.get("sampled_at", ""),
            "interval_seconds": interval,
            "pid": os.getpid(),
            "rules_loaded_at": rules.get("loaded_at", ""),
        }
        atomic_write_json(STATE_PATH, state)
        previous_sample = current_sample
        previous_monotonic = current_monotonic
        previous_wall = current_wall

    state["health"]["running"] = False
    state["updated_at"] = now_iso()
    atomic_write_json(STATE_PATH, state)


def fmt_seconds(seconds: float) -> str:
    seconds = int(round(seconds))
    hours, rem = divmod(seconds, 3600)
    minutes, secs = divmod(rem, 60)
    if hours:
        return f"{hours}h {minutes:02d}m"
    if minutes:
        return f"{minutes}m {secs:02d}s"
    return f"{secs}s"


def sorted_usage(items: dict[str, Any]) -> list[tuple[str, dict[str, Any]]]:
    return sorted(items.items(), key=lambda item: float(item[1].get("seconds", 0.0)), reverse=True)


def usage_rows(items: dict[str, Any], limit: int) -> list[dict[str, Any]]:
    rows = []
    for key, bucket in sorted_usage(items)[:limit]:
        row = dict(bucket)
        row["id"] = key
        row["seconds"] = round(float(bucket.get("seconds", 0.0)), 3)
        row["duration"] = fmt_seconds(row["seconds"])
        rows.append(row)
    return rows


def snapshot(day: str | None, limit: int) -> dict[str, Any]:
    state = migrate_state(load_json(STATE_PATH, empty_state()))
    selected_day = day or today_key()
    day_root = state.get("days", {}).get(selected_day, {"seconds": 0.0, "apps": {}, "categories": {}})
    return {
        "generated_at": now_iso(),
        "state_path": str(STATE_PATH),
        "events_path": str(EVENTS_PATH),
        "rules_path": str(RULES_PATH),
        "selected_day": selected_day,
        "current": state.get("current", {}),
        "health": state.get("health", {}),
        "totals": {
            "seconds": round(float(state.get("total_seconds", 0.0)), 3),
            "active_seconds": round(float(state.get("active_seconds", 0.0)), 3),
            "unknown_seconds": round(float(state.get("unknown_seconds", 0.0)), 3),
            "duration": fmt_seconds(float(state.get("total_seconds", 0.0))),
            "active_duration": fmt_seconds(float(state.get("active_seconds", 0.0))),
            "unknown_duration": fmt_seconds(float(state.get("unknown_seconds", 0.0))),
        },
        "day": {
            "seconds": round(float(day_root.get("seconds", 0.0)), 3),
            "active_seconds": round(float(day_root.get("active_seconds", 0.0)), 3),
            "unknown_seconds": round(float(day_root.get("unknown_seconds", 0.0)), 3),
            "duration": fmt_seconds(float(day_root.get("seconds", 0.0))),
            "active_duration": fmt_seconds(float(day_root.get("active_seconds", 0.0))),
            "unknown_duration": fmt_seconds(float(day_root.get("unknown_seconds", 0.0))),
            "categories": usage_rows(day_root.get("categories", {}), limit),
            "apps": usage_rows(day_root.get("apps", {}), limit),
        },
        "all_time": {
            "categories": usage_rows(state.get("categories", {}), limit),
            "apps": usage_rows(state.get("apps", {}), limit),
        },
        "sample_count": int(state.get("sample_count", 0)),
        "error_count": int(state.get("error_count", 0)),
    }


def print_snapshot_json(day: str | None, limit: int) -> None:
    print(json.dumps(snapshot(day, limit), indent=2, sort_keys=True))


def print_report(day: str | None, limit: int) -> None:
    state = migrate_state(load_json(STATE_PATH, empty_state()))
    if day:
        root = state.get("days", {}).get(day, {})
        title = f"ScreenTime {day}"
    else:
        root = state
        title = "ScreenTime total"

    print(title)
    print(f"Total: {fmt_seconds(float(root.get('seconds', state.get('total_seconds', 0.0))))}")
    current = state.get("current", {})
    if current:
        print(f"Focused now: {current.get('app', 'unknown')} ({current.get('category', 'other')})")

    print("\nCategories")
    for category_id, bucket in sorted_usage(root.get("categories", {}))[:limit]:
        label = bucket.get("label", category_id)
        print(f"  {label}: {fmt_seconds(float(bucket.get('seconds', 0.0)))}")

    print("\nApps")
    for app_id, bucket in sorted_usage(root.get("apps", {}))[:limit]:
        category = bucket.get("category", "")
        suffix = f" [{category}]" if category else ""
        print(f"  {app_id}{suffix}: {fmt_seconds(float(bucket.get('seconds', 0.0)))}")


def reset_state() -> None:
    atomic_write_json(STATE_PATH, empty_state())
    if EVENTS_PATH.exists():
        EVENTS_PATH.unlink()


def main() -> int:
    parser = argparse.ArgumentParser(description="Track focused app usage on Hyprland.")
    sub = parser.add_subparsers(dest="command", required=True)

    monitor = sub.add_parser("monitor", help="Run the sampler loop.")
    monitor.add_argument("--interval", type=float, default=DEFAULT_INTERVAL, help="Sample interval in seconds.")

    report = sub.add_parser("report", help="Print a human-readable usage report.")
    report.add_argument("--day", help="Report a specific local day, e.g. 2026-05-01.")
    report.add_argument("--limit", type=int, default=12)

    snapshot_parser = sub.add_parser("snapshot", help="Print a UI-friendly JSON snapshot.")
    snapshot_parser.add_argument("--day", help="Snapshot a specific local day, e.g. 2026-05-01.")
    snapshot_parser.add_argument("--limit", type=int, default=12)
    snapshot_parser.add_argument("--json", action="store_true", help="Kept for QML call clarity; snapshot always prints JSON.")

    sub.add_parser("path", help="Print state file paths.")
    sub.add_parser("reset", help="Reset collected state.")

    args = parser.parse_args()
    if args.command == "monitor":
        run_monitor(max(1.0, args.interval))
    elif args.command == "report":
        print_report(args.day, args.limit)
    elif args.command == "snapshot":
        print_snapshot_json(args.day, args.limit)
    elif args.command == "path":
        print(STATE_PATH)
        print(EVENTS_PATH)
        print(RULES_PATH)
    elif args.command == "reset":
        reset_state()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
