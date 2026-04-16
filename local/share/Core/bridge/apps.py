#!/usr/bin/env python3

import configparser
import json
import os
from pathlib import Path


def resolve_icon_path(icon_name: str) -> str:
    if not icon_name:
        return ""

    candidate = Path(icon_name).expanduser()
    if candidate.is_file():
        return str(candidate)

    theme = "hicolor"
    theme_variants = [theme]

    try:
        import subprocess
        gtk = subprocess.check_output(
            ["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip().strip("'")
        if gtk:
            theme = gtk
            theme_variants = [theme]
    except Exception:
        pass

    for suffix in ["-dark", "-light", "-Dark", "-Light"]:
        if theme.endswith(suffix):
            theme_variants.append(theme[:-len(suffix)])

    base_dirs = [Path.home() / ".local/share/icons", Path("/usr/share/icons")]
    sizes = ["256x256", "128x128", "96x96", "64x64", "48x48", "32x32", "24x24", "22x22", "16x16", "scalable"]
    exts = [".svg", ".png", ".xpm"]
    subpaths = [
        "{size}/apps/{name}{ext}",
        "apps/{size}/{name}{ext}",
        "apps/scalable/{name}{ext}",
    ]

    for base in base_dirs:
        for theme_name in theme_variants:
            theme_dir = base / theme_name
            if not theme_dir.is_dir():
                continue
            for size in sizes:
                for subpath in subpaths:
                    for ext in exts:
                        candidate = theme_dir / subpath.format(size=size, name=icon_name, ext=ext)
                        if candidate.is_file():
                            return str(candidate)

    for ext in exts:
        pixmap = Path("/usr/share/pixmaps") / f"{icon_name}{ext}"
        if pixmap.is_file():
            return str(pixmap)

    return ""


def application_dirs() -> list[Path]:
    home = Path.home()
    data_home = Path(os.environ.get("XDG_DATA_HOME", home / ".local/share"))
    dirs = [data_home / "applications"]

    for entry in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":"):
        if entry:
            dirs.append(Path(entry) / "applications")

    deduped: list[Path] = []
    seen: set[str] = set()
    for path in dirs:
        key = str(path)
        if key not in seen:
            seen.add(key)
            deduped.append(path)
    return deduped


def parse_desktop_file(path: Path, source: str) -> dict | None:
    parser = configparser.ConfigParser(interpolation=None, strict=False)
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

    if entry.get("NoDisplay", "").lower() == "true":
        return None
    if entry.get("Hidden", "").lower() == "true":
        return None

    name = entry.get("Name", "").strip()
    if not name:
        return None

    exec_line = entry.get("Exec", "").strip()
    icon_name = entry.get("Icon", "").strip()
    comment = entry.get("Comment", "").strip()
    categories = [part for part in entry.get("Categories", "").split(";") if part]

    return {
        "id": path.name,
        "name": name,
        "comment": comment,
        "exec": exec_line,
        "icon": icon_name,
        "icon_path": resolve_icon_path(icon_name),
        "categories": categories,
        "desktop_file": str(path),
        "source": source,
    }


def list_apps() -> dict:
    apps_by_id: dict[str, dict] = {}

    for apps_dir in application_dirs():
        if not apps_dir.exists():
            continue

        source = "user" if str(apps_dir).startswith(str(Path.home())) else "system"
        for desktop_file in sorted(apps_dir.glob("*.desktop")):
            parsed = parse_desktop_file(desktop_file, source)
            if not parsed:
                continue
            apps_by_id[parsed["id"]] = parsed

    apps = sorted(apps_by_id.values(), key=lambda item: item["name"].lower())
    user_count = sum(1 for app in apps if app["source"] == "user")
    system_count = sum(1 for app in apps if app["source"] == "system")

    return {
        "apps": apps,
        "total": len(apps),
        "user_count": user_count,
        "system_count": system_count,
    }


def main() -> None:
    print(json.dumps(list_apps(), ensure_ascii=False))


if __name__ == "__main__":
    main()
