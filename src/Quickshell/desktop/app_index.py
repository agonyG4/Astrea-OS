#!/usr/bin/env python3

from __future__ import annotations

import argparse
import ctypes
import json
import os
import re
import select
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

BRIDGE_DIR = Path(__file__).resolve().parents[2] / "Core" / "bridge"


def _load_astrea_shared():
    import importlib.util
    spec = importlib.util.spec_from_file_location("astrea_shared_runtime", BRIDGE_DIR / "astrea_shared.py")
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module

ASTREA_SHARED = _load_astrea_shared()

FALLBACK_ICON = ASTREA_SHARED.FALLBACK_ICON
atomic_write_json = ASTREA_SHARED.atomic_write_json
atomic_write_text = ASTREA_SHARED.atomic_write_text
parse_desktop_file = ASTREA_SHARED.parse_desktop_file
xdg_desktop_dir = ASTREA_SHARED.xdg_desktop_dir

MAX_APPS = 64
MAX_ICON_ASSET_BYTES = 2 * 1024 * 1024
DESKTOP_CONFIG_DEFAULT = {"enabled": True}
DESKTOP_STATE_DEFAULT = {"sortMode": "name", "iconPreset": "medium", "iconsHidden": False, "positions": {}}
IN_CLOSE_WRITE = 0x00000008
IN_MOVED_TO = 0x00000080
IN_CREATE = 0x00000100
IN_DELETE = 0x00000200
IN_DELETE_SELF = 0x00000400
IN_MOVE_SELF = 0x00000800
IN_ONLYDIR = 0x01000000
IN_NONBLOCK = 0x00000800
IN_CLOEXEC = 0x00080000
WATCH_MASK = IN_CLOSE_WRITE | IN_MOVED_TO | IN_CREATE | IN_DELETE | IN_DELETE_SELF | IN_MOVE_SELF


def display_path(path: Path) -> str:
    raw = str(path)
    home_prefix = str(Path.home())
    if raw == home_prefix:
        return "$HOME"
    if raw.startswith(home_prefix + "/"):
        return "$HOME/" + raw[len(home_prefix) + 1:]
    return raw


def file_url(path: Path | str) -> str:
    return Path(path).expanduser().resolve().as_uri()


def steam_appid(parsed: dict[str, str]) -> str:
    exec_line = str(parsed.get("exec") or "")
    icon = str(parsed.get("icon") or "")

    match = re.search(r"steam://rungameid/(\d+)", exec_line)
    if match:
        return match.group(1)

    match = re.fullmatch(r"steam_icon_(\d+)", icon)
    return match.group(1) if match else ""


def steam_root() -> Path:
    return Path.home() / ".local/share/Steam"


def hicolor_icon_path(appid: str, size: int) -> Path:
    return Path.home() / ".local/share/icons/hicolor" / f"{size}x{size}" / "apps" / f"steam_icon_{appid}.png"


