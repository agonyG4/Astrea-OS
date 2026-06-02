#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from astrea_shared import atomic_write_json, read_json, xdg_config_home  # noqa: E402


COUNTRIES = [
    {"code": "BR", "name": "Brazil", "time_format": "24h"},
    {"code": "US", "name": "United States", "time_format": "12h"},
    {"code": "PT", "name": "Portugal", "time_format": "24h"},
    {"code": "GB", "name": "United Kingdom", "time_format": "24h"},
    {"code": "FR", "name": "France", "time_format": "24h"},
    {"code": "ES", "name": "Spain", "time_format": "24h"},
    {"code": "DE", "name": "Germany", "time_format": "24h"},
    {"code": "IT", "name": "Italy", "time_format": "24h"},
    {"code": "CA", "name": "Canada", "time_format": "12h"},
    {"code": "JP", "name": "Japan", "time_format": "24h"},
    {"code": "AR", "name": "Argentina", "time_format": "24h"},
    {"code": "CL", "name": "Chile", "time_format": "24h"},
    {"code": "UY", "name": "Uruguay", "time_format": "24h"},
]
COUNTRY_CODES = {item["code"] for item in COUNTRIES}
COUNTRY_TIME_FORMAT_DEFAULTS = {
    item["code"]: item.get("time_format", "24h")
    for item in COUNTRIES
}
TIME_FORMATS = {"system", "24h", "12h"}
DEFAULT_REGION = {
    "country_code": "BR",
    "time_format": "system",
    "automatic_location": True,
}
DEFAULT_CONFIG = {
    "language": "en_US",
    "region": DEFAULT_REGION,
}
GEOCLUE_SERVICE = "geoclue.service"
SETTINGS_PATH = Path(os.environ.get(
    "ASTREA_SYSTEM_SETTINGS_PATH",
    xdg_config_home() / "AstreaOS/system/settings.json",
)).expanduser()


Runner = Callable[[list[str], float], tuple[int, str, str]]


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


def parse_bool(value: str) -> bool:
    normalized = str(value or "").strip().lower()
    if normalized in {"1", "true", "yes", "on", "sim", "enabled"}:
        return True
    if normalized in {"0", "false", "no", "off", "nao", "não", "disabled"}:
        return False
    raise ValueError(f"invalid boolean value: {value}")


def normalize_country(value: Any) -> str:
    code = str(value or DEFAULT_REGION["country_code"]).strip().upper().replace("-", "_")
    return code if code in COUNTRY_CODES else DEFAULT_REGION["country_code"]


def normalize_time_format(value: Any) -> str:
    normalized = str(value or DEFAULT_REGION["time_format"]).strip().lower()
    return normalized if normalized in TIME_FORMATS else DEFAULT_REGION["time_format"]


def normalize_region(value: Any) -> dict[str, Any]:
    region = value if isinstance(value, dict) else {}
    return {
        "country_code": normalize_country(region.get("country_code")),
        "time_format": normalize_time_format(region.get("time_format")),
        "automatic_location": bool(region.get("automatic_location", True)),
    }


def effective_time_format(region: Any) -> str:
    normalized = normalize_region(region)
    selected = normalized["time_format"]
    if selected in {"12h", "24h"}:
        return selected
    return COUNTRY_TIME_FORMAT_DEFAULTS.get(normalized["country_code"], "24h")


def normalize_config(value: Any) -> dict[str, Any]:
    config = dict(value) if isinstance(value, dict) else {}
    config["language"] = str(config.get("language") or DEFAULT_CONFIG["language"]).replace("-", "_")
    config["region"] = normalize_region(config.get("region"))
    return config


def load_config(path: Path = SETTINGS_PATH) -> dict[str, Any]:
    return normalize_config(read_json(path, DEFAULT_CONFIG))


