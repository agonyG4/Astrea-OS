#!/usr/bin/env python3

from __future__ import annotations

import json
import locale
import argparse
import os
from configparser import ConfigParser
from pathlib import Path


MAX_APPS = 64
FALLBACK_ICON = "application-x-executable"


def xdg_desktop_dir() -> Path:
    config_path = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "user-dirs.dirs"
    fallback = Path.home() / "Desktop"

    try:
        for line in config_path.read_text(encoding="utf-8", errors="ignore").splitlines():
            line = line.strip()
            if not line.startswith("XDG_DESKTOP_DIR="):
                continue

            value = line.split("=", 1)[1].strip().strip('"')
            value = value.replace("$HOME", str(Path.home()))
            return Path(os.path.expandvars(value)).expanduser()
    except Exception:
        pass

    return fallback
def localized_keys(base: str) -> list[str]:
    lang, _ = locale.getlocale()
    keys: list[str] = []
    if lang:
        normalized = lang.replace("-", "_")
        keys.append(f"{base}[{normalized}]")
        if "_" in normalized:
            keys.append(f"{base}[{normalized.split('_', 1)[0]}]")
    keys.append(base)
    return keys


def localized_value(entry, base: str) -> str:
    for key in localized_keys(base):
        value = entry.get(key, "").strip()
        if value:
            return value
    return ""


def icon_has_localhost_reference(icon: str) -> bool:
    if "/" not in icon:
        return False

    path = Path(icon)
    try:
        return path.suffix.lower() == ".svg" and path.is_file() and "localhost:" in path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return False


def parse_entry(path: Path) -> dict[str, str] | None:
    parser = ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str

    try:
        parser.read(path, encoding="utf-8")
    except Exception:
        return None

    if "Desktop Entry" not in parser:
        return None

    entry = parser["Desktop Entry"]
    if entry.get("Type", "Application") != "Application":
        return None
    if entry.get("NoDisplay", "false").lower() == "true":
        return None
    if entry.get("Hidden", "false").lower() == "true":
        return None
    if entry.get("Terminal", "false").lower() == "true":
        return None

    name = localized_value(entry, "Name")
    icon = entry.get("Icon", "").strip()
    exec_line = entry.get("Exec", "").strip()
    if not name or not exec_line:
        return None
    if "://" in icon:
        icon = FALLBACK_ICON
    if icon_has_localhost_reference(icon):
        icon = FALLBACK_ICON
    if not icon:
        icon = FALLBACK_ICON

    return {
        "name": name,
        "generic": localized_value(entry, "GenericName"),
        "icon": icon,
        "desktop": str(path),
    }


def collect_apps() -> list[dict[str, str]]:
    items: list[dict[str, str]] = []
    seen: set[str] = set()
    desktop_dir = xdg_desktop_dir()

    if not desktop_dir.exists():
        return items

    for path in sorted(desktop_dir.glob("*.desktop")):
        item = parse_entry(path)
        if not item:
            continue

        key = Path(item["desktop"]).name
        if key in seen:
            continue

        seen.add(key)
        items.append(item)

    items.sort(key=lambda item: item["name"].casefold())
    return items


def write_js(items: list[dict[str, str]], output_path: Path) -> None:
    payload = json.dumps(items, ensure_ascii=False, indent=2)
    output_path.write_text(f"var APPS = {payload};\n", encoding="utf-8")


def write_json(items: list[dict[str, str]], output_path: Path) -> None:
    payload = json.dumps(items, ensure_ascii=False, indent=2)
    output_path.write_text(payload + "\n", encoding="utf-8")


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
