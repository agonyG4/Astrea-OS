#!/usr/bin/env python3

import argparse
import configparser
import importlib.util
import json
import shutil
import shlex
import stat
import subprocess
import sys
from pathlib import Path


def _load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


BRIDGE_DIR = Path(__file__).resolve().parents[1]
_shared = _load_module("astrea_shared_runtime", BRIDGE_DIR / "astrea_shared.py")
_uninstall = _load_module("apps_uninstall_runtime", Path(__file__).with_name("app_uninstall.py"))

application_dirs = _shared.application_dirs
astrea_root = _shared.astrea_root
parse_desktop_file = _shared.parse_desktop_file
xdg_desktop_dir = _shared.xdg_desktop_dir

is_protected_app = _uninstall.is_protected_app
is_steam_game_app = _uninstall.is_steam_game_app
build_uninstall_info = _uninstall.uninstall_info

CAMERA_PORTAL_NAME = "org.freedesktop.portal.Camera"


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


def desktop_entry(path: Path) -> configparser.SectionProxy | None:
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    try:
        parser.read(path, encoding="utf-8")
    except Exception:
        return None
    return parser["Desktop Entry"] if "Desktop Entry" in parser else None


def flatpak_app_id(app: dict) -> str:
    entry = desktop_entry(Path(app.get("desktop_file", "")))
    if entry:
        app_id = entry.get("X-Flatpak", "").strip()
        if app_id:
            return app_id

    try:
        tokens = shlex.split(app.get("exec", ""))
    except ValueError:
        tokens = []
    if len(tokens) >= 3 and Path(tokens[0]).name == "flatpak" and tokens[1] == "run":
        for token in tokens[2:]:
            if token.startswith("-") or token.startswith("@@"):
                continue
            if "." in token:
                return token
    return ""


def command_output(command: list[str], *, timeout: float = 3.0) -> str:
    return subprocess.check_output(command, stderr=subprocess.DEVNULL, text=True, timeout=timeout).strip()


def format_bytes(size: int | None) -> str:
    if size is None:
        return "Não disponível"
    units = ["B", "KB", "MB", "GB", "TB"]
    value = float(size)
    unit = units[0]
    for unit in units:
        if value < 1024 or unit == units[-1]:
            break
        value /= 1024
    return f"{value:.1f} {unit}" if unit != "B" else f"{int(value)} B"


def directory_size(path: Path) -> int | None:
    try:
        output = command_output(["du", "-sb", str(path)], timeout=4)
        return int(output.split()[0])
    except Exception:
        return None


def acf_value(text: str, key: str) -> str:
    needle = f'"{key}"'
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith(needle):
            continue
        parts = line.split('"')
        if len(parts) >= 4:
            return parts[3]
    return ""


def steam_app_id(app: dict) -> str:
    exec_line = app.get("exec") or ""
    marker = "steam://rungameid/"
    if marker in exec_line:
        tail = exec_line.split(marker, 1)[1]
        return "".join(ch for ch in tail if ch.isdigit())
    icon = app.get("icon") or ""
    if icon.startswith("steam_icon_"):
        return "".join(ch for ch in icon.removeprefix("steam_icon_") if ch.isdigit())
    return ""


def steam_library_dirs() -> list[Path]:
    roots = [
        Path.home() / ".local/share/Steam",
        Path.home() / ".steam/steam",
    ]
    libraries: list[Path] = []
    seen: set[str] = set()

    def add(path: Path) -> None:
        key = str(path.expanduser())
        if key not in seen:
            seen.add(key)
            libraries.append(Path(key))

    for root in roots:
        if (root / "steamapps").is_dir():
            add(root)
        for vdf in [root / "config/libraryfolders.vdf", root / "steamapps/libraryfolders.vdf"]:
            try:
                text = vdf.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for line in text.splitlines():
                value = acf_value(line, "path")
                if value:
                    add(Path(value))
    return libraries