def service_status(runner: Runner = run_command) -> dict[str, Any]:
    code, stdout, stderr = runner(["systemctl", "list-unit-files", GEOCLUE_SERVICE, "--no-legend", "--no-pager"], 3.0)
    text = (stdout or stderr or "").strip()
    if code != 0 or not text or "0 unit files listed" in text:
        return {"available": False, "state": "not-found", "detail": text}
    parts = text.split()
    return {"available": True, "state": parts[1] if len(parts) > 1 else "unknown", "detail": text}


def needs_privilege(code: int, stderr: str) -> bool:
    text = (stderr or "").lower()
    return code != 0 and any(term in text for term in ("permission", "denied", "authentication", "polkit"))


def privileged_command(command: list[str]) -> list[str] | None:
    pkexec = shutil.which("pkexec")
    if not pkexec:
        return None
    return [pkexec, *command]


def run_service_action(action: str, runner: Runner = run_command) -> dict[str, Any]:
    status = service_status(runner)
    result = {
        "action": action,
        "available": status["available"],
        "ok": True,
        "detail": status.get("detail", ""),
        "state": status.get("state", "unknown"),
    }
    if not status["available"]:
        return result

    if action == "disable":
        command = ["systemctl", "mask", "--now", GEOCLUE_SERVICE]
    elif action == "enable":
        command = ["systemctl", "unmask", GEOCLUE_SERVICE]
    else:
        raise ValueError(f"unknown service action: {action}")

    code, stdout, stderr = runner(command, 8.0)
    if needs_privilege(code, stderr):
        elevated = privileged_command(command)
        if elevated:
            code, stdout, stderr = runner(elevated, 30.0)
    result["ok"] = code == 0
    result["detail"] = (stderr or stdout or result["detail"]).strip()
    return result


def save_config(
    next_config: dict[str, Any],
    *,
    path: Path = SETTINGS_PATH,
    runner: Runner = run_command,
) -> dict[str, Any]:
    previous = load_config(path)
    normalized = normalize_config(next_config)
    service_result = {"action": "none", "ok": True, "available": False, "detail": ""}

    was_enabled = previous["region"]["automatic_location"]
    is_enabled = normalized["region"]["automatic_location"]
    if was_enabled and not is_enabled:
        service_result = run_service_action("disable", runner)
    elif not was_enabled and is_enabled:
        service_result = run_service_action("enable", runner)

    atomic_write_json(path, normalized, indent=4)
    return {
        "config": normalized,
        "geolocation_service": service_result,
        "countries": COUNTRIES,
        "time_formats": sorted(TIME_FORMATS),
        "effective_time_format": effective_time_format(normalized["region"]),
    }


def apply_set_args(args: argparse.Namespace) -> dict[str, Any]:
    config = load_config(args.path)
    if args.language is not None:
        config["language"] = args.language
    region = dict(config.get("region") or {})
    if args.country_code is not None:
        region["country_code"] = args.country_code
    if args.time_format is not None:
        region["time_format"] = args.time_format
    if args.automatic_location is not None:
        region["automatic_location"] = parse_bool(args.automatic_location)
    config["region"] = region
    return save_config(config, path=args.path)


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Astrea region and location settings")
    parser.add_argument("--path", type=Path, default=SETTINGS_PATH)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("get", help="print normalized regional settings")

    set_parser = sub.add_parser("set", help="update regional settings")
    set_parser.add_argument("--language")
    set_parser.add_argument("--country-code")
    set_parser.add_argument("--time-format", choices=sorted(TIME_FORMATS))
    set_parser.add_argument("--automatic-location")

    service = sub.add_parser("service", help="control the system location service")
    service.add_argument("action", choices=["status", "enable", "disable"])

    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.command == "get":
        config = load_config(args.path)
        emit({
            "config": config,
            "geolocation_service": service_status(),
            "countries": COUNTRIES,
            "time_formats": sorted(TIME_FORMATS),
            "effective_time_format": effective_time_format(config["region"]),
        })
        return
    if args.command == "set":
        emit(apply_set_args(args))
        return
    if args.command == "service":
        if args.action == "status":
            emit(service_status())
        else:
            emit(run_service_action(args.action))


if __name__ == "__main__":
    main()
