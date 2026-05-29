#!/usr/bin/env python3
"""Shared runtime helpers for Astrea backend scripts."""

from __future__ import annotations

import configparser
import json
import locale
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Any

FALLBACK_ICON = "application-x-executable"


def astrea_root() -> Path:
    return Path(os.environ.get("ASTREA_ROOT", Path.home() / ".local/share/Astrea")).expanduser()


def atomic_write_text(path: Path, text: str, *, encoding: str = "utf-8") -> None:
    """Write text via a same-directory temporary file and atomic replace."""
    path = Path(path).expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent))
    tmp = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding=encoding) as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, path)
    except Exception:
        try:
            tmp.unlink()
        except FileNotFoundError:
            pass
        raise


def atomic_write_json(path: Path, payload: Any, *, indent: int | None = 2, sort_keys: bool = False) -> None:
    text = json.dumps(payload, ensure_ascii=False, indent=indent, sort_keys=sort_keys)
    atomic_write_text(path, text + "\n")


def read_json(path: Path, default: Any) -> Any:
    try:
        with Path(path).expanduser().open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        return data
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return default


def xdg_data_home() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")).expanduser()


def xdg_config_home() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")).expanduser()


def xdg_state_home() -> Path:
    return Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")).expanduser()


def xdg_runtime_dir(app_name: str = "Astrea") -> Path:
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if runtime:
        return Path(runtime).expanduser() / app_name
    return xdg_state_home() / app_name / "runtime"


def xdg_desktop_dir() -> Path:
    config_path = xdg_config_home() / "user-dirs.dirs"
    fallback = Path.home() / "Desktop"
    try:
        for line in config_path.read_text(encoding="utf-8", errors="ignore").splitlines():
            line = line.strip()
            if not line.startswith("XDG_DESKTOP_DIR="):
                continue
            value = line.split("=", 1)[1].strip().strip('"')
            value = value.replace("$HOME", str(Path.home()))
            return Path(os.path.expandvars(value)).expanduser()
    except OSError:
        pass
    return fallback


def application_dirs() -> list[Path]:
    dirs = [xdg_data_home() / "applications"]
    for entry in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":"):
        if entry:
            dirs.append(Path(entry).expanduser() / "applications")
    deduped: list[Path] = []
    seen: set[str] = set()
    for path in dirs:
        key = str(path)
        if key not in seen:
            seen.add(key)
            deduped.append(path)
    return deduped


def _current_icon_theme() -> str:
    try:
        theme = subprocess.check_output(
            ["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"],
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=2,
        ).strip().strip("'")
        return theme or "hicolor"
    except Exception:
        return "hicolor"


def resolve_icon_path(icon_name: str) -> str:
    if not icon_name or "://" in icon_name:
        return ""
    candidate = Path(icon_name).expanduser()
    if candidate.is_file():
        return str(candidate)

    theme = _current_icon_theme()
    theme_variants = [theme]
    for suffix in ["-dark", "-light", "-Dark", "-Light"]:
        if theme.endswith(suffix):
            theme_variants.append(theme[: -len(suffix)])
    if "hicolor" not in theme_variants:
        theme_variants.append("hicolor")

    base_dirs = [Path.home() / ".local/share/icons", Path("/usr/share/icons")]
    sizes = ["256x256", "128x128", "96x96", "64x64", "48x48", "32x32", "24x24", "22x22", "16x16", "scalable"]
    exts = [".svg", ".png", ".xpm"]
    subpaths = ["{size}/apps/{name}{ext}", "apps/{size}/{name}{ext}", "apps/scalable/{name}{ext}"]

    for base in base_dirs:
        for theme_name in theme_variants:
            theme_dir = base / theme_name
            if not theme_dir.is_dir():
                continue
            for size in sizes:
                for subpath in subpaths:
                    for ext in exts:
                        path = theme_dir / subpath.format(size=size, name=icon_name, ext=ext)
                        if path.is_file():
                            return str(path)

    for ext in exts:
        pixmap = Path("/usr/share/pixmaps") / f"{icon_name}{ext}"
        if pixmap.is_file():
            return str(pixmap)
    return ""


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


def localized_value(entry: configparser.SectionProxy, base: str) -> str:
    for key in localized_keys(base):
        value = entry.get(key, "").strip()
        if value:
            return value
    return ""


def icon_has_localhost_reference(icon: str) -> bool:
    if "/" not in icon:
        return False
    path = Path(icon).expanduser()
    try:
        return path.suffix.lower() == ".svg" and path.is_file() and "localhost:" in path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return False


def safe_desktop_icon(icon: str, *, fallback: str = FALLBACK_ICON) -> str:
    icon = (icon or "").strip()
    if not icon or "://" in icon or icon_has_localhost_reference(icon):
        return fallback
    return icon


def parse_desktop_file(path: Path, *, source: str = "", skip_terminal: bool = False, require_exec: bool = False) -> dict[str, Any] | None:
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
    if entry.get("NoDisplay", "false").lower() == "true" or entry.get("Hidden", "false").lower() == "true":
        return None
    if skip_terminal and entry.get("Terminal", "false").lower() == "true":
        return None

    name = localized_value(entry, "Name")
    exec_line = entry.get("Exec", "").strip()
    if not name or (require_exec and not exec_line):
        return None

    icon_name = safe_desktop_icon(entry.get("Icon", ""), fallback=FALLBACK_ICON)
    categories = [part for part in entry.get("Categories", "").split(";") if part]
    return {
        "id": path.name,
        "name": name,
        "generic": localized_value(entry, "GenericName"),
        "comment": localized_value(entry, "Comment"),
        "exec": exec_line,
        "icon": icon_name,
        "icon_path": resolve_icon_path(icon_name),
        "categories": categories,
        "desktop_file": str(path),
        "desktop": str(path),
        "source": source,
        "protected": path.name == "astrea-settings.desktop",
    }


def run_command(command: list[str], *, timeout: float = 5.0) -> tuple[int, str, str]:
    """Run command and return (code, stdout, stderr) without raising."""
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
        return result.returncode, (result.stdout or ""), (result.stderr or "")
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 1, "", str(exc)


def error_payload(message: str, *, code: str = "error") -> dict[str, Any]:
    return {"ok": False, "code": code, "message": message}
