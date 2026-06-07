#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path
from typing import Any, Callable


Runner = Callable[[list[str], float], tuple[int, str, str]]


SERVICE_CATALOG: list[dict[str, Any]] = [
    {
        "key": "status",
        "unit": "astrea-status.service",
        "label": "System Status",
        "group": "Core",
        "description": "Cache de rede, audio, Bluetooth e estado usado pela topbar.",
        "impact": "Alto",
        "critical": True,
        "activation": "systemd",
        "managed_by": "systemd --user",
    },
    {
        "key": "launchd",
        "unit": "astrea-launchd.service",
        "label": "App Launcher",
        "group": "Core",
        "description": "Daemon que abre aplicativos pelo Astrea Launch.",
        "impact": "Alto",
        "critical": True,
        "activation": "systemd",
        "managed_by": "systemd --user",
    },
    {
        "key": "latency",
        "unit": "astrea-latencyd.service",
        "label": "Latency Boost",
        "group": "Core",
        "description": "Responde a pedidos temporarios de baixa latencia.",
        "impact": "Medio",
        "critical": False,
        "activation": "systemd",
        "managed_by": "systemd --user",
    },
    {
        "key": "weather",
        "unit": "astrea-weatherd.service",
        "label": "Weather Monitor",
        "group": "Apps",
        "description": "Atualiza clima e alertas em segundo plano.",
        "impact": "Medio",
        "critical": False,
        "activation": "systemd",
        "managed_by": "systemd --user",
    },
    {
        "key": "portal",
        "unit": "astrea-filechooser-portal.service",
        "label": "FileChooser Portal",
        "group": "Integration",
        "description": "Integra o Explorer ao portal de arquivos do sistema.",
        "impact": "Medio",
        "critical": False,
        "activation": "dbus",
        "managed_by": "D-Bus activation",
    },
    {
        "key": "night_shift",
        "unit": "astrea-night-shift.timer",
        "label": "Night Shift Schedule",
        "group": "Display",
        "description": "Reaplica temperatura de cor nos horarios salvos.",
        "impact": "Baixo",
        "critical": False,
        "activation": "systemd",
        "managed_by": "systemd --user",
    },
    {
        "key": "polkit",
        "unit": "astrea-polkit-agent.service",
        "label": "Authentication Agent",
        "group": "Integration",
        "description": "Janela de autenticacao para acoes administrativas.",
        "impact": "Alto",
        "critical": True,
        "activation": "shell",
        "managed_by": "Astrea Shell",
    },
    {
        "key": "screentime",
        "unit": "astrea-screentimed.service",
        "label": "ScreenTime Monitor",
        "group": "Apps",
        "description": "Rastreia o app em foco para estatisticas de uso.",
        "impact": "Baixo",
        "critical": False,
        "activation": "systemd",
        "managed_by": "systemd --user",
    },
]

SERVICE_BY_KEY = {item["key"]: item for item in SERVICE_CATALOG}
ENABLED_STATES = {"enabled", "enabled-runtime", "linked", "linked-runtime", "static"}
NON_TOGGLEABLE_STATES = {"static", "generated", "transient"}


def run_command(command: list[str], timeout: float = 5.0) -> tuple[int, str, str]:
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            check=False,
            text=True,
            timeout=timeout,
        )
        return result.returncode, result.stdout or "", result.stderr or ""
    except (OSError, subprocess.SubprocessError) as exc:
        return 127, "", str(exc)


def first_line(value: str) -> str:
    return next((line.strip() for line in (value or "").splitlines() if line.strip()), "")


def user_unit_dir() -> Path:
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")).expanduser()
    return config_home / "systemd/user"


def xdg_data_home() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")).expanduser()


def astrea_root() -> Path:
    return Path(os.environ.get("ASTREA_ROOT", Path.home() / ".local/share/Astrea")).expanduser()


def unit_is_enabled_on_disk(unit: str, unit_dir: Path) -> bool:
    try:
        return any(path.name == unit for path in unit_dir.glob("*.wants/*"))
    except OSError:
        return False


def unit_file_status_from_disk(unit: str) -> dict[str, Any]:
    unit_dir = user_unit_dir()
    unit_path = unit_dir / unit
    enabled = unit_is_enabled_on_disk(unit, unit_dir)
    if not unit_path.exists() and not enabled:
        return {
            "available": False,
            "state": "not-found",
            "detail": "",
        }
    return {
        "available": True,
        "state": "enabled" if enabled else "disabled",
        "detail": str(unit_path),
    }


def unit_file_status(unit: str, runner: Runner = run_command) -> dict[str, Any]:
    code, stdout, stderr = runner(
        ["systemctl", "--user", "list-unit-files", "--no-legend", "--no-pager", unit],
        3.0,
    )
    text = (stdout or stderr or "").strip()
    if code != 0 or not text or "0 unit files listed" in text:
        disk_status = unit_file_status_from_disk(unit)
        if disk_status["available"]:
            if text:
                disk_status["detail"] = text
            return disk_status
        return {
            "available": False,
            "state": "not-found",
            "detail": text,
        }

    for line in text.splitlines():
        parts = line.split()
        if parts and parts[0] == unit:
            return {
                "available": True,
                "state": parts[1] if len(parts) > 1 else "unknown",
                "detail": line.strip(),
            }
    return {
        "available": False,
        "state": "not-found",
        "detail": text,
    }


def systemctl_state(action: str, unit: str, runner: Runner = run_command) -> str:
    code, stdout, stderr = runner(["systemctl", "--user", action, unit], 3.0)
    value = first_line(stdout)
    if value:
        return value
    if code != 0:
        return "unknown"
    value = first_line(stderr)
    if value:
        return value
    return "unknown" if code == 0 else "unavailable"


