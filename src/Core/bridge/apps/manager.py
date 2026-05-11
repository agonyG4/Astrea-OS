#!/usr/bin/env python3

import argparse
import json
import shutil
import stat
import subprocess
import sys
from pathlib import Path

BRIDGE_DIR = Path(__file__).resolve().parents[1]
if str(BRIDGE_DIR) not in sys.path:
    sys.path.insert(0, str(BRIDGE_DIR))

from astrea_shared import application_dirs, parse_desktop_file, xdg_desktop_dir

def is_protected_app(app: dict) -> bool:
    app_id = (app.get("id") or "").casefold()
    desktop_file = (app.get("desktop_file") or "").casefold()
    name = (app.get("name") or "").casefold()
    return (
        app_id == "astrea-settings.desktop"
        or desktop_file.endswith("/astrea-settings.desktop")
        or name in {"astrea settings", "settings"} and app_id.startswith("astrea-settings")
    )



def list_apps() -> dict:
    apps_by_id: dict[str, dict] = {}

    for apps_dir in application_dirs():
        if not apps_dir.exists():
            continue

        source = "user" if str(apps_dir).startswith(str(Path.home())) else "system"
        for desktop_file in sorted(apps_dir.glob("*.desktop")):
            parsed = parse_desktop_file(desktop_file, source=source)
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
        parsed = parse_desktop_file(path, source="user" if str(path).startswith(str(Path.home())) else "system")
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