def steam_game_size(app: dict) -> dict | None:
    app_id = steam_app_id(app)
    if not app_id:
        return None

    for library in steam_library_dirs():
        manifest = library / "steamapps" / f"appmanifest_{app_id}.acf"
        try:
            text = manifest.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue

        raw_size = acf_value(text, "SizeOnDisk")
        if raw_size.isdigit() and int(raw_size) > 0:
            size = int(raw_size)
            return {"label": format_bytes(size), "bytes": size, "source": f"steam:{app_id}"}

        installdir = acf_value(text, "installdir")
        if installdir:
            size = directory_size(library / "steamapps/common" / installdir)
            if size is not None:
                return {"label": format_bytes(size), "bytes": size, "source": f"steam:{app_id}"}
    return None


def executable_path(app: dict) -> Path | None:
    try:
        tokens = shlex.split(app.get("exec", ""))
    except ValueError:
        return None
    if not tokens:
        return None
    first = tokens[0]
    if first == "env" or first.endswith("/env"):
        for token in tokens[1:]:
            if "=" in token:
                continue
            first = token
            break
    resolved = Path(first).expanduser() if "/" in first else Path(shutil.which(first) or "")
    return resolved if str(resolved) else None


def pacman_owner(path: Path) -> str:
    try:
        output = command_output(["pacman", "-Qo", str(path)], timeout=3)
    except Exception:
        return ""
    marker = " is owned by "
    if marker not in output:
        return ""
    owned = output.split(marker, 1)[1].strip()
    return owned.rsplit(" ", 1)[0]


def pacman_installed_size(package: str) -> str:
    if not package:
        return ""
    try:
        output = command_output(["pacman", "-Qi", package], timeout=3)
    except Exception:
        return ""
    for line in output.splitlines():
        if line.startswith("Installed Size"):
            return line.split(":", 1)[1].strip()
    return ""


def astrea_app_dir(app: dict) -> Path | None:
    mapping = {
        "astrea-settings.desktop": "Settings",
        "astrea-weather.desktop": "Weather",
        "astrea-explorer.desktop": "Explorer",
    }
    app_dir = mapping.get(app.get("id", ""))
    if not app_dir:
        return None
    path = astrea_root() / "Apps" / app_dir
    return path if path.is_dir() else None


def app_size(app: dict, fp_id: str) -> dict:
    if fp_id:
        try:
            size = int(command_output(["flatpak", "info", "--show-size", fp_id], timeout=4))
            return {"label": format_bytes(size), "bytes": size, "source": "flatpak"}
        except Exception:
            return {"label": "Não disponível", "bytes": None, "source": "flatpak"}

    steam_size = steam_game_size(app)
    if steam_size:
        return steam_size

    desktop_file = Path(app.get("desktop_file", "")).expanduser()
    owner = pacman_owner(desktop_file)
    if owner:
        label = pacman_installed_size(owner)
        if label:
            return {"label": label, "bytes": None, "source": f"pacman:{owner}"}

    astrea_dir = astrea_app_dir(app)
    if astrea_dir:
        size = directory_size(astrea_dir)
        return {"label": format_bytes(size), "bytes": size, "source": str(astrea_dir)}

    exe = executable_path(app)
    if exe and exe.exists() and str(exe).startswith(str(Path.home())):
        if exe.parent == Path.home() / ".local/bin":
            return {"label": "Não disponível", "bytes": None, "source": str(exe)}
        target = exe.parent if exe.is_file() else exe
        size = directory_size(target)
        return {"label": format_bytes(size), "bytes": size, "source": str(target)}

    if desktop_file.is_file():
        return {"label": format_bytes(desktop_file.stat().st_size), "bytes": desktop_file.stat().st_size, "source": "desktop-file"}
    return {"label": "Não disponível", "bytes": None, "source": ""}