def atomic_copy_file(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_name(f".{target.name}.{os.getpid()}.tmp")
    tmp.unlink(missing_ok=True)
    try:
        shutil.copyfile(source, tmp)
        os.replace(tmp, target)
    except OSError:
        tmp.unlink(missing_ok=True)
        raise


def atomic_write_bytes(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    tmp.unlink(missing_ok=True)
    try:
        tmp.write_bytes(data)
        os.replace(tmp, path)
    except OSError:
        tmp.unlink(missing_ok=True)
        raise


def update_icon_cache() -> None:
    command = shutil.which("gtk-update-icon-cache")
    if not command:
        return
    subprocess.run(
        [command, "-f", "-t", str(Path.home() / ".local/share/icons/hicolor")],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=5,
        check=False,
    )


def appinfo_hash_candidates(appid: str, name: str = "") -> list[str]:
    path = steam_root() / "appcache/appinfo.vdf"
    try:
        data = path.read_bytes()
    except OSError:
        return []

    candidates: list[str] = []

    markers = []
    if name:
        markers.append(name.encode("utf-8", errors="ignore"))
    markers.append(appid.encode("ascii", errors="ignore"))

    for marker in markers:
        start = 0
        while marker:
            index = data.find(marker, start)
            if index < 0:
                break
            chunk = data[max(0, index - 1024): index + 4096]
            for raw in re.findall(rb"[0-9a-f]{40}", chunk):
                value = raw.decode("ascii")
                if value not in candidates:
                    candidates.append(value)
            start = index + len(marker)

    return candidates


def download_steam_icon_asset(appid: str, hash_value: str, ext: str, target: Path) -> bool:
    url = f"https://cdn.cloudflare.steamstatic.com/steamcommunity/public/images/apps/{appid}/{hash_value}.{ext}"
    request = urllib.request.Request(url, headers={"User-Agent": "AstreaDesktopIcons/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=3) as response:
            data = response.read(MAX_ICON_ASSET_BYTES + 1)
    except (OSError, urllib.error.URLError, urllib.error.HTTPError, TimeoutError):
        return False

    if len(data) > MAX_ICON_ASSET_BYTES:
        return False
    if ext == "ico" and not data.startswith(b"\x00\x00\x01\x00"):
        return False
    if ext == "zip" and not data.startswith(b"PK"):
        return False

    try:
        atomic_write_bytes(target, data)
        return True
    except OSError:
        return False


def steam_icon_assets(appid: str, name: str = "") -> list[Path]:
    games_dir = steam_root() / "steam/games"
    assets: list[Path] = []
    seen: set[str] = set()
    candidates = appinfo_hash_candidates(appid, name)

    for hash_value in candidates:
        for ext in ("ico", "zip"):
            path = games_dir / f"{hash_value}.{ext}"
            if path.is_file() and str(path) not in seen:
                assets.append(path)
                seen.add(str(path))

    for hash_value in candidates:
        for ext in ("ico", "zip"):
            path = games_dir / f"{hash_value}.{ext}"
            if str(path) in seen:
                continue
            try:
                games_dir.mkdir(parents=True, exist_ok=True)
            except OSError:
                continue
            if download_steam_icon_asset(appid, hash_value, ext, path):
                assets.append(path)
                seen.add(str(path))

    return assets


def install_png_icon(appid: str, source: Path, size: int) -> bool:
    target = hicolor_icon_path(appid, size)
    try:
        atomic_copy_file(source, target)
        return True
    except OSError:
        return False


def install_zip_icon(appid: str, path: Path) -> bool:
    installed = False
    try:
        with zipfile.ZipFile(path) as archive:
            for name in archive.namelist():
                match = re.search(r"icon[_-](\d+)(?:px)?\.png$", name, flags=re.IGNORECASE)
                if not match:
                    continue
                size = int(match.group(1))
                if size not in {16, 24, 32, 48, 64, 96, 128, 256}:
                    continue
                info = archive.getinfo(name)
                if info.file_size > MAX_ICON_ASSET_BYTES:
                    continue
                with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as handle:
                    handle.write(archive.read(info))
                    temp_path = Path(handle.name)
                try:
                    installed = install_png_icon(appid, temp_path, size) or installed
                finally:
                    temp_path.unlink(missing_ok=True)
    except (OSError, zipfile.BadZipFile, KeyError):
        return False
    return installed


def install_ico_icon(appid: str, path: Path) -> bool:
    magick = shutil.which("magick")
    if not magick:
        return False

    try:
        result = subprocess.run(
            [magick, "identify", "-format", "%p %w %h\n", str(path)],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    if result.returncode != 0:
        return False

    frames: list[tuple[int, int]] = []
    for line in result.stdout.splitlines():
        match = re.match(r"(\d+)\s+(\d+)\s+(\d+)", line.strip())
        if not match:
            continue
        index, width, height = map(int, match.groups())
        if width == height and width in {16, 24, 32, 48, 64, 96, 128, 256}:
            frames.append((width, index))
    if not frames:
        return False

    installed = False
    for size, index in sorted(frames, reverse=True):
        target = hicolor_icon_path(appid, size)
        temp_target = target.with_name(f".{target.name}.{os.getpid()}.tmp")
        try:
            target.parent.mkdir(parents=True, exist_ok=True)
            temp_target.unlink(missing_ok=True)
            result = subprocess.run(
                [magick, f"{path}[{index}]", str(temp_target)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=5,
                check=False,
            )
            if result.returncode == 0:
                os.replace(temp_target, target)
                installed = True
            else:
                temp_target.unlink(missing_ok=True)
        except (OSError, subprocess.TimeoutExpired):
            temp_target.unlink(missing_ok=True)
            continue
    return installed


def ensure_steam_icon(appid: str, name: str = "") -> str:
    icon_name = f"steam_icon_{appid}"
    existing = ASTREA_SHARED.resolve_icon_path(icon_name)
    if existing:
        return existing

    installed = False
    for asset in steam_icon_assets(appid, name):
        if asset.suffix.lower() == ".zip":
            installed = install_zip_icon(appid, asset) or installed
        elif asset.suffix.lower() == ".ico":
            installed = install_ico_icon(appid, asset) or installed
        if installed:
            break

    if installed:
        update_icon_cache()
        return ASTREA_SHARED.resolve_icon_path(icon_name)
    return ""


def icon_source_for(parsed: dict[str, str]) -> str:
    appid = steam_appid(parsed)

    if appid:
        steam_icon_path = ensure_steam_icon(appid, str(parsed.get("name") or ""))
        if steam_icon_path:
            return file_url(steam_icon_path)

    icon_path = str(parsed.get("icon_path") or "")
    if icon_path:
        return file_url(icon_path)

    return ""


def next_folder_path(desktop_dir: Path, base_name: str = "Nova Pasta") -> Path:
    candidate = desktop_dir / base_name
    if not candidate.exists():
        return candidate

    index = 2
    while True:
        candidate = desktop_dir / f"{base_name} {index}"
        if not candidate.exists():
            return candidate
        index += 1


def create_folder() -> Path:
    desktop_dir = xdg_desktop_dir()
    desktop_dir.mkdir(parents=True, exist_ok=True)
    path = next_folder_path(desktop_dir)
    path.mkdir()
    return path


def load_state(paths: list[str]) -> dict:
    for raw in paths:
        path = Path(raw).expanduser()
        try:
            if path.exists():
                data = json.loads(path.read_text(encoding="utf-8") or "{}")
                return data if isinstance(data, dict) else {}
        except (OSError, json.JSONDecodeError):
            continue
    return {}


def save_state(path_text: str, payload_text: str) -> None:
    path = Path(path_text).expanduser()
    payload = json.loads(payload_text or "{}")
    if not isinstance(payload, dict):
        raise ValueError("desktop state payload must be a JSON object")
    atomic_write_json(path, payload)


def load_desktop_config(path_text: str) -> dict:
    path = Path(path_text).expanduser()
    cfg = dict(DESKTOP_CONFIG_DEFAULT)
    if path.exists():
        data = load_state([path_text])
        if isinstance(data, dict):
            cfg.update(data)
    else:
        atomic_write_json(path, cfg, indent=4)
    return cfg


def save_desktop_config(path_text: str, payload_text: str) -> None:
    path = Path(path_text).expanduser()
    payload = json.loads(payload_text or "{}")
    if not isinstance(payload, dict):
        raise ValueError("desktop config payload must be a JSON object")
    cfg = dict(DESKTOP_CONFIG_DEFAULT)
    cfg.update(payload)
    atomic_write_json(path, cfg, indent=4)


def load_desktop_layout(path_text: str) -> dict:
    path = Path(path_text).expanduser()
    state = dict(DESKTOP_STATE_DEFAULT)
    state["positions"] = {}
    if path.exists():
        data = load_state([path_text])
        if isinstance(data, dict):
            state.update(data)
    else:
        atomic_write_json(path, state, indent=None)
    if not isinstance(state.get("positions"), dict):
        state["positions"] = {}
    return state


def update_desktop_layout(path_text: str, sort_mode: str, icon_preset: str, icons_hidden: str, clear_positions: str) -> None:
    state = load_desktop_layout(path_text)
    state["sortMode"] = sort_mode
    state["iconPreset"] = icon_preset
    state["iconsHidden"] = icons_hidden == "1"
    if clear_positions == "1":
        state["positions"] = {}
    elif not isinstance(state.get("positions"), dict):
        state["positions"] = {}
    atomic_write_json(Path(path_text).expanduser(), state, indent=None)


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
        desktop_file = display_path(Path(parsed.get("desktop_file") or path))

        items.append({
            "name": str(parsed.get("name") or ""),
            "generic": str(parsed.get("generic") or ""),
            "icon": str(parsed.get("icon") or FALLBACK_ICON),
            "iconSource": icon_source_for(parsed),
            "desktop": desktop_file,
            "kind": "app",
        })

    for path in sorted((p for p in desktop_dir.iterdir() if p.is_dir()), key=lambda p: p.name.casefold()):
        key = display_path(path)
        if key in seen:
            continue
        seen.add(key)
        items.append({
            "name": path.name,
            "generic": "Folder",
            "icon": "folder",
            "desktop": key,
            "kind": "folder",
        })

    items.sort(key=lambda item: item["name"].casefold())
    return items


def desktop_signature() -> list[list[object]]:
    desktop_dir = xdg_desktop_dir()
    items: list[list[object]] = []
    if not desktop_dir.exists():
        return items
    for path in sorted(desktop_dir.iterdir()):
        if not (path.is_dir() or path.suffix == ".desktop"):
            continue
        try:
            stat = path.stat()
        except OSError:
            continue
        items.append([path.name, "dir" if path.is_dir() else "desktop", stat.st_mtime_ns, stat.st_size])
    return items


def signature_json() -> str:
    return json.dumps(desktop_signature(), ensure_ascii=False, separators=(",", ":"))


def emit_signature(last: str | None = None) -> str:
    current = signature_json()
    if current != last:
        print(current, flush=True)
    return current


def inotify_watch() -> int | None:
    desktop_dir = xdg_desktop_dir()
    if not desktop_dir.exists():
        return None
    try:
        libc = ctypes.CDLL("libc.so.6", use_errno=True)
        fd = libc.inotify_init1(IN_NONBLOCK | IN_CLOEXEC)
        if fd < 0:
            return None
        wd = libc.inotify_add_watch(fd, os.fsencode(desktop_dir), WATCH_MASK | IN_ONLYDIR)
        if wd < 0:
            os.close(fd)
            return None
        return fd
    except (AttributeError, OSError):
        return None


def drain_inotify(fd: int) -> None:
    try:
        while os.read(fd, 4096):
            pass
    except BlockingIOError:
        return
    except OSError:
        return


def watch_signatures() -> None:
    parent_pid = os.getppid()

    def parent_alive() -> bool:
        return os.getppid() == parent_pid

    last = emit_signature(None)
    fd = inotify_watch()
    if fd is None:
        while parent_alive():
            time.sleep(5)
            last = emit_signature(last)
        return

    poller = select.poll()
    poller.register(fd, select.POLLIN | select.POLLERR | select.POLLHUP)
    try:
        while parent_alive():
            events = poller.poll(30000)
            if not events:
                last = emit_signature(last)
                continue
            drain_inotify(fd)
            time.sleep(0.08)
            last = emit_signature(last)
    finally:
        os.close(fd)


def write_js(items: list[dict[str, str]], output_path: Path) -> None:
    payload = json.dumps(items, ensure_ascii=False, indent=2)
    atomic_write_text(output_path, f"var APPS = {payload};\n")


def write_json(items: list[dict[str, str]], output_path: Path) -> None:
    atomic_write_json(output_path, items, indent=2)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate or watch the desktop icon list from the XDG desktop folder.")
    parser.add_argument("--json", action="store_true", help="print the generated app list as JSON")
    parser.add_argument("--write", action="store_true", help="manually write apps.js and apps.json (debug only)")
    parser.add_argument("--signature", action="store_true", help="print the current desktop shortcut signature as JSON")
    parser.add_argument("--watch-signature", action="store_true", help="stream desktop shortcut signatures when the desktop folder changes")
    parser.add_argument("--create-folder", action="store_true", help="create a new folder on the desktop")
    parser.add_argument("--load-state", nargs="+", metavar="PATH", help="print the first readable desktop icon state file")
    parser.add_argument("--save-state", nargs=2, metavar=("PATH", "JSON"), help="atomically write desktop icon state JSON")
    parser.add_argument("--load-config", metavar="PATH", help="print Desktop Icons config JSON, creating defaults when missing")
    parser.add_argument("--save-config", nargs=2, metavar=("PATH", "JSON"), help="atomically write Desktop Icons config JSON")
    parser.add_argument("--load-layout-state", metavar="PATH", help="print Desktop Icons layout state JSON, creating defaults when missing")
    parser.add_argument("--update-layout-state", nargs=5, metavar=("PATH", "SORT", "PRESET", "HIDDEN", "CLEAR"), help="update Desktop Icons layout state")
    parser.add_argument("--max-apps", type=int, default=MAX_APPS, help="maximum number of apps to emit")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.watch_signature:
        watch_signatures()
        return
    if args.signature:
        print(signature_json())
        return
    if args.create_folder:
        print(display_path(create_folder()))
        return
    if args.load_state:
        print(json.dumps(load_state(args.load_state), ensure_ascii=False, separators=(",", ":")))
        return
    if args.save_state:
        save_state(args.save_state[0], args.save_state[1])
        return
    if args.load_config:
        print(json.dumps(load_desktop_config(args.load_config), ensure_ascii=False, separators=(",", ":")))
        return
    if args.save_config:
        save_desktop_config(args.save_config[0], args.save_config[1])
        return
    if args.load_layout_state:
        print(json.dumps(load_desktop_layout(args.load_layout_state), ensure_ascii=False, separators=(",", ":")))
        return
    if args.update_layout_state:
        update_desktop_layout(*args.update_layout_state)
        return

    items = collect_apps()[:max(1, args.max_apps)]
    script_dir = Path(__file__).resolve().parent

    if args.write:
        js_path = script_dir / "apps.js"
        json_path = script_dir / "apps.json"
        write_js(items, js_path)
        write_json(items, json_path)
        print(f"{js_path} ({len(items)} apps)")

    if args.json or not args.write:
        print(json.dumps(items, ensure_ascii=False))


if __name__ == "__main__":
    main()
