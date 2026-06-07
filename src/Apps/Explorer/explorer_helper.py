#!/usr/bin/env python3

from __future__ import annotations

import argparse
import ctypes
import datetime
import json
import os
import select
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.parse
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path


def _path_exists(path: Path) -> bool:
    return path.exists() or path.is_symlink()


def _validate_child_name(name: str, label: str = "name") -> str:
    value = str(name or "").strip()
    if not value or value in {".", ".."}:
        raise ValueError(f"invalid_{label}")
    if Path(value).is_absolute() or Path(value).name != value:
        raise ValueError(f"invalid_{label}")
    return value


def create_folder(base_text: str, name: str) -> None:
    base = Path(base_text).expanduser()
    safe_name = _validate_child_name(name, "folder_name")
    target = base / safe_name
    index = 2
    while _path_exists(target):
        target = base / f"{safe_name} {index}"
        index += 1
    target.mkdir()


def rename_path(source_text: str, new_name: str) -> None:
    source = Path(source_text).expanduser()
    safe_name = _validate_child_name(new_name, "file_name")
    target = source.parent / safe_name
    if source == target:
        return
    if _path_exists(target):
        raise SystemExit(1)
    os.rename(source, target)


def suggest_dirs(base_text: str, prefix: str, request_id: str = "") -> None:
    base = Path(base_text).expanduser()
    if request_id:
        print(f"__request_id__:{request_id}")
    if not base.is_dir():
        return
    matches = []
    for entry in base.iterdir():
        if entry.is_dir() and entry.name.startswith(prefix):
            matches.append(str(entry))
    for entry in sorted(matches)[:12]:
        print(entry)