def flatpak_installation(app: dict) -> str:
    desktop_file = Path(app.get("desktop_file", "")).expanduser()
    home_flatpak = Path.home() / ".local/share/flatpak"
    try:
        if desktop_file.is_relative_to(home_flatpak):
            return "user"
        if desktop_file.is_relative_to(Path("/var/lib/flatpak")):
            return "system"
    except ValueError:
        pass
    return "system"


def package_owner(app: dict) -> str:
    desktop_file = Path(app.get("desktop_file", "")).expanduser()
    owner = pacman_owner(desktop_file)
    if owner:
        return owner

    exe = executable_path(app)
    if exe and exe.exists():
        return pacman_owner(exe)
    return ""


def uninstall_info(app: dict, fp_id: str = "") -> dict:
    return build_uninstall_info(
        app,
        flatpak_id=fp_id or flatpak_app_id(app),
        flatpak_installation=flatpak_installation(app),
        package_owner=package_owner(app),
    )


def flatpak_override_text(fp_id: str) -> str:
    try:
        return command_output(["flatpak", "override", "--user", "--show", fp_id], timeout=3)
    except Exception:
        return ""


def override_values(text: str, key: str) -> list[str]:
    values: list[str] = []
    for line in text.splitlines():
        if not line.startswith(f"{key}="):
            continue
        values.extend(part.strip() for part in line.split("=", 1)[1].split(";") if part.strip())
    return values


def camera_blocked(text: str) -> bool:
    for line in text.splitlines():
        if line.startswith(f"{CAMERA_PORTAL_NAME}="):
            return line.split("=", 1)[1].strip().lower() in {"none", "no", "false"}
    return f"!{CAMERA_PORTAL_NAME}" in text


def build_permissions(app: dict, fp_id: str) -> list[dict]:
    if not fp_id:
        return [
            {
                "id": "microphone",
                "name": "Microfone",
                "blocked": False,
                "supported": False,
                "description": "Apps nativos não têm sandbox de microfone por app neste sistema.",
            },
            {
                "id": "camera",
                "name": "Câmera",
                "blocked": False,
                "supported": False,
                "description": "Apps nativos não têm sandbox de câmera por app neste sistema.",
            },
        ]

    overrides = flatpak_override_text(fp_id)
    sockets = override_values(overrides, "sockets")
    return [
        {
            "id": "microphone",
            "name": "Microfone",
            "blocked": "!pulseaudio" in sockets,
            "supported": True,
            "description": "Bloqueia o socket de áudio do Flatpak. Vale a partir do próximo lançamento do app.",
        },
        {
            "id": "camera",
            "name": "Câmera",
            "blocked": camera_blocked(overrides),
            "supported": True,
            "description": "Bloqueia o portal de câmera do Flatpak. Vale a partir do próximo lançamento do app.",
        },
    ]


def app_details(app: dict) -> dict:
    fp_id = flatpak_app_id(app)
    details = dict(app)
    details["flatpak_id"] = fp_id
    details["install_type"] = "Flatpak" if fp_id else ("Usuário" if app.get("source") == "user" else "Sistema")
    details["size"] = app_size(app, fp_id)
    details["permissions"] = build_permissions(app, fp_id)
    details["uninstall"] = uninstall_info(app, fp_id)
    return {"ok": True, "app": details}


def set_permission(app: dict, permission: str, blocked: bool) -> dict:
    fp_id = flatpak_app_id(app)
    if not fp_id:
        raise PermissionError("Este app não tem sandbox por app. Bloqueio individual só é suportado para Flatpak.")

    if permission == "microphone":
        option = "--nosocket=pulseaudio" if blocked else "--socket=pulseaudio"
    elif permission == "camera":
        option = f"--no-talk-name={CAMERA_PORTAL_NAME}" if blocked else f"--talk-name={CAMERA_PORTAL_NAME}"
    else:
        raise ValueError(f"Permissão desconhecida: {permission}")

    subprocess.run(["flatpak", "override", "--user", option, fp_id], check=True)
    state = "bloqueado" if blocked else "liberado"
    return {"ok": True, "message": f"{permission} {state} para {app.get('name', fp_id)}", "app": app_details(app)["app"]}


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

    launcher = astrea_root() / "bin" / "astrea-launch"
    command = [str(launcher), "--file", str(target)] if launcher.is_file() else ["xdg-open", str(target)]
    subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return {"ok": True, "message": "Local do arquivo aberto", "target": str(target)}


