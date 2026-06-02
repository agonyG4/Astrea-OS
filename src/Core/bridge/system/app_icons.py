#!/usr/bin/env python3
"""
Reusable app icon resolver for Astrea surfaces.

It accepts app/window metadata from PipeWire, Hyprland, or desktop entries and
returns an icon name plus an optional local icon path that QML can render.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

BRIDGE_DIR = Path(__file__).resolve().parents[1]


def _load_astrea_shared():
    import importlib.util
    spec = importlib.util.spec_from_file_location("astrea_shared_runtime", BRIDGE_DIR / "astrea_shared.py")
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


ASTREA_SHARED = _load_astrea_shared()
APP_ICON_CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")).expanduser() / "Astrea/app-icons"
ICO_CACHE_VERSION = "ico-v2"


def run(cmd: list[str], timeout: float = 4.0) -> str:
    try:
        return subprocess.check_output(
            cmd,
            stderr=subprocess.DEVNULL,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
    except Exception:
        return ""


def application_dirs() -> list[Path]:
    dirs = [Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")).expanduser() / "applications"]
    for entry in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":"):
        if entry:
            dirs.append(Path(entry).expanduser() / "applications")
    deduped = []
    seen = set()
    for path in dirs:
        key = str(path)
        if key not in seen:
            seen.add(key)
            deduped.append(path)
    return deduped


def parse_desktop_file(path: Path, *, source: str = "", require_exec: bool = False):
    return ASTREA_SHARED.parse_desktop_file(path, source=source, require_exec=require_exec)


def resolve_icon_path(icon_name: str) -> str:
    return ASTREA_SHARED.resolve_icon_path(icon_name)


def _guess_icon(name: str) -> str:
    mapping = {
        "firefox":    "firefox",
        "chrome":     "google-chrome",
        "chromium":   "chromium",
        "spotify":    "spotify",
        "discord":    "discord",
        "telegram":   "telegram",
        "vlc":        "vlc",
        "mpv":        "mpv",
        "steam":      "steam",
        "obs":        "com.obsproject.Studio",
        "krita":      "krita",
        "gimp":       "gimp",
        "zen":        "zen-browser",
        "brave":      "brave-browser",
        "rhythmbox":  "rhythmbox",
        "amarok":     "amarok",
        "elisa":      "elisa",
        "clementine": "clementine",
    }
    lower = name.lower()
    for key, icon in mapping.items():
        if key in lower:
            return icon
    return "audio-x-generic"


def _compact_match_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", str(value or "").casefold())


def _steam_roots() -> list[Path]:
    candidates = [
        Path.home() / ".local/share/Steam",
        Path.home() / ".steam/steam",
    ]
    return [path for path in candidates if path.exists()]


def _parse_steam_manifest(path: Path) -> dict[str, str]:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return {}
    fields = {}
    for key in ("appid", "name", "installdir"):
        match = re.search(rf'"{re.escape(key)}"\s+"([^"]+)"', text)
        if match:
            fields[key] = match.group(1)
    return fields


def _process_environ(pid: str) -> dict[str, str]:
    try:
        raw = Path(f"/proc/{int(pid)}/environ").read_bytes()
    except (OSError, ValueError):
        return {}
    result = {}
    for item in raw.split(b"\0"):
        if not item or b"=" not in item:
            continue
        key, value = item.split(b"=", 1)
        try:
            result[key.decode("utf-8", errors="ignore")] = value.decode("utf-8", errors="ignore")
        except UnicodeDecodeError:
            continue
    return result


def _process_parent_pid(pid: str) -> str:
    try:
        text = Path(f"/proc/{int(pid)}/stat").read_text(encoding="utf-8", errors="ignore")
    except (OSError, ValueError):
        return ""
    end = text.rfind(")")
    if end < 0:
        return ""
    fields = text[end + 2:].split()
    return fields[1] if len(fields) > 1 else ""


def _process_cmdline(pid: str) -> str:
    try:
        raw = Path(f"/proc/{int(pid)}/cmdline").read_bytes()
    except (OSError, ValueError):
        return ""
    args = [arg.decode("utf-8", errors="ignore") for arg in raw.split(b"\0") if arg]
    return "\n".join(args)


def _process_cwd(pid: str) -> str:
    try:
        return os.readlink(f"/proc/{int(pid)}/cwd")
    except (OSError, ValueError):
        return ""


def _process_ancestor_pids(pid: str, limit: int = 8) -> list[str]:
    current = str(pid or "").strip()
    result = []
    seen = set()
    while current and current not in seen and len(result) < limit:
        seen.add(current)
        result.append(current)
        parent = _process_parent_pid(current)
        if not parent or parent == current or parent == "1":
            break
        current = parent
    return result


def _process_contexts(props: dict, limit: int = 8) -> list[dict]:
    pid = str(props.get("application.process.id") or props.get("pid") or "").strip()
    if not pid:
        return []
    contexts = []
    for current in _process_ancestor_pids(pid, limit=limit):
        contexts.append({
            "pid": current,
            "env": _process_environ(current),
            "cmdline": _process_cmdline(current),
            "cwd": _process_cwd(current),
        })
    return contexts


def _steam_library_dirs() -> list[Path]:
    dirs = []
    for root in _steam_roots():
        dirs.append(root / "steamapps")
        libraryfolders = root / "steamapps/libraryfolders.vdf"
        try:
            text = libraryfolders.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            text = ""
        for match in re.finditer(r'"path"\s+"([^"]+)"', text):
            library = Path(match.group(1).replace("\\\\", "/")).expanduser() / "steamapps"
            dirs.append(library)
    deduped = []
    seen = set()
    for path in dirs:
        try:
            key = str(path.resolve())
        except OSError:
            key = str(path)
        if key not in seen and path.exists():
            seen.add(key)
            deduped.append(path)
    return deduped


def _steam_manifest_paths() -> list[Path]:
    manifests = []
    for steamapps in _steam_library_dirs():
        try:
            manifests.extend(sorted(steamapps.glob("appmanifest_*.acf")))
        except OSError:
            continue
    return manifests


def _hicolor_steam_icon_path(icon_name: str) -> str:
    root = Path.home() / ".local/share/icons/hicolor"
    candidates = []
    try:
        paths = list(root.glob(f"*/apps/{icon_name}.png"))
    except OSError:
        return ""
    for path in paths:
        match = re.search(r"/(\d+)x\d+/apps/", str(path))
        size = int(match.group(1)) if match else 0
        candidates.append((size, path))
    candidates.sort(reverse=True)
    return str(candidates[0][1]) if candidates else ""


def _steam_icon_candidate_for_appid(appid: str) -> tuple[str, str]:
    appid = str(appid or "").strip()
    if not appid:
        return "", ""
    icon_name = f"steam_icon_{appid}"

    icon_path = resolve_icon_path(icon_name) or _hicolor_steam_icon_path(icon_name)
    if icon_path:
        return icon_name, icon_path

    for root in _steam_roots():
        cache = root / "appcache/librarycache" / appid
        patterns = [
            "**/logo.png",
            "**/header.jpg",
            "**/library_header.jpg",
            "**/library_600x900.jpg",
        ]
        for pattern in patterns:
            matches = sorted(cache.glob(pattern))
            if matches:
                return icon_name, str(matches[0])
    return "", ""


def _steam_appid_from_text(text: str) -> str:
    if not text:
        return ""
    patterns = (
        r"(?:SteamAppId|SteamGameId|STEAM_COMPAT_APP_ID|SteamOverlayGameId)\D+(\d+)",
        r"steam://rungameid/(\d+)",
        r"steamapps[/\\]compatdata[/\\](\d+)",
        r"\bsteam_app_(\d+)\b",
    )
    for pattern in patterns:
        match = re.search(pattern, str(text), flags=re.IGNORECASE)
        if match:
            return match.group(1)
    return ""


def _steam_appid_for_process(props: dict) -> str:
    env_keys = ("SteamAppId", "SteamGameId", "STEAM_COMPAT_APP_ID", "SteamOverlayGameId")
    for key in env_keys:
        value = str(props.get(key, "")).strip()
        if value.isdigit():
            return value

    for value in props.values():
        appid = _steam_appid_from_text(str(value))
        if appid:
            return appid

    for context in _process_contexts(props):
        env = context.get("env", {})
        for key in env_keys:
            value = str(env.get(key, "")).strip()
            if value.isdigit():
                return value
        for key, value in env.items():
            if any(token in key for token in ("Steam", "STEAM", "PROTON", "COMPAT")):
                appid = _steam_appid_from_text(value)
                if appid:
                    return appid
        for value in (context.get("cmdline", ""), context.get("cwd", "")):
            appid = _steam_appid_from_text(value)
            if appid:
                return appid
    return ""


def _stream_text_hints(name: str, props: dict) -> str:
    parts = [str(name or "")]
    for key in (
        "application.name",
        "application.process.binary",
        "application.id",
        "media.name",
        "node.name",
        "module-stream-restore.id",
        "window.class",
        "window.initial_class",
        "window.title",
        "window.initial_title",
    ):
        parts.append(str(props.get(key, "")))
    for context in _process_contexts(props, limit=4):
        parts.append(str(context.get("cmdline", "")))
        parts.append(str(context.get("cwd", "")))
    return "\n".join(part for part in parts if part)


def _exe_stems_for_stream(name: str, props: dict) -> list[str]:
    values = [
        name,
        props.get("application.name", ""),
        props.get("media.name", ""),
        props.get("node.name", ""),
        props.get("module-stream-restore.id", ""),
        props.get("window.title", ""),
        props.get("window.initial_title", ""),
    ]
    result = []
    seen = set()
    for value in values:
        for match in re.finditer(r"([^/\\:]+?)\.exe\b", str(value or ""), flags=re.IGNORECASE):
            key = _compact_match_key(match.group(1))
            if key and key not in seen:
                seen.add(key)
                result.append(key)
    return result


def _steam_manifest_match_score(fields: dict[str, str], stems: list[str], text_hints: str) -> int:
    name_key = _compact_match_key(fields.get("name", ""))
    install_key = _compact_match_key(fields.get("installdir", ""))
    hints_key = _compact_match_key(text_hints)
    score = 0

    if install_key and install_key in hints_key:
        score = max(score, 90)
    if name_key and name_key in hints_key:
        score = max(score, 80)

    for stem in stems:
        if not stem:
            continue
        if stem in {name_key, install_key}:
            score = max(score, 75)
        elif len(stem) >= 4 and name_key and stem in name_key:
            score = max(score, 55)
        elif len(stem) >= 4 and install_key and stem in install_key:
            score = max(score, 55)
    return score


def _steam_icon_for_app(name: str, props: dict) -> tuple[str, str]:
    icon_name, icon_path = _steam_icon_candidate_for_appid(_steam_appid_for_process(props))
    if icon_path:
        return icon_name, icon_path

    app_name = str(name or props.get("application.name", "")).strip().casefold()
    stems = _exe_stems_for_stream(name, props)
    text_hints = _stream_text_hints(name, props)
    if not app_name and not stems:
        return "", ""

    best_score = 0
    best_icon = ("", "")
    for manifest in _steam_manifest_paths():
        fields = _parse_steam_manifest(manifest)
        if not fields.get("appid"):
            continue
        score = 100 if fields.get("name", "").casefold() == app_name else 0
        score = max(score, _steam_manifest_match_score(fields, stems, text_hints))
        if score <= best_score:
            continue
        candidate = _steam_icon_candidate_for_appid(fields.get("appid", ""))
        if candidate[1]:
            best_score = score
            best_icon = candidate
    return best_icon


def _is_wine_or_proton_stream(name: str, props: dict) -> bool:
    text = " ".join(str(props.get(key, "")) for key in (
        "application.name",
        "application.process.binary",
        "application.id",
        "media.name",
        "node.name",
        "module-stream-restore.id",
        "window.class",
        "window.initial_class",
        "window.title",
        "window.initial_title",
    ))
    text = f"{name} {text}".casefold()
    return (
        ".exe" in text
        or "wine" in text
        or "proton" in text
        or "pressure-vessel" in text
        or "steam_app_default" in text
    )


def _wine_prefixes_from_contexts(contexts: list[dict]) -> list[Path]:
    prefixes = []
    for context in contexts:
        env = context.get("env", {})
        wineprefix = str(env.get("WINEPREFIX", "")).strip()
        if wineprefix:
            prefixes.append(Path(wineprefix).expanduser())
        compat = str(env.get("STEAM_COMPAT_DATA_PATH", "")).strip()
        if compat:
            prefixes.append(Path(compat).expanduser() / "pfx")
    prefixes.append(Path.home() / ".wine")

    deduped = []
    seen = set()
    for prefix in prefixes:
        key = str(prefix)
        if key not in seen:
            seen.add(key)
            deduped.append(prefix)
    return deduped


def _windows_exe_paths_from_text(text: str) -> list[str]:
    if not text:
        return []
    patterns = (
        r"([A-Za-z]:\\[^\"'\0\r\n]*?\.exe)",
        r"(/[^\0\r\n\"']*?\.exe)",
    )
    result = []
    seen = set()
    for pattern in patterns:
        for match in re.finditer(pattern, text, flags=re.IGNORECASE):
            value = match.group(1).strip()
            if value and value not in seen:
                seen.add(value)
                result.append(value)
    return result


def _wine_path_to_unix_path(value: str, prefixes: list[Path]) -> Path | None:
    value = str(value or "").strip().strip("\"'")
    if not value:
        return None
    if value.startswith("/"):
        path = Path(value)
        return path if path.exists() else None

    match = re.match(r"^([A-Za-z]):[\\/](.*)$", value)
    if not match:
        return None
    drive = match.group(1).casefold()
    rest = match.group(2).replace("\\", "/").lstrip("/")
    candidates = []

    if drive == "z":
        candidates.append(Path("/") / rest)
    for prefix in prefixes:
        drive_link = prefix / "dosdevices" / f"{drive}:"
        if drive_link.exists():
            try:
                candidates.append(drive_link.resolve() / rest)
            except OSError:
                pass
        if drive == "c":
            candidates.append(prefix / "drive_c" / rest)
    candidates.extend((Path.home() / rest, Path("/") / rest))

    seen = set()
    for candidate in candidates:
        key = str(candidate)
        if key in seen:
            continue
        seen.add(key)
        if candidate.exists():
            return candidate
    return None


def _wine_executable_paths(name: str, props: dict) -> list[Path]:
    contexts = _process_contexts(props)
    prefixes = _wine_prefixes_from_contexts(contexts)
    values = [
        str(name or ""),
        str(props.get("application.name", "")),
        str(props.get("node.name", "")),
        str(props.get("window.title", "")),
        str(props.get("window.initial_title", "")),
    ]
    for context in contexts:
        values.append(str(context.get("cmdline", "")))
        values.append(str(context.get("cwd", "")))

    paths = []
    seen = set()
    exe_names = [
        f"{stem}.exe"
        for stem in _exe_stems_for_stream(name, props)
        if stem
    ]
    for value in values:
        for raw_path in _windows_exe_paths_from_text(value):
            path = _wine_path_to_unix_path(raw_path, prefixes)
            if path and str(path) not in seen:
                seen.add(str(path))
                paths.append(path)

    for context in contexts:
        cwd = str(context.get("cwd", ""))
        if not cwd:
            continue
        for exe_name in exe_names:
            candidate = Path(cwd) / exe_name
            if candidate.exists() and str(candidate) not in seen:
                seen.add(str(candidate))
                paths.append(candidate)
    return paths


def _convert_ico_to_png(path: Path) -> str:
    tool = shutil.which("magick") or shutil.which("convert")
    if not tool:
        return ""
    try:
        stat = path.stat()
        APP_ICON_CACHE.mkdir(parents=True, exist_ok=True)
    except OSError:
        return ""

    frame_index, frame_size = _best_ico_frame(path, tool)
    fingerprint = hashlib.sha256(
        f"{ICO_CACHE_VERSION}:{path}:{stat.st_mtime_ns}:{stat.st_size}:{frame_index}:{frame_size}".encode("utf-8", errors="ignore")
    ).hexdigest()[:24]
    stem = _compact_match_key(path.stem) or "icon"
    output = APP_ICON_CACHE / f"{stem}-{max(frame_size, 0)}-{fingerprint}.png"
    if output.exists():
        return str(output)
    tmp = output.with_name(f".{output.name}.{os.getpid()}.tmp")
    try:
        subprocess.run(
            [tool, f"{path}[{frame_index}]", "-resize", "256x256>", str(tmp)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=3,
            check=True,
        )
        tmp.replace(output)
        return str(output)
    except Exception:
        try:
            tmp.unlink(missing_ok=True)
        except OSError:
            pass
        if output.exists():
            return str(output)
    return ""


def _best_ico_frame(path: Path, tool: str) -> tuple[int, int]:
    try:
        result = subprocess.run(
            [tool, "identify", "-format", "%p %w %h\n", str(path)],
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )
    except Exception:
        return 0, 0
    if result.returncode != 0:
        return 0, 0
    return _best_ico_frame_from_identify(result.stdout)


def _best_ico_frame_from_identify(output: str) -> tuple[int, int]:
    frames: list[tuple[int, int]] = []
    for line in str(output or "").splitlines():
        match = re.match(r"(\d+)\s+(\d+)\s+(\d+)", line.strip())
        if not match:
            continue
        index, width, height = map(int, match.groups())
        if width == height and width > 0:
            frames.append((width, index))
    if not frames:
        return 0, 0
    size, index = sorted(frames, reverse=True)[0]
    return index, size


def _prepare_local_icon_file(path: Path) -> str:
    if path.suffix.casefold() == ".ico":
        return _convert_ico_to_png(path) or str(path)
    return str(path)


def _local_icon_for_executable(executable: Path) -> str:
    try:
        executable = executable.resolve()
    except OSError:
        return ""
    if not executable.exists():
        return ""

    image_exts = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".ico"}
    stem_key = _compact_match_key(executable.stem)
    generic_names = {"icon", "logo", "game", "app", "windowicon", "launcher"}
    dirs = [executable.parent]
    try:
        for child in executable.parent.iterdir():
            if child.is_dir():
                dirs.append(child)
    except OSError:
        pass

    best_path = None
    best_score = 0
    for directory in dirs:
        try:
            entries = list(directory.iterdir())
        except OSError:
            continue
        if len(entries) > 700:
            continue
        for entry in entries:
            if not entry.is_file() or entry.suffix.casefold() not in image_exts:
                continue
            entry_key = _compact_match_key(entry.stem)
            score = 0
            if entry_key == stem_key:
                score = 100
            elif entry_key in generic_names:
                score = 80
            elif stem_key and len(stem_key) >= 4 and stem_key in entry_key:
                score = 60
            if score > best_score:
                best_score = score
                best_path = entry

    return _prepare_local_icon_file(best_path) if best_path else ""


def _wine_icon_for_app(name: str, props: dict) -> str:
    for executable in _wine_executable_paths(name, props):
        icon = _local_icon_for_executable(executable)
        if icon:
            return icon
    return ""


def _desktop_icon_for_app(name: str, props: dict) -> str:
    needles = {
        str(name or "").strip().lower(),
        str(props.get("application.process.binary", "")).strip().lower(),
        str(props.get("application.name", "")).strip().lower(),
        str(props.get("node.name", "")).strip().lower(),
        str(props.get("window.class", "")).strip().lower(),
        str(props.get("window.initial_class", "")).strip().lower(),
        str(props.get("window.title", "")).strip().lower(),
    }
    needles = {n for n in needles if n}
    if not needles:
        return ""

    best_icon = ""
    best_score = 0
    for app_dir in application_dirs():
        try:
            entries = list(app_dir.glob("*.desktop"))
        except OSError:
            continue
        for path in entries:
            entry = parse_desktop_file(path, source=str(app_dir), require_exec=False)
            if not entry:
                continue
            hay = " ".join(str(entry.get(key, "")) for key in ("id", "name", "exec")).lower()
            score = 0
            for needle in needles:
                compact = needle.removesuffix("-bin")
                if needle and needle in hay:
                    score = max(score, 2)
                if compact and compact != needle and compact in hay:
                    score = max(score, 1)
            if score > best_score:
                best_score = score
                best_icon = entry.get("icon", "")
    return best_icon


def resolve_app_icon(name: str, props: dict | None = None) -> tuple[str, str]:
    props = props or {}
    explicit_icon = str(props.get("application.icon-name")
                        or props.get("application.icon_name")
                        or props.get("media.icon-name")
                        or props.get("icon_name")
                        or "").strip()
    if explicit_icon:
        icon_path = resolve_icon_path(explicit_icon)
        if icon_path:
            return explicit_icon, icon_path

    wine_or_proton = _is_wine_or_proton_stream(name, props)
    if wine_or_proton:
        icon_name, icon_path = _steam_icon_for_app(name, props)
        if icon_path:
            return icon_name, icon_path

        desktop_icon = _desktop_icon_for_app(name, props)
        if desktop_icon:
            resolved = resolve_icon_path(desktop_icon)
            if resolved:
                return desktop_icon, resolved

        icon_path = _wine_icon_for_app(name, props)
        if icon_path:
            return explicit_icon or Path(icon_path).stem, icon_path

    guessed_icon = _guess_icon(name)
    if guessed_icon != "audio-x-generic":
        icon_path = resolve_icon_path(guessed_icon)
        if icon_path:
            return guessed_icon, icon_path

    if not wine_or_proton:
        icon_name, icon_path = _steam_icon_for_app(name, props)
        if icon_path:
            return icon_name or guessed_icon, icon_path

    desktop_icon = _desktop_icon_for_app(name, props)
    if desktop_icon:
        icon_path = resolve_icon_path(desktop_icon)
        if icon_path:
            return desktop_icon, icon_path

    if not wine_or_proton:
        icon_path = _wine_icon_for_app(name, props)
        if icon_path:
            return explicit_icon or Path(icon_path).stem, icon_path

    icon_name = explicit_icon or guessed_icon or "audio-x-generic"
    icon_path = resolve_icon_path(icon_name) if icon_name else ""
    return icon_name, icon_path


def hypr_client_props(client: dict) -> tuple[str, dict]:
    title = str(client.get("title") or client.get("initialTitle") or client.get("class") or "App")
    app_class = str(client.get("class") or client.get("initialClass") or "")
    pid = str(client.get("pid") or "").strip()
    props = {
        "pid": pid,
        "application.process.id": pid,
        "application.name": title,
        "application.process.binary": app_class,
        "application.id": app_class,
        "node.name": title,
        "window.class": app_class,
        "window.initial_class": str(client.get("initialClass") or ""),
        "window.title": title,
        "window.initial_title": str(client.get("initialTitle") or ""),
    }
    return title, props


def _hypr_client_needs_deep_icon(client: dict) -> bool:
    text = " ".join(str(client.get(key, "")) for key in (
        "class",
        "initialClass",
        "title",
        "initialTitle",
    )).casefold()
    return (
        ".exe" in text
        or "wine" in text
        or "proton" in text
        or "pressure-vessel" in text
        or "steam_app_" in text
    )


def annotate_hypr_clients(clients: list[dict]) -> list[dict]:
    annotated = []
    for client in clients:
        if not isinstance(client, dict):
            continue
        item = dict(client)
        if not _hypr_client_needs_deep_icon(item):
            annotated.append(item)
            continue
        name, props = hypr_client_props(item)
        icon_name, icon_path = resolve_app_icon(name, props)
        if icon_path and icon_name != "audio-x-generic":
            item["astreaIcon"] = icon_path
            item["astreaIconName"] = icon_name
        elif icon_name and icon_name != "audio-x-generic":
            item["astreaIconName"] = icon_name
        annotated.append(item)
    return annotated


def hypr_clients_json() -> list[dict]:
    raw = run(["hyprctl", "clients", "-j"], timeout=2.5)
    data = json.loads(raw or "[]")
    return data if isinstance(data, list) else []


def _read_json_arg_or_stdin(args: list[str]):
    raw = args[0] if args else sys.stdin.read()
    return json.loads(raw or "{}")


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "resolve"
    if mode == "resolve":
        payload = _read_json_arg_or_stdin(sys.argv[2:])
        if not isinstance(payload, dict):
            payload = {}
        name = str(payload.get("name") or payload.get("title") or payload.get("application.name") or "App")
        props = payload.get("props") if isinstance(payload.get("props"), dict) else payload
        icon_name, icon_path = resolve_app_icon(name, props)
        print(json.dumps({"icon_name": icon_name, "icon": icon_path}, ensure_ascii=False))
        return 0
    if mode == "hypr-clients":
        print(json.dumps(annotate_hypr_clients(hypr_clients_json()), ensure_ascii=False))
        return 0
    print(f"Modo desconhecido: {mode}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