def process_running(needle: str) -> bool:
    try:
        result = subprocess.run(
            ["ps", "-eo", "args="],
            capture_output=True,
            check=False,
            text=True,
            timeout=2,
        )
    except (OSError, subprocess.SubprocessError):
        return False
    return any(needle in line and "services.py" not in line for line in result.stdout.splitlines())


def dbus_portal_status(entry: dict[str, Any]) -> dict[str, Any]:
    data_home = xdg_data_home()
    dbus_file = data_home / "dbus-1/services/org.freedesktop.impl.portal.desktop.astrea.service"
    portal_file = data_home / "xdg-desktop-portal/portals/astrea.portal"
    available = dbus_file.exists() and portal_file.exists()
    active = process_running("astrea-filechooser-portal") or process_running("astrea_filechooser_portal.py")
    state = "active" if active else "on-demand"
    return {
        "key": entry["key"],
        "unit": entry["unit"],
        "label": entry["label"],
        "group": entry["group"],
        "description": entry["description"],
        "impact": entry["impact"],
        "critical": bool(entry.get("critical")),
        "activation": entry["activation"],
        "managed_by": entry["managed_by"],
        "available": available,
        "toggleable": False,
        "enabled": available,
        "active": active,
        "state": state if available else "not-found",
        "enabled_state": "on-demand" if available else "not-found",
        "detail": str(dbus_file) if available else "",
    }


def shell_polkit_status(entry: dict[str, Any]) -> dict[str, Any]:
    shell_path = astrea_root() / "Quickshell/shell.qml"
    available = shell_path.exists()
    active = process_running("Quickshell") or process_running("shell.qml")
    return {
        "key": entry["key"],
        "unit": entry["unit"],
        "label": entry["label"],
        "group": entry["group"],
        "description": entry["description"],
        "impact": entry["impact"],
        "critical": bool(entry.get("critical")),
        "activation": entry["activation"],
        "managed_by": entry["managed_by"],
        "available": available,
        "toggleable": False,
        "enabled": available,
        "active": active,
        "state": "embedded" if available else "not-found",
        "enabled_state": "shell" if available else "not-found",
        "detail": str(shell_path) if available else "",
    }


def service_payload(entry: dict[str, Any], runner: Runner = run_command) -> dict[str, Any]:
    if entry.get("activation") == "dbus":
        return dbus_portal_status(entry)
    if entry.get("activation") == "shell":
        return shell_polkit_status(entry)

    unit = entry["unit"]
    file_status = unit_file_status(unit, runner)
    available = bool(file_status["available"])
    enabled_state = file_status["state"]
    active_state = "not-found"

    if available:
        active_state = systemctl_state("is-active", unit, runner)
        checked_enabled_state = systemctl_state("is-enabled", unit, runner)
        if checked_enabled_state not in {"unknown", "unavailable"}:
            enabled_state = checked_enabled_state

    enabled = enabled_state in ENABLED_STATES
    active = active_state == "active"
    toggleable = available and enabled_state not in NON_TOGGLEABLE_STATES

    return {
        "key": entry["key"],
        "unit": unit,
        "label": entry["label"],
        "group": entry["group"],
        "description": entry["description"],
        "impact": entry["impact"],
        "critical": bool(entry.get("critical")),
        "activation": entry.get("activation", "systemd"),
        "managed_by": entry.get("managed_by", "systemd --user"),
        "available": available,
        "toggleable": toggleable,
        "enabled": enabled,
        "active": active,
        "state": active_state,
        "enabled_state": enabled_state,
        "detail": file_status.get("detail", ""),
    }


def list_services(runner: Runner = run_command) -> dict[str, Any]:
    return {
        "services": [service_payload(entry, runner) for entry in SERVICE_CATALOG],
    }


def parse_bool(value: str) -> bool:
    normalized = str(value or "").strip().lower()
    if normalized in {"1", "true", "yes", "on", "enable", "enabled", "sim"}:
        return True
    if normalized in {"0", "false", "no", "off", "disable", "disabled", "nao", "não"}:
        return False
    raise ValueError(f"invalid enabled value: {value}")


def set_service_enabled(key: str, enabled: bool, runner: Runner = run_command) -> dict[str, Any]:
    entry = SERVICE_BY_KEY.get(key)
    if not entry:
        raise ValueError(f"unknown Astrea service: {key}")

    unit = entry["unit"]
    action = "enable" if enabled else "disable"
    code, stdout, stderr = runner(["systemctl", "--user", action, "--now", unit], 15.0)
    ok = code == 0
    payload = list_services(runner)
    payload.update({
        "ok": ok,
        "action": action,
        "key": key,
        "unit": unit,
        "detail": (stderr or stdout or "").strip(),
    })
    return payload


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Astrea user service controls")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("list", help="list Astrea user services")

    set_parser = sub.add_parser("set", help="enable or disable an Astrea user service")
    set_parser.add_argument("key")
    set_parser.add_argument("enabled")

    enable_parser = sub.add_parser("enable", help="enable and start an Astrea user service")
    enable_parser.add_argument("key")

    disable_parser = sub.add_parser("disable", help="disable and stop an Astrea user service")
    disable_parser.add_argument("key")

    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.command == "list":
            emit(list_services())
        elif args.command == "set":
            emit(set_service_enabled(args.key, parse_bool(args.enabled)))
        elif args.command == "enable":
            emit(set_service_enabled(args.key, True))
        elif args.command == "disable":
            emit(set_service_enabled(args.key, False))
    except ValueError as exc:
        emit({"ok": False, "error": str(exc), "services": list_services()["services"]})
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
