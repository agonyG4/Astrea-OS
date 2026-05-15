#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

BRIDGE_DIR = Path(__file__).resolve().parents[2] / "Core" / "bridge"
if str(BRIDGE_DIR) not in sys.path:
    sys.path.insert(0, str(BRIDGE_DIR))

from astrea_shared import FALLBACK_ICON, atomic_write_json, atomic_write_text, parse_desktop_file, xdg_desktop_dir

MAX_APPS = 64


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


def write_js(items: list[dict[str, str]], output_path: Path) -> None:
    payload = json.dumps(items, ensure_ascii=False, indent=2)
    atomic_write_text(output_path, f"var APPS = {payload};\n")


def write_json(items: list[dict[str, str]], output_path: Path) -> None:
    atomic_write_json(output_path, items, indent=2)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate the desktop icon list from the XDG desktop folder.")
    parser.add_argument("--json", action="store_true", help="print the generated app list as JSON")
    parser.add_argument("--write", action="store_true", help="write apps.js and apps.json")
    parser.add_argument("--max-apps", type=int, default=MAX_APPS, help="maximum number of apps to emit")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
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
