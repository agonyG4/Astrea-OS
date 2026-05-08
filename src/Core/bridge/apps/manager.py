#!/usr/bin/env python3

import argparse
import configparser
import json
import os
import shutil
import stat
import subprocess
import sys
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


def is_protected_app(app: dict) -> bool:
    app_id = (app.get("id") or "").casefold()
    desktop_file = (app.get("desktop_file") or "").casefold()
    name = (app.get("name") or "").casefold()
    return (
        app_id == "astrea-settings.desktop"
        or desktop_file.endswith("/astrea-settings.desktop")
        or name in {"astrea settings", "settings"} and app_id.startswith("astrea-settings")
    )


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
        "protected": path.name == "astrea-settings.desktop",
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


def find_app(identifier: str) -> dict:
    needle = str(Path(identifier).expanduser()) if "/" in identifier else identifier

    for app in list_apps()["apps"]:
        if identifier == app["id"] or needle == app["desktop_file"]:
            return app

    path = Path(identifier).expanduser()
    if path.is_file():
        parsed = parse_desktop_file(path, "user" if str(path).startswith(str(Path.home())) else "system")
        if parsed:
            return parsed

    raise FileNotFoundError(f"App não encontrado: {identifier}")


def refresh_desktop_index() -> None:
    script = Path.home() / ".local/share/Astrea/Quickshell/desktop/app_index.py"
    if script.is_file():
        subprocess.run(["python3", str(script), "--json", "--write"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def create_desktop_shortcut(source: Path, desktop_dir: Path | None = None) -> dict:
    source = source.expanduser()
    if not source.is_file():
        raise FileNotFoundError(f"Desktop file não existe: {source}")

    desktop_dir = desktop_dir or xdg_desktop_dir()
    desktop_dir.mkdir(parents=True, exist_ok=True)
    target = desktop_dir / source.name
    shutil.copy2(source, target)
    target.chmod(target.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    refresh_desktop_index()
    return {"ok": True, "message": "Atalho criado na area de trabalho", "target": str(target)}


def open_location(path: Path) -> dict:
    target = path.expanduser()
    if target.is_file():
        target = target.parent
    if not target.exists():
        raise FileNotFoundError(f"Local não encontrado: {target}")

    subprocess.Popen(["xdg-open", str(target)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return {"ok": True, "message": "Local do arquivo aberto", "target": str(target)}


def uninstall_app(app: dict) -> dict:
    if is_protected_app(app):
        raise PermissionError("Settings é protegido e não pode ser desinstalado")

    desktop_file = Path(app["desktop_file"]).expanduser()
    if app.get("source") == "user" and desktop_file.is_file():
        desktop_file.unlink()
        refresh_desktop_index()
        return {"ok": True, "message": "App removido da lista de aplicativos", "target": str(desktop_file)}

    raise PermissionError("Este app é do sistema. Desinstale pelo gerenciador de pacotes.")


def action_result(action: str, identifier: str) -> dict:
    app = find_app(identifier)
    if action == "create-shortcut":
        return create_desktop_shortcut(Path(app["desktop_file"]))
    if action == "open-location":
        return open_location(Path(app["desktop_file"]))
    if action == "uninstall":
        return uninstall_app(app)
    raise ValueError(f"Ação desconhecida: {action}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="List and manage desktop applications for Astrea Settings.")
    parser.add_argument("action", nargs="?", default="list", choices=["list", "create-shortcut", "open-location", "uninstall"])
    parser.add_argument("identifier", nargs="?")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    try:
        if args.action == "list":
            result = list_apps()
        else:
            if not args.identifier:
                raise ValueError("Identificador do app ausente")
            result = action_result(args.action, args.identifier)
        print(json.dumps(result, ensure_ascii=False))
    except Exception as exc:
        print(json.dumps({"ok": False, "message": str(exc)}, ensure_ascii=False))
        sys.exit(1)


if __name__ == "__main__":
    main()