def process_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def read_pid(path: Path) -> int | None:
    try:
        return int(path.read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        return None




def create_desktop_shortcut(target_text: str) -> dict[str, object]:
    target = Path(target_text).expanduser()
    if not target.exists() and not target.is_symlink():
        return {"ok": False, "error": "target_not_found"}
    desktop = ""
    try:
        probe = subprocess.run(["xdg-user-dir", "DESKTOP"], check=False, capture_output=True, text=True)
        desktop = (probe.stdout or "").strip()
    except Exception:
        desktop = ""
    if not desktop or desktop == str(Path.home()):
        desktop = str(Path.home() / "Área de trabalho")
    desk = Path(desktop).expanduser()
    if not desk.exists():
        desk = Path.home() / "Desktop"
    desk.mkdir(parents=True, exist_ok=True)
    name = target.name
    dest = desk / name
    i = 2
    while dest.exists() or dest.is_symlink():
        dest = desk / f"{name} {i}"
        i += 1
    os.symlink(str(target), str(dest))
    return {"ok": True, "destination": str(dest)}

def network_mount_probe(root_text: str) -> None:
    root = Path(root_text)
    if not root.is_dir():
        raise SystemExit(2)
    for entry in root.iterdir():
        print(entry)
        return


def copy_uri_list(paths: list[str], runner=None) -> None:
    payload = "".join(f"file://{urllib.parse.quote(path, safe='/')}\n" for path in paths)
    run = runner or subprocess.run
    run(["wl-copy", "--type", "text/uri-list"], input=payload, text=True, check=True)

IMAGE_MIME_EXTENSIONS = {
    "image/png": "png",
    "image/jpeg": "jpg",
    "image/webp": "webp",
    "image/gif": "gif",
    "image/bmp": "bmp",
    "image/tiff": "tiff",
    "image/x-portable-pixmap": "ppm",
    "image/x-portable-graymap": "pgm",
    "image/x-portable-bitmap": "pbm",
}
ARCHIVE_FORMAT_EXTENSIONS = {"zip": "zip", "rar": "rar", "tar": "tar", "tar.gz": "tar.gz", "tar.xz": "tar.xz"}


def image_extension_for_mime(mime_type: str) -> str:
    return IMAGE_MIME_EXTENSIONS.get(mime_type, "png")


def paste_image(destination_dir_text: str, mime_type: str, paste_runner=None) -> str:
    destination_dir = Path(destination_dir_text).expanduser()
    if not destination_dir.is_dir():
        raise SystemExit(2)

    ext = image_extension_for_mime(mime_type)
    stamp = time.strftime("%Y-%m-%d %H-%M-%S")
    base_name = f"Pasted Image {stamp}"
    target = _unique_target(destination_dir, f"{base_name}.{ext}")

    runner = paste_runner or subprocess.run
    result = runner(
        ["wl-paste", "--no-newline", "--type", mime_type],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    target.write_bytes(result.stdout)
    print(target)
    return str(target)


def _truthy_desktop_value(value: str | None) -> bool:
    return (value or "").strip().lower() in {"1", "true", "yes"}


def parse_desktop_entry(path: Path) -> dict[str, object] | None:
    values: dict[str, str] = {}
    in_desktop_entry = False
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return None

    for raw_line in lines:
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            in_desktop_entry = line == "[Desktop Entry]"
            continue
        if not in_desktop_entry or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values.setdefault(key.strip(), value.strip())

    if values.get("Type") != "Application":
        return None

    name = values.get("Name") or path.stem
    exec_line = values.get("Exec", "")
    no_display = _truthy_desktop_value(values.get("NoDisplay"))
    hidden = _truthy_desktop_value(values.get("Hidden")) or not exec_line
    mime_types = [item for item in values.get("MimeType", "").split(";") if item]
    categories = [item for item in values.get("Categories", "").split(";") if item]
    return {
        "name": name,
        "desktop_id": path.name,
        "desktop_file": str(path),
        "icon": values.get("Icon", ""),
        "exec": exec_line,
        "mime_types": mime_types,
        "categories": categories,
        "hidden": hidden,
        "no_display": no_display,
        "terminal": _truthy_desktop_value(values.get("Terminal")),
    }


PREVIEWABLE_RECENT_EXTENSIONS = {
    ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".svg", ".avif",
    ".heic", ".heif", ".tiff", ".tif",
}


def _file_url(path: Path) -> str:
    return "file://" + urllib.parse.quote(str(path), safe="/")


def _unix_millis_from_stat(path: Path) -> int:
    try:
        return int(path.stat().st_mtime * 1000)
    except OSError:
        return 0


def _unix_millis_from_iso8601(value: str | None) -> int:
    if not value:
        return 0
    try:
        normalized = value.replace("Z", "+00:00")
        return int(datetime.datetime.fromisoformat(normalized).timestamp() * 1000)
    except Exception:
        return 0


def _safe_int(value: object, default: int = 0) -> int:
    try:
        return int(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return default


def _recent_file_kind(path: Path, is_dir: bool) -> str:
    if is_dir:
        return "Pasta"
    suffix = path.suffix.lstrip(".")
    return suffix.upper() if suffix else "Arquivo"


def _recent_item_from_path(path: Path, last_accessed: int | None = None, *, kind: str = "") -> dict[str, object] | None:
    path = path.expanduser()
    if not _path_exists(path):
        return None
    try:
        stat = path.stat()
    except OSError:
        return None
    is_dir = path.is_dir()
    executable = bool(stat.st_mode & 0o111) and not is_dir
    preview_url = _file_url(path) if (not is_dir and path.suffix.lower() in PREVIEWABLE_RECENT_EXTENSIONS) else ""
    return {
        "fileName": path.name or str(path),
        "filePath": str(path),
        "fileUrl": _file_url(path),
        "fileIsDir": is_dir,
        "fileExecutable": executable,
        "fileHidden": path.name.startswith("."),
        "fileSize": 0 if is_dir else stat.st_size,
        "fileModified": int(stat.st_mtime * 1000),
        "fileKind": kind or _recent_file_kind(path, is_dir),
        "filePreviewUrl": preview_url,
        "lastAccessed": int(last_accessed or _unix_millis_from_stat(path)),
        "recentSource": "finder",
    }


def _resolve_desktop_file(desktop_id: str) -> Path | None:
    candidate = Path(desktop_id).expanduser()
    if candidate.is_file():
        return candidate
    file_name = desktop_id if desktop_id.endswith(".desktop") else f"{desktop_id}.desktop"
    for directory in _application_dirs():
        path = directory / file_name
        if path.is_file():
            return path
    return None


def _desktop_recent_item(desktop_file: Path, last_accessed: int) -> dict[str, object] | None:
    parsed = parse_desktop_entry(desktop_file)
    if not parsed:
        return None
    item = _recent_item_from_path(desktop_file, last_accessed, kind="Aplicativo")
    if not item:
        return None
    item["fileName"] = str(parsed.get("name") or desktop_file.stem)
    item["fileExecutable"] = True
    item["filePreviewUrl"] = ""
    item["recentSource"] = "launch"
    return item


def _desktop_file_from_launch_record(record: dict[str, object]) -> Path | None:
    for arg in record.get("argv") or []:
        if isinstance(arg, str) and arg.endswith(".desktop"):
            path = Path(arg).expanduser()
            if path.is_file():
                return path
    target = str(record.get("target") or "")
    return _resolve_desktop_file(target) if target else None


def _iter_launch_history_items(history_path: Path, limit: int) -> list[dict[str, object]]:
    if not history_path.is_file():
        return []
    records: list[dict[str, object]] = []
    seen_paths: set[str] = set()
    try:
        lines = history_path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return []
    for line in reversed(lines):
        if len(seen_paths) >= limit:
            break
        try:
            record = json.loads(line)
        except json.JSONDecodeError:
            continue
        if record.get("status") != "ok":
            continue
        timestamp = _safe_int(record.get("timestamp_ms"), 0)
        kind = record.get("kind")
        item = None
        if kind == "file":
            target = str(record.get("target") or "")
            if target:
                item = _recent_item_from_path(Path(target), timestamp)
        elif kind == "desktop":
            desktop_file = _desktop_file_from_launch_record(record)
            if desktop_file:
                item = _desktop_recent_item(desktop_file, timestamp)
        if item:
            item_path = str(item.get("filePath") or "")
            if not item_path or item_path in seen_paths:
                continue
            item["recentSource"] = "launch"
            records.append(item)
            seen_paths.add(item_path)
    return records


def _iter_xbel_recent_items(xbel_path: Path, limit: int) -> list[dict[str, object]]:
    if not xbel_path.is_file():
        return []
    try:
        root = ET.parse(xbel_path).getroot()
    except Exception:
        return []
    items: list[dict[str, object]] = []
    for bookmark in root.findall("{*}bookmark"):
        href = bookmark.attrib.get("href", "")
        if not href.startswith("file://"):
            continue
        path = Path(urllib.parse.unquote(urllib.parse.urlparse(href).path))
        timestamp = max(
            _unix_millis_from_iso8601(bookmark.attrib.get("visited")),
            _unix_millis_from_iso8601(bookmark.attrib.get("modified")),
            _unix_millis_from_iso8601(bookmark.attrib.get("added")),
        )
        item = _recent_item_from_path(path, timestamp)
        if item:
            item["recentSource"] = "xbel"
            items.append(item)
    return sorted(items, key=lambda item: _safe_int(item.get("lastAccessed"), 0), reverse=True)[:limit]


def _load_finder_recent_items(path: Path) -> list[dict[str, object]]:
    if not path.is_file():
        return []
    try:
        parsed = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return []
    if not isinstance(parsed, list):
        return []
    items = []
    for item in parsed:
        if isinstance(item, dict):
            item.setdefault("recentSource", "finder")
            items.append(item)
    return items


def _merge_recent_items(*sources: list[dict[str, object]], limit: int = 60) -> list[dict[str, object]]:
    merged: dict[str, dict[str, object]] = {}
    for source in sources:
        for item in source:
            path = str(item.get("filePath") or "")
            if not path:
                continue
            timestamp = _safe_int(item.get("lastAccessed"), 0)
            existing = merged.get(path)
            if not existing or timestamp >= _safe_int(existing.get("lastAccessed"), 0):
                merged[path] = item
    return sorted(merged.values(), key=lambda item: _safe_int(item.get("lastAccessed"), 0), reverse=True)[:limit]


def merged_recents(finder_path_text: str, launch_history_text: str, xbel_path_text: str, limit: int = 60) -> list[dict[str, object]]:
    finder_path = Path(finder_path_text).expanduser()
    launch_history = Path(launch_history_text).expanduser()
    xbel_path = Path(xbel_path_text).expanduser()
    return _merge_recent_items(
        _load_finder_recent_items(finder_path),
        _iter_launch_history_items(launch_history, limit),
        _iter_xbel_recent_items(xbel_path, limit),
        limit=limit,
    )


def _application_dirs() -> list[Path]:
    dirs: list[Path] = []
    home = Path.home()
    dirs.append(home / ".local/share/applications")
    dirs.append(home / ".local/share/flatpak/exports/share/applications")

    for root in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":"):
        if root:
            dirs.append(Path(root) / "applications")
    dirs.append(Path("/var/lib/flatpak/exports/share/applications"))

    unique: list[Path] = []
    seen: set[str] = set()
    for directory in dirs:
        key = str(directory)
        if key not in seen:
            unique.append(directory)
            seen.add(key)
    return unique


def _query_file_mime(path: Path, mime_runner=None) -> str:
    if mime_runner is not None:
        return (mime_runner(str(path)) or "").strip()
    try:
        result = subprocess.run(
            ["xdg-mime", "query", "filetype", str(path)],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        return result.stdout.strip()
    except Exception:
        try:
            result = subprocess.run(
                ["file", "--brief", "--mime-type", str(path)],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
            )
            return result.stdout.strip()
        except Exception:
            return "application/octet-stream"


def _query_default_app(mime_type: str, default_runner=None) -> str:
    if default_runner is not None:
        return (default_runner(mime_type) or "").strip()
    try:
        result = subprocess.run(
            ["xdg-mime", "query", "default", mime_type],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        return result.stdout.strip()
    except Exception:
        return ""


def _mime_matches(app_mimes: list[str], mime_type: str) -> bool:
    if not mime_type:
        return False
    if mime_type in app_mimes:
        return True
    group = mime_type.split("/", 1)[0] if "/" in mime_type else ""
    return any(item == f"{group}/*" for item in app_mimes)


def _desktop_app_identity(app: dict[str, object]) -> str:
    name = str(app.get("name") or "").casefold().strip()
    exec_line = str(app.get("exec") or "").casefold().strip()
    return f"{name}\0{exec_line}"


def _dedupe_desktop_apps(apps: list[dict[str, object]]) -> list[dict[str, object]]:
    unique = []
    seen: set[str] = set()
    for app in apps:
        identity = _desktop_app_identity(app)
        if identity in seen:
            continue
        seen.add(identity)
        unique.append(app)
    return unique


def _iter_desktop_entries(app_dirs: list[Path]):
    seen: set[str] = set()
    for directory in app_dirs:
        if not directory.is_dir():
            continue
        for entry in sorted(directory.glob("*.desktop")):
            if entry.name in seen:
                continue
            seen.add(entry.name)
            parsed = parse_desktop_entry(entry)
            if parsed is not None:
                yield parsed


def open_with_apps(path_text: str, app_dirs=None, mime_runner=None, default_runner=None) -> dict[str, object]:
    path = Path(path_text).expanduser().resolve()
    if not path.exists() or not (path.is_file() or path.is_dir()):
        return {"ok": False, "error": "Arquivo nao encontrado", "apps": []}

    mime_type = _query_file_mime(path, mime_runner)
    default_id = _query_default_app(mime_type, default_runner)
    dirs = [Path(item) for item in app_dirs] if app_dirs is not None else _application_dirs()

    recommended = []
    for app in _iter_desktop_entries(dirs):
        mime_types = app.get("mime_types", [])
        is_default = app["desktop_id"] == default_id
        is_compatible = _mime_matches(mime_types, mime_type)
        if app.get("hidden"):
            continue
        record = {
            "name": app["name"],
            "desktop_id": app["desktop_id"],
            "desktop_file": app["desktop_file"],
            "icon": app["icon"],
            "exec": app["exec"],
            "is_default": is_default,
            "is_recommended": is_default or is_compatible,
            "categories": app.get("categories", []),
            "no_display": bool(app.get("no_display")),
            "terminal": bool(app.get("terminal")),
        }
        if record["is_recommended"]:
            recommended.append(record)

    recommended.sort(key=lambda item: (not item["is_default"], str(item["name"]).casefold()))
    recommended = _dedupe_desktop_apps(recommended)
    sections = []
    if recommended:
        sections.append({"id": "recommended", "title": "Aplicativos recomendados", "apps": recommended})
    apps = [app for section in sections for app in section["apps"]]
    return {
        "ok": True,
        "path": str(path),
        "is_directory": path.is_dir(),
        "mime": mime_type,
        "default": default_id,
        "sections": sections,
        "apps": apps,
    }


def launch_open_with(path_text: str, desktop_file_text: str, popen=subprocess.Popen) -> dict[str, object]:
    path = Path(path_text).expanduser().resolve()
    desktop_file = Path(desktop_file_text).expanduser().resolve()
    if not path.exists() or not (path.is_file() or path.is_dir()):
        return {"ok": False, "error": "Arquivo nao encontrado"}
    if not desktop_file.is_file():
        return {"ok": False, "error": "Aplicativo nao encontrado"}

    process = popen(
        ["gio", "launch", str(desktop_file), path.as_uri()],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return {"ok": True, "pid": process.pid}


def set_default_open_with(
    path_text: str,
    desktop_file_text: str,
    mime_runner=None,
    default_runner=subprocess.run,
) -> dict[str, object]:
    path = Path(path_text).expanduser().resolve()
    desktop_file = Path(desktop_file_text).expanduser().resolve()
    if not path.exists() or not (path.is_file() or path.is_dir()):
        return {"ok": False, "error": "Arquivo nao encontrado"}
    if not desktop_file.is_file():
        return {"ok": False, "error": "Aplicativo nao encontrado"}

    mime_type = _query_file_mime(path, mime_runner)
    desktop_id = desktop_file.name
    default_runner(
        ["xdg-mime", "default", desktop_id, mime_type],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return {"ok": True, "mime": mime_type, "default": desktop_id}


def _json_event(payload: dict[str, object]) -> None:
    import json
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def _error_code_from_exception(exc: Exception) -> str:
    msg = str(exc).lower()
    if "permission denied" in msg:
        return "permission_denied"
    if "no such file" in msg or "not found" in msg:
        return "not_found"
    if "invalid" in msg:
        return "invalid_path"
    return "operation_failed"


def _pick_extractor(archive_path: Path, which_runner=shutil.which) -> list[str]:
    lower = archive_path.name.lower()
    if lower.endswith(".zip"):
        if which_runner("unzip"):
            return ["unzip", "-o", str(archive_path), "-d"]
        if which_runner("bsdtar"):
            return ["bsdtar", "-xf", str(archive_path), "-C"]
        raise RuntimeError("missing_tool: unzip/bsdtar")
    if lower.endswith(".rar"):
        if which_runner("unrar"):
            return ["unrar", "x", "-o+", str(archive_path)]
        if which_runner("7z"):
            return ["7z", "x", "-y", str(archive_path)]
        raise RuntimeError("missing_tool: unrar/7z")
    if lower.endswith(".7z"):
        if which_runner("7z"):
            return ["7z", "x", "-y", str(archive_path)]
        raise RuntimeError("missing_tool: 7z")
    if which_runner("bsdtar"):
        return ["bsdtar", "-xf", str(archive_path), "-C"]
    if which_runner("tar"):
        return ["tar", "-xf", str(archive_path), "-C"]
    raise RuntimeError("missing_tool: bsdtar/tar")


def _tool_password_args(tool: str, password: str | None) -> list[str]:
    if tool == "unzip":
        return ["-P", password] if password is not None else []
    if tool == "unrar":
        return [f"-p{password}"] if password is not None else ["-p-"]
    if tool == "7z":
        return [f"-p{password}"] if password is not None else ["-p-"]
    return []


def _archive_requires_password(archive_path: Path, which_runner=shutil.which) -> bool:
    if not which_runner("7z"):
        return False
    try:
        result = subprocess.run(
            ["7z", "l", "-slt", "-p-", "-y", str(archive_path)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=8,
        )
    except Exception:
        return False
    output = f"{result.stdout}\n{result.stderr}".lower()
    if "encrypted = +" in output:
        return True
    return result.returncode != 0 and any(token in output for token in ("password", "encrypted", "wrong password"))


def _run_text(cmd: list[str], timeout: int = 12) -> str:
    result = subprocess.run(
        cmd,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout,
    )
    return result.stdout


def _list_zip_entries(archive_path: Path) -> list[dict[str, object]]:
    entries: list[dict[str, object]] = []
    try:
        with zipfile.ZipFile(archive_path) as archive:
            for info in archive.infolist():
                if info.is_dir():
                    continue
                entries.append({"name": info.filename, "size": max(0, int(info.file_size or 0))})
    except Exception:
        return []
    return entries


def _list_tar_entries(archive_path: Path) -> list[dict[str, object]]:
    entries: list[dict[str, object]] = []
    try:
        with tarfile.open(archive_path) as archive:
            for member in archive.getmembers():
                if member.isdir():
                    continue
                entries.append({"name": member.name, "size": max(0, int(member.size or 0))})
    except Exception:
        return []
    return entries


def _is_tar_archive(archive_path: Path) -> bool:
    return archive_path.name.lower().endswith((".tar", ".tar.gz", ".tgz", ".tar.bz2", ".tbz2", ".tar.xz", ".txz"))


def _list_archive_entries(archive_path: Path, password: str | None = None, which_runner=shutil.which) -> list[object]:
    lower = archive_path.name.lower()
    if lower.endswith(".zip"):
        zip_entries = _list_zip_entries(archive_path)
        if zip_entries:
            return zip_entries
    if lower.endswith((".tar", ".tar.gz", ".tgz", ".tar.bz2", ".tbz2", ".tar.xz", ".txz")):
        tar_entries = _list_tar_entries(archive_path)
        if tar_entries:
            return tar_entries

    commands: list[list[str]] = []
    if lower.endswith(".zip") and which_runner("unzip"):
        commands.append(["unzip", "-Z1", str(archive_path)])
    if lower.endswith(".rar") and which_runner("unrar"):
        commands.append(["unrar", "lb"] + _tool_password_args("unrar", password) + [str(archive_path)])
    if which_runner("7z"):
        commands.append(["7z", "l", "-slt", "-y"] + _tool_password_args("7z", password) + [str(archive_path)])
    if which_runner("bsdtar"):
        commands.append(["bsdtar", "-tf", str(archive_path)])

    for cmd in commands:
        try:
            output = _run_text(cmd)
        except Exception:
            continue
        entries: list[str] = []
        if cmd[0] == "7z":
            current: dict[str, object] = {}
            for line in output.splitlines():
                if not line.strip():
                    if current.get("name") and not current.get("is_dir"):
                        entries.append({"name": str(current.get("name")), "size": int(current.get("size") or 0)})
                    current = {}
                    continue
                if line.startswith("Path = "):
                    value = line.split("=", 1)[1].strip()
                    if value and value != str(archive_path):
                        current["name"] = value
                elif line.startswith("Size = "):
                    value = line.split("=", 1)[1].strip()
                    current["size"] = int(value) if value.isdigit() else 0
                elif line.startswith("Folder = "):
                    current["is_dir"] = line.split("=", 1)[1].strip() == "+"
            if current.get("name") and not current.get("is_dir"):
                entries.append({"name": str(current.get("name")), "size": int(current.get("size") or 0)})
        else:
            entries = [line.strip() for line in output.splitlines() if line.strip()]
        return [
            entry for entry in entries
            if _archive_entry_name(entry) and not _archive_entry_name(entry).endswith("/")
        ]
    return []


def _archive_entry_name(entry: object) -> str:
    if isinstance(entry, dict):
        return str(entry.get("name") or "")
    return str(entry or "")


def _archive_entry_size(entry: object) -> int:
    if isinstance(entry, dict):
        try:
            return max(0, int(entry.get("size") or 0))
        except (TypeError, ValueError):
            return 0
    return 0


def _count_extracted_entries(destination: Path) -> int:
    if not destination.exists():
        return 0
    count = 0
    for _root, _dirs, files in os.walk(destination):
        count += len(files)
    return count


def _count_extracted_bytes(destination: Path) -> int:
    if not destination.exists():
        return 0
    total = 0
    for root, _dirs, files in os.walk(destination):
        base = Path(root)
        for name in files:
            try:
                total += (base / name).stat().st_size
            except OSError:
                continue
    return total


def _format_eta(seconds: float | int | None) -> str:
    if seconds is None:
        return ""
    value = max(0, int(round(float(seconds))))
    if value <= 0:
        return "agora"
    if value < 60:
        return f"{value}s restantes"
    minutes, secs = divmod(value, 60)
    if minutes < 60:
        return f"{minutes}m {secs:02d}s restantes"
    hours, minutes = divmod(minutes, 60)
    return f"{hours}h {minutes:02d}m restantes"




def _is_unsafe_archive_entry(name: str) -> bool:
    value = (name or "").strip().replace("\\", "/")
    if not value:
        return False
    if value.startswith("/"):
        return True
    parts = [p for p in value.split("/") if p not in ("", ".")]
    if any(p == ".." for p in parts):
        return True
    lowered = value.lower()
    if "->" in lowered and ".." in lowered:
        return True
    return False


def validate_archive_entries(entries: list[str]) -> None:
    for entry in entries:
        if _is_unsafe_archive_entry(entry):
            raise ValueError(f"unsafe archive entry: {entry}")
def _archive_progress_payload(
    mode: str,
    done: int,
    total: int,
    start_time: float,
    now,
    bytes_done: int = 0,
    bytes_total: int = 0,
) -> dict[str, object]:
    total = max(0, int(total or 0))
    done = max(0, int(done or 0))
    bytes_done = max(0, int(bytes_done or 0))
    bytes_total = max(0, int(bytes_total or 0))
    if bytes_total > 0:
        percent = bytes_done / bytes_total * 100
        progress_done = min(bytes_done, bytes_total)
        progress_total = bytes_total
    else:
        percent = (done / total * 100) if total > 0 else 0
        progress_done = done
        progress_total = total
    eta_seconds = None
    if progress_total > 0 and 0 < progress_done < progress_total:
        elapsed = max(0.1, now() - start_time)
        eta_seconds = (elapsed / progress_done) * (progress_total - progress_done)
    elif progress_total > 0 and progress_done >= progress_total:
        eta_seconds = 0
    payload: dict[str, object] = {
        "event": "progress",
        "mode": mode,
        "done": done,
        "total": total,
        "percent": min(99, percent) if progress_total > 0 and progress_done < progress_total else min(100, percent),
        "bytes_done": bytes_done,
        "bytes_total": bytes_total,
    }
    if eta_seconds is not None:
        payload["eta_seconds"] = int(round(eta_seconds))
        payload["eta_text"] = _format_eta(eta_seconds)
    return payload


def _build_extract_command(base_cmd: list[str], destination: Path, password: str | None) -> list[str]:
    tool = base_cmd[0]
    if tool == "unzip":
        return ["unzip"] + _tool_password_args("unzip", password) + base_cmd[1:] + [str(destination)]
    if tool == "unrar":
        return base_cmd[:2] + _tool_password_args("unrar", password) + base_cmd[2:] + [str(destination) + "/"]
    if tool == "7z":
        return base_cmd[:3] + _tool_password_args("7z", password) + base_cmd[3:] + [f"-o{destination}"]
    return base_cmd + [str(destination)]


def _apply_tar_metadata(target: Path, member: tarfile.TarInfo) -> None:
    if member.mode is not None:
        try:
            os.chmod(target, member.mode & 0o777)
        except OSError:
            pass
    try:
        os.utime(target, (member.mtime, member.mtime))
    except OSError:
        pass


def _extract_tar_archive_streaming(
    archive_path: Path,
    destination: Path,
    start_time: float,
    now,
) -> tuple[int, int]:
    done = 0
    bytes_done = 0

    with tarfile.open(archive_path, mode="r|*") as archive:
        for member in archive:
            validate_archive_entries([member.name])
            try:
                filtered = tarfile.data_filter(member, str(destination))
            except tarfile.FilterError as exc:
                raise ValueError(str(exc)) from exc
            if filtered is None:
                continue

            target = destination / filtered.name
            if filtered.isdir():
                target.mkdir(parents=True, exist_ok=True)
                _apply_tar_metadata(target, filtered)
                continue

            if filtered.isfile():
                source = archive.extractfile(member)
                if source is None:
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                with source, target.open("wb") as output:
                    while True:
                        chunk = source.read(1024 * 1024)
                        if not chunk:
                            break
                        output.write(chunk)
                        bytes_done += len(chunk)
                _apply_tar_metadata(target, filtered)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                archive.extract(member, str(destination), filter="data")

            done += 1
            _json_event(_archive_progress_payload("extract", done, 0, start_time, now, bytes_done, 0))

    return done, bytes_done


def _called_process_error_code(exc: subprocess.CalledProcessError) -> str:
    output = ""
    for value in (getattr(exc, "stdout", None), getattr(exc, "stderr", None)):
        if isinstance(value, bytes):
            output += value.decode("utf-8", "replace")
        elif isinstance(value, str):
            output += value
    lowered = output.lower()
    if any(token in lowered for token in ("wrong password", "incorrect password", "password")):
        return "wrong_password"
    return _error_code_from_exception(exc)


def _read_password_from_stdin() -> str:
    value = sys.stdin.readline()
    if value.endswith("\n"):
        value = value[:-1]
    if value.endswith("\r"):
        value = value[:-1]
    return value


def _remove_path(path: Path) -> None:
    if not path.exists() and not path.is_symlink():
        return
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    else:
        path.unlink()


def _prepare_extract_destination(parent: Path, name: str, conflict_policy: str) -> tuple[Path, Path | None]:
    safe_name = _validate_child_name(name, "destination_name")
    target = parent / safe_name
    policy = (conflict_policy or "keep-both").lower()
    if policy not in {"ask", "keep-both", "merge", "overwrite"}:
        raise RuntimeError(f"invalid_conflict_policy: {conflict_policy}")

    if not _path_exists(target):
        return target, None

    if policy == "ask":
        _json_event({
            "event": "conflict",
            "mode": "extract",
            "destination": str(target),
            "name": target.name,
            "is_directory": target.is_dir(),
        })
        raise SystemExit(4)

    if policy == "keep-both":
        return _unique_target(parent, name), None

    if policy == "merge":
        if target.is_dir():
            return target, None
        raise RuntimeError("merge_requires_directory")

    backup = _unique_target(parent, f".{target.name}.astrea-overwrite-backup")
    os.rename(target, backup)
    return target, backup


def _restore_extract_backup(destination: Path, backup: Path | None, remove_without_backup: bool = True) -> None:
    if backup is None:
        if remove_without_backup:
            _remove_path(destination)
        return
    _remove_path(destination)
    os.rename(backup, destination)


def _finish_extract_backup(backup: Path | None) -> None:
    if backup is not None:
        _remove_path(backup)


def extract_archive(
    archive_path_text: str,
    folder_name: str,
    password: str | None = None,
    conflict_policy: str = "keep-both",
    run_cmd=None,
    list_runner=None,
    password_probe=None,
    which_runner=shutil.which,
    now=time.monotonic,
) -> None:
    archive_path = Path(archive_path_text).expanduser()
    if not archive_path.exists():
        _json_event({"event": "error", "mode": "extract", "code": "not_found", "message": "archive not found"})
        raise SystemExit(1)

    probe = password_probe or _archive_requires_password
    if password is None and probe(archive_path):
        _json_event({"event": "password_required", "mode": "extract", "name": archive_path.name})
        raise SystemExit(3)

    parent = archive_path.parent
    destination: Path
    backup: Path | None
    destination = parent / (folder_name or archive_path.name)
    backup = None
    destination_preexisting = False
    entry_lister = list_runner or _list_archive_entries
    entries: list[object] = []
    total = 0
    total_bytes = 0
    runner = run_cmd or subprocess.run
    start_time = now()
    baseline_count = 0
    baseline_bytes = 0
    try:
        destination, backup = _prepare_extract_destination(parent, folder_name or archive_path.name, conflict_policy)
        destination_preexisting = _path_exists(destination)
        if run_cmd is None and list_runner is None and _is_tar_archive(archive_path):
            destination.mkdir(parents=True, exist_ok=True)
            _json_event({
                "event": "start",
                "mode": "extract",
                "name": archive_path.name,
                "destination": str(destination),
                "total": 0,
                "bytes_total": 0,
            })
            done, bytes_done = _extract_tar_archive_streaming(archive_path, destination, start_time, now)
            total = done
            total_bytes = bytes_done
            _json_event(_archive_progress_payload("extract", done, total, start_time, now, bytes_done, total_bytes))
            _json_event({
                "event": "done",
                "mode": "extract",
                "destination": str(destination),
                "done": done,
                "total": total,
                "percent": 100,
                "eta_seconds": 0,
                "eta_text": _format_eta(0),
                "bytes_done": bytes_done,
                "bytes_total": total_bytes,
            })
            _finish_extract_backup(backup)
            return

        entries = entry_lister(archive_path, password, which_runner)
        entry_names = [_archive_entry_name(entry) for entry in entries]
        total = max(0, len(entry_names))
        total_bytes = sum(_archive_entry_size(entry) for entry in entries)
        validate_archive_entries(entry_names)
        destination.mkdir(parents=True, exist_ok=True)
        baseline_count = _count_extracted_entries(destination)
        baseline_bytes = _count_extracted_bytes(destination)
        _json_event({
            "event": "start",
            "mode": "extract",
            "name": archive_path.name,
            "destination": str(destination),
            "total": total,
            "bytes_total": total_bytes,
        })
        cmd = _pick_extractor(archive_path, which_runner)
        final_cmd = _build_extract_command(cmd, destination, password)
        if run_cmd is None:
            with tempfile.TemporaryFile() as stdout_tmp, tempfile.TemporaryFile() as stderr_tmp:
                proc = subprocess.Popen(final_cmd, stdout=stdout_tmp, stderr=stderr_tmp)
                last_done = -1
                last_bytes_done = -1
                while proc.poll() is None:
                    done = max(0, _count_extracted_entries(destination) - baseline_count)
                    bytes_done = max(0, _count_extracted_bytes(destination) - baseline_bytes)
                    if done != last_done or bytes_done != last_bytes_done:
                        _json_event(_archive_progress_payload(
                            "extract",
                            done,
                            total,
                            start_time,
                            now,
                            bytes_done,
                            total_bytes,
                        ))
                        last_done = done
                        last_bytes_done = bytes_done
                    time.sleep(0.35)
                proc.wait()
                if proc.returncode != 0:
                    stdout_tmp.seek(0)
                    stderr_tmp.seek(0)
                    raise subprocess.CalledProcessError(
                        proc.returncode,
                        final_cmd,
                        output=stdout_tmp.read(),
                        stderr=stderr_tmp.read(),
                    )
        else:
            runner(final_cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        done = max(0, _count_extracted_entries(destination) - baseline_count)
        bytes_done = max(0, _count_extracted_bytes(destination) - baseline_bytes)
        if total > 0 and done < total:
            done = total
        if total <= 0:
            total = done
        if total_bytes > 0 and bytes_done < total_bytes:
            bytes_done = total_bytes
        _json_event(_archive_progress_payload("extract", done, total, start_time, now, bytes_done, total_bytes))
        _json_event({
            "event": "done",
            "mode": "extract",
            "destination": str(destination),
            "done": done,
            "total": total,
            "percent": 100,
            "eta_seconds": 0,
            "eta_text": _format_eta(0),
            "bytes_done": bytes_done,
            "bytes_total": total_bytes,
        })
        _finish_extract_backup(backup)
    except RuntimeError as exc:
        _restore_extract_backup(destination, backup, not destination_preexisting)
        msg = str(exc)
        code = "missing_tool" if "missing_tool" in msg else _error_code_from_exception(exc)
        _json_event({"event": "error", "mode": "extract", "code": code, "message": msg, "destination": str(destination)})
        raise SystemExit(1)
    except subprocess.CalledProcessError as exc:
        _restore_extract_backup(destination, backup, not destination_preexisting)
        code = _called_process_error_code(exc)
        message = "Senha incorreta" if code == "wrong_password" else str(exc)
        _json_event({"event": "error", "mode": "extract", "code": code, "message": message, "destination": str(destination)})
        raise SystemExit(1)
    except Exception as exc:
        _restore_extract_backup(destination, backup, not destination_preexisting)
        _json_event({"event": "error", "mode": "extract", "code": _error_code_from_exception(exc), "message": str(exc), "destination": str(destination)})
        raise SystemExit(1)


def compress_folder(folder_path_text: str, archive_format: str, run_cmd=None, which_runner=shutil.which) -> None:
    folder = Path(folder_path_text).expanduser()
    if not folder.is_dir():
        _json_event({"event": "error", "mode": "compress", "code": "not_found", "message": "folder not found"})
        raise SystemExit(1)
    ext = ARCHIVE_FORMAT_EXTENSIONS.get(archive_format)
    if not ext:
        _json_event({"event": "error", "mode": "compress", "code": "invalid_format", "message": "unsupported format"})
        raise SystemExit(1)
    target = _unique_target(folder.parent, f"{folder.name}.{ext}")
    _json_event({"event": "start", "mode": "compress", "name": folder.name, "destination": str(target), "total": 1})
    runner = run_cmd or subprocess.run
    try:
        if archive_format == "zip":
            if not which_runner("zip"): raise RuntimeError("zip")
            runner(["zip", "-qr", str(target), folder.name], check=True, cwd=str(folder.parent), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        elif archive_format == "rar":
            if not which_runner("rar"): raise RuntimeError("rar")
            runner(["rar", "a", "-idq", str(target), folder.name], check=True, cwd=str(folder.parent), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        else:
            if not which_runner("tar"): raise RuntimeError("tar")
            args = {"tar": ["tar", "-cf"], "tar.gz": ["tar", "-czf"], "tar.xz": ["tar", "-cJf"]}[archive_format]
            runner(args + [str(target), folder.name], check=True, cwd=str(folder.parent), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        _json_event({"event": "progress", "mode": "compress", "done": 1, "total": 1, "percent": 100})
        _json_event({"event": "done", "mode": "compress", "destination": str(target), "done": 1, "total": 1, "percent": 100})
    except RuntimeError as exc:
        _json_event({"event": "error", "mode": "compress", "code": "missing_tool", "message": f"missing_tool: {exc}", "destination": str(target)})
        raise SystemExit(1)
    except Exception as exc:
        _json_event({"event": "error", "mode": "compress", "code": _error_code_from_exception(exc), "message": str(exc), "destination": str(target)})
        raise SystemExit(1)


def _path_type(path: Path) -> str:
    try:
        path.lstat()
    except OSError:
        return "missing"
    if path.is_symlink():
        return "symlink"
    if path.is_dir():
        return "directory"
    if path.is_file():
        return "file"
    return "other"


def _resolved_path(path: Path) -> Path:
    try:
        return path.resolve(strict=False)
    except OSError:
        return path.absolute()


def _is_same_or_descendant(source: Path, target: Path) -> bool:
    source_resolved = _resolved_path(source)
    target_resolved = _resolved_path(target)
    return target_resolved == source_resolved or source_resolved in target_resolved.parents


def _conflict_record(source: Path, destination: Path) -> dict[str, object] | None:
    target = destination / source.name
    source_type = _path_type(source)
    if source_type == "directory" and _is_same_or_descendant(source, target):
        return {
            "source": str(source),
            "destination": str(target),
            "name": source.name,
            "source_type": source_type,
            "destination_type": _path_type(target),
            "conflict_kind": "directory-into-self",
            "supported_policies": ["skip"],
        }
    if source == target:
        return {
            "source": str(source),
            "destination": str(target),
            "name": source.name,
            "source_type": _path_type(source),
            "destination_type": _path_type(target),
            "conflict_kind": "same-path",
            "supported_policies": ["skip"],
        }
    if not _path_exists(target):
        return None

    destination_type = _path_type(target)
    if source_type == "directory" and destination_type == "directory":
        conflict_kind = "directory-merge"
        policies = ["skip", "overwrite", "keep-both", "merge"]
    elif source_type == "file" and destination_type == "file":
        conflict_kind = "file-replace"
        policies = ["skip", "overwrite", "keep-both", "rename"]
    elif source_type == "directory" and destination_type == "file":
        conflict_kind = "directory-over-file"
        policies = ["skip"]
    elif source_type == "file" and destination_type == "directory":
        conflict_kind = "file-over-directory"
        policies = ["skip"]
    else:
        conflict_kind = "name-collision"
        policies = ["skip", "keep-both"]

    return {
        "source": str(source),
        "destination": str(target),
        "name": source.name,
        "source_type": source_type,
        "destination_type": destination_type,
        "conflict_kind": conflict_kind,
        "supported_policies": policies,
    }


def scan_conflicts(destination_text: str, paths: list[str], output_format: str = "names") -> None:
    import json

    destination = Path(destination_text).expanduser()
    conflicts: list[dict[str, object]] = []
    for raw in paths:
        source = Path(raw).expanduser()
        record = _conflict_record(source, destination)
        if record is not None:
            conflicts.append(record)

    if output_format == "json":
        print(json.dumps(conflicts, ensure_ascii=False))
        return

    for item in conflicts:
        print(item["name"])


IN_CLOSE_WRITE = 0x00000008
IN_MOVED_FROM = 0x00000040
IN_MOVED_TO = 0x00000080
IN_CREATE = 0x00000100
IN_DELETE = 0x00000200
IN_DELETE_SELF = 0x00000400
IN_MOVE_SELF = 0x00000800
IN_ATTRIB = 0x00000004
IN_ONLYDIR = 0x01000000
IN_ISDIR = 0x40000000
IN_NONBLOCK = 0x00000800
IN_CLOEXEC = 0x00080000
DIR_WATCH_MASK = IN_CLOSE_WRITE | IN_MOVED_FROM | IN_MOVED_TO | IN_CREATE | IN_DELETE | IN_DELETE_SELF | IN_MOVE_SELF | IN_ATTRIB
DIR_REFRESH_MASK = IN_CLOSE_WRITE | IN_MOVED_FROM | IN_MOVED_TO | IN_CREATE | IN_DELETE | IN_DELETE_SELF | IN_MOVE_SELF
INOTIFY_EVENT_STRUCT = struct.Struct("iIII")


def _dir_signature(path: Path) -> tuple:
    try:
        entries = []
        for entry in path.iterdir():
            try:
                stat = entry.stat()
            except OSError:
                continue
            entries.append((entry.name, stat.st_mtime_ns, stat.st_size, stat.st_mode))
        return tuple(sorted(entries))
    except OSError:
        return ()


def _emit_changed() -> None:
    print("changed", flush=True)


def _unique_target(parent: Path, name: str) -> Path:
    candidate = parent / name
    if not _path_exists(candidate):
        return candidate
    stem, ext = os.path.splitext(name)
    index = 2
    while True:
        candidate = parent / f"{stem} {index}{ext}"
        if not _path_exists(candidate):
            return candidate
        index += 1


def _encode_trash_path(path: Path) -> str:
    return urllib.parse.quote(str(path), safe="/")


def _decode_trash_path(path_text: str) -> str:
    return urllib.parse.unquote(path_text)


def trash_items(trash_files_text: str, trash_info_text: str, paths: list[str]) -> None:
    trash_files = Path(trash_files_text).expanduser()
    trash_info = Path(trash_info_text).expanduser()
    trash_files.mkdir(parents=True, exist_ok=True)
    trash_info.mkdir(parents=True, exist_ok=True)
    deletion_date = time.strftime("%Y-%m-%dT%H:%M:%S")

    for raw in paths:
        source = Path(raw).expanduser()
        if not _path_exists(source):
            continue
        destination = _unique_target(trash_files, source.name)
        shutil.move(str(source), str(destination))
        info_path = trash_info / f"{destination.name}.trashinfo"
        info_path.write_text(
            "[Trash Info]\n"
            f"Path={_encode_trash_path(source)}\n"
            f"DeletionDate={deletion_date}\n",
            encoding="utf-8",
        )


def restore_trash_items(trash_info_text: str, fallback_dir_text: str, paths: list[str]) -> None:
    trash_info = Path(trash_info_text).expanduser()
    fallback_dir = Path(fallback_dir_text).expanduser()
    fallback_dir.mkdir(parents=True, exist_ok=True)

    for raw in paths:
        trashed = Path(raw).expanduser()
        if not _path_exists(trashed):
            continue
        info_path = trash_info / f"{trashed.name}.trashinfo"

        original = ""
        if info_path.exists():
            try:
                for line in info_path.read_text(encoding="utf-8").splitlines():
                    if line.startswith("Path="):
                        original = _decode_trash_path(line[5:])
                        break
            except OSError:
                original = ""

        target = Path(original) if original else (fallback_dir / trashed.name)
        parent = target.parent
        try:
            parent.mkdir(parents=True, exist_ok=True)
        except OSError:
            parent = fallback_dir

        final_target = _unique_target(parent, target.name)
        shutil.move(str(trashed), str(final_target))
        info_path.unlink(missing_ok=True)


def empty_trash(trash_files_text: str, trash_info_text: str) -> None:
    trash_files = Path(trash_files_text).expanduser()
    trash_info = Path(trash_info_text).expanduser()
    trash_files.mkdir(parents=True, exist_ok=True)
    trash_info.mkdir(parents=True, exist_ok=True)

    for entry in trash_files.iterdir():
        if entry.is_dir() and not entry.is_symlink():
            shutil.rmtree(entry, ignore_errors=True)
        else:
            entry.unlink(missing_ok=True)

    for entry in trash_info.iterdir():
        if entry.is_dir() and not entry.is_symlink():
            shutil.rmtree(entry, ignore_errors=True)
        else:
            entry.unlink(missing_ok=True)


def _iter_inotify_masks(data: bytes):
    offset = 0
    size = INOTIFY_EVENT_STRUCT.size
    while offset + size <= len(data):
        _, mask, _, name_len = INOTIFY_EVENT_STRUCT.unpack_from(data, offset)
        yield mask
        offset += size + name_len


def _should_emit_directory_change(masks) -> bool:
    for mask in masks:
        if mask & DIR_REFRESH_MASK:
            return True
    return False


def _parent_is_alive(parent_pid: int) -> bool:
    return parent_pid > 1 and os.getppid() == parent_pid and process_alive(parent_pid)


def _drain_inotify(fd: int) -> list[int]:
    masks: list[int] = []
    try:
        while True:
            data = os.read(fd, 4096)
            if not data:
                break
            masks.extend(_iter_inotify_masks(data))
    except BlockingIOError:
        return masks
    except OSError:
        return masks
    return masks


def monitor_dir(path_text: str) -> None:
    path = Path(path_text).expanduser()
    if not path.is_dir():
        raise SystemExit(2)
    parent_pid = os.getppid()

    try:
        libc = ctypes.CDLL("libc.so.6", use_errno=True)
        fd = libc.inotify_init1(IN_NONBLOCK | IN_CLOEXEC)
        if fd < 0:
            raise OSError(ctypes.get_errno())
        wd = libc.inotify_add_watch(fd, os.fsencode(path), DIR_WATCH_MASK | IN_ONLYDIR)
        if wd < 0:
            os.close(fd)
            raise OSError(ctypes.get_errno())
    except Exception:
        last = _dir_signature(path)
        while _parent_is_alive(parent_pid):
            time.sleep(1)
            current = _dir_signature(path)
            if current != last:
                last = current
                _emit_changed()
        return

    poller = select.poll()
    poller.register(fd, select.POLLIN | select.POLLERR | select.POLLHUP)
    try:
        while _parent_is_alive(parent_pid):
            events = poller.poll(1000)
            if not events:
                continue
            masks = _drain_inotify(fd)
            if _should_emit_directory_change(masks):
                _emit_changed()
    finally:
        os.close(fd)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Small UI helpers for Astrea Explorer.")
    sub = parser.add_subparsers(dest="command", required=True)

    create = sub.add_parser("create-folder")
    create.add_argument("base")
    create.add_argument("name")

    rename = sub.add_parser("rename")
    rename.add_argument("source")
    rename.add_argument("new_name")

    suggest = sub.add_parser("suggest-dirs")
    suggest.add_argument("base")
    suggest.add_argument("prefix")
    suggest.add_argument("--request-id", default="")

    which = sub.add_parser("which")
    which.add_argument("program")

    probe = sub.add_parser("network-mount-probe")
    probe.add_argument("root")

    copy_uri = sub.add_parser("copy-uri-list")
    copy_uri.add_argument("paths", nargs="+")

    conflicts = sub.add_parser("scan-conflicts")
    conflicts.add_argument("destination")
    conflicts.add_argument("paths", nargs="+")
    conflicts.add_argument("--format", choices=["names", "json"], default="names")

    monitor = sub.add_parser("monitor-dir")
    monitor.add_argument("path")

    trash = sub.add_parser("trash")
    trash.add_argument("trash_files")
    trash.add_argument("trash_info")
    trash.add_argument("paths", nargs="+")

    restore = sub.add_parser("restore-trash")
    restore.add_argument("trash_info")
    restore.add_argument("fallback_dir")
    restore.add_argument("paths", nargs="+")

    empty = sub.add_parser("empty-trash")
    empty.add_argument("trash_files")
    empty.add_argument("trash_info")

    paste_image_cmd = sub.add_parser("paste-image")
    paste_image_cmd.add_argument("destination_dir")
    paste_image_cmd.add_argument("mime_type")
    extract_cmd = sub.add_parser("extract-archive")
    extract_cmd.add_argument("archive_path")
    extract_cmd.add_argument("folder_name")
    extract_cmd.add_argument("--password")
    extract_cmd.add_argument("--password-stdin", action="store_true")
    extract_cmd.add_argument("--conflict-policy", choices=["ask", "keep-both", "merge", "overwrite"], default="keep-both")
    compress_cmd = sub.add_parser("compress-folder")
    compress_cmd.add_argument("folder_path")
    compress_cmd.add_argument("archive_format")
    desktop_shortcut_cmd = sub.add_parser("create-desktop-shortcut")
    desktop_shortcut_cmd.add_argument("path")

    merged_recents_cmd = sub.add_parser("merged-recents")
    merged_recents_cmd.add_argument("finder_recents")
    merged_recents_cmd.add_argument("launch_history")
    merged_recents_cmd.add_argument("xbel_recents")
    merged_recents_cmd.add_argument("--limit", type=int, default=60)

    open_with_cmd = sub.add_parser("open-with-apps")
    open_with_cmd.add_argument("path")
    launch_with_cmd = sub.add_parser("launch-open-with")
    launch_with_cmd.add_argument("path")
    launch_with_cmd.add_argument("desktop_file")
    default_with_cmd = sub.add_parser("set-default-open-with")
    default_with_cmd.add_argument("path")
    default_with_cmd.add_argument("desktop_file")

    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.command == "create-folder":
        create_folder(args.base, args.name)
    elif args.command == "rename":
        rename_path(args.source, args.new_name)
    elif args.command == "suggest-dirs":
        suggest_dirs(args.base, args.prefix, args.request_id)
    elif args.command == "which":
        raise SystemExit(0 if shutil.which(args.program) else 1)
    elif args.command == "network-mount-probe":
        network_mount_probe(args.root)
    elif args.command == "copy-uri-list":
        copy_uri_list(args.paths)
    elif args.command == "scan-conflicts":
        scan_conflicts(args.destination, args.paths, args.format)
    elif args.command == "monitor-dir":
        monitor_dir(args.path)
    elif args.command == "trash":
        trash_items(args.trash_files, args.trash_info, args.paths)
    elif args.command == "restore-trash":
        restore_trash_items(args.trash_info, args.fallback_dir, args.paths)
    elif args.command == "empty-trash":
        empty_trash(args.trash_files, args.trash_info)
    elif args.command == "paste-image":
        paste_image(args.destination_dir, args.mime_type)
    elif args.command == "extract-archive":
        password = _read_password_from_stdin() if args.password_stdin else args.password
        extract_archive(args.archive_path, args.folder_name, password=password, conflict_policy=args.conflict_policy)
    elif args.command == "compress-folder":
        compress_folder(args.folder_path, args.archive_format)
    elif args.command == "create-desktop-shortcut":
        print(json.dumps(create_desktop_shortcut(args.path), ensure_ascii=False), flush=True)
    elif args.command == "merged-recents":
        print(
            json.dumps(
                merged_recents(args.finder_recents, args.launch_history, args.xbel_recents, args.limit),
                ensure_ascii=False,
            ),
            flush=True,
        )
    elif args.command == "open-with-apps":
        print(json.dumps(open_with_apps(args.path), ensure_ascii=False), flush=True)
    elif args.command == "launch-open-with":
        print(json.dumps(launch_open_with(args.path, args.desktop_file), ensure_ascii=False), flush=True)
    elif args.command == "set-default-open-with":
        print(json.dumps(set_default_open_with(args.path, args.desktop_file), ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