def uninstall_app(app: dict) -> dict:
    info = uninstall_info(app)
    if not info.get("can"):
        raise PermissionError(info.get("reason") or "Este app não pode ser desinstalado por aqui.")

    if info.get("method") == "flatpak":
        fp_id = info["flatpak_id"]
        command = ["flatpak", "uninstall", "--assumeyes", "--app"]
        if info.get("installation") == "user":
            command.append("--user")
        command.append(fp_id)
        try:
            subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        except subprocess.CalledProcessError as exc:
            detail = (exc.stderr or "").strip()
            raise RuntimeError(detail or f"Falha ao desinstalar Flatpak {fp_id}") from exc
        refresh_desktop_index()
        return {"ok": True, "message": "App Flatpak desinstalado", "target": fp_id}

    if info.get("method") == "system-package":
        package = info.get("package", "")
        if not package:
            raise PermissionError("Não foi possível identificar o pacote Pacman deste app.")
        command = ["pkexec", "pacman", "-Rns", "--noconfirm", package]
        try:
            subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        except subprocess.CalledProcessError as exc:
            detail = (exc.stderr or "").strip()
            raise RuntimeError(detail or f"Falha ao desinstalar pacote {package}") from exc
        except FileNotFoundError as exc:
            raise RuntimeError("pkexec não está disponível para pedir autenticação.") from exc
        refresh_desktop_index()
        return {"ok": True, "message": f"Pacote {package} desinstalado", "target": package}

    desktop_file = Path(app["desktop_file"]).expanduser()
    if info.get("method") == "desktop-file" and desktop_file.is_file():
        desktop_file.unlink()
        refresh_desktop_index()
        return {"ok": True, "message": "Launcher removido da lista de aplicativos", "target": str(desktop_file)}

    raise PermissionError(info.get("reason") or "Este app não pode ser desinstalado por aqui.")


def action_result(action: str, identifier: str, permission: str = "", value: str = "") -> dict:
    app = find_app(identifier)
    if action == "details":
        return app_details(app)
    if action == "create-shortcut":
        return create_desktop_shortcut(Path(app["desktop_file"]))
    if action == "open-location":
        return open_location(Path(app["desktop_file"]))
    if action == "uninstall":
        return uninstall_app(app)
    if action == "set-permission":
        if not permission:
            raise ValueError("Permissão ausente")
        return set_permission(app, permission, value == "blocked")
    raise ValueError(f"Ação desconhecida: {action}")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="List and manage desktop applications for Astrea Settings.")
    parser.add_argument("action", nargs="?", default="list")
    parser.add_argument("identifier", nargs="?")
    parser.add_argument("permission", nargs="?")
    parser.add_argument("value", nargs="?")
    args, _unknown = parser.parse_known_args(argv)
    return args


def main(argv: list[str] | None = None) -> int:
    effective_argv = argv if argv is not None else sys.argv[1:]
    if effective_argv and str(effective_argv[0]).endswith(".py"):
        return 0
    args = parse_args(argv)
    try:
        if args.action == "list":
            result = list_apps()
        else:
            if not args.identifier:
                raise ValueError("Identificador do app ausente")
            result = action_result(args.action, args.identifier, args.permission or "", args.value or "")
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except Exception as exc:
        print(json.dumps({"ok": False, "message": str(exc)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    sys.exit(main())
