#!/usr/bin/env python3

from __future__ import annotations

import json
import locale
from configparser import ConfigParser
from pathlib import Path


APP_DIRS = [
    Path("/usr/share/applications"),
    Path("/usr/local/share/applications"),
    Path.home() / ".local/share/applications",
]


def locale_keys() -> list[str]:
    lang, _ = locale.getlocale()
    keys: list[str] = []
    if lang:
        normalized = lang.replace("-", "_")
        keys.append(f"Name[{normalized}]")
        if "_" in normalized:
            keys.append(f"Name[{normalized.split('_', 1)[0]}]")
    keys.append("Name")
    return keys


def parse_entry(path: Path, name_fields: list[str]) -> dict[str, str] | None:
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

    icon = entry.get("Icon", "").strip()
    exec_line = entry.get("Exec", "").strip()
    if not icon or not exec_line:
        return None

    name = ""
    for key in name_fields:
        value = entry.get(key, "").strip()
        if value:
            name = value
            break

    if not name:
        return None

    return {
        "name": name,
        "icon": icon,
        "desktop": str(path),
    }


def collect_apps() -> list[dict[str, str]]:
    name_fields = locale_keys()
    items: list[dict[str, str]] = []
    seen: set[tuple[str, str]] = set()

    for app_dir in APP_DIRS:
        if not app_dir.exists():
            continue
        for path in sorted(app_dir.glob("*.desktop")):
            item = parse_entry(path, name_fields)
            if not item:
                continue
            key = (item["name"], item["icon"])
            if key in seen:
                continue
            seen.add(key)
            items.append(item)

    items.sort(key=lambda item: item["name"].casefold())
    return items


def write_js(items: list[dict[str, str]], output_path: Path) -> None:
    payload = json.dumps(items, ensure_ascii=False, indent=2)
    output_path.write_text(f"var APPS = {payload};\n", encoding="utf-8")


def main() -> None:
    output_path = Path(__file__).with_name("apps.js")
    write_js(collect_apps(), output_path)
    print(output_path)


if __name__ == "__main__":
    main()
