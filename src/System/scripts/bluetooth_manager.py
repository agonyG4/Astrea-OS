#!/usr/bin/env python3
"""
Astrea Bluetooth Autoconnect Helper
Manages paired device autoconnection via bluetoothctl.
Outputs JSON on stdout; exits non-zero only on internal errors.
"""

import json
import os
import re
import select
import subprocess
import sys
import time
import traceback
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
atomic_write_json = ASTREA_SHARED.atomic_write_json
read_json = ASTREA_SHARED.read_json

# ─── Paths ────────────────────────────────────────────────────────────────────

STATE_DIR = (
    Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")).expanduser()
    / "Astrea"
    / "bluetooth"
)
CONFIG_PATH = STATE_DIR / "autoconnect.json"
RUNTIME_PATH = STATE_DIR / "runtime.json"
STATUS_CACHE_PATH = STATE_DIR / "status-cache.json"
SHARED_STATUS_PATH = (
    Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")).expanduser()
    / "Astrea"
    / "status"
    / "bluetooth.json"
)

# ─── Constants ────────────────────────────────────────────────────────────────

MAC_RE = re.compile(r"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$")

MAX_DEVICE_ORDER = 64
CONNECT_TIMEOUT = 15
DISCONNECT_TIMEOUT = 12
INFO_TIMEOUT = 6
LIST_TIMEOUT = 6
SHOW_TIMEOUT = 4
STATUS_CACHE_TTL = 1.2
POWER_VERIFY_RETRIES = 6
POWER_VERIFY_SLEEP = 0.35

CONNECT_VERIFY_RETRIES = 3
CONNECT_VERIFY_SLEEP = 0.8
AUTOCONNECT_FAILURE_COOLDOWN_SEC = 600

DEFAULT_CONFIG: dict = {
    "enabled": True,
    "trusted_only": True,
    "retry_interval_sec": 12,
    "disconnect_snooze_sec": 300,
    "device_order": [],
    "device_overrides": {},
}

DEFAULT_RUNTIME: dict = {
    "last_attempt_ts": 0,
    "last_success_ts": 0,
    "last_success_mac": "",
    "device_cooldowns": {},
}

# ─── Output helpers ───────────────────────────────────────────────────────────


def _out(data: dict) -> None:
    print(json.dumps(data), flush=True)


def _err(message: str, *, trace: bool = False, exit_code: int = 1) -> None:
    payload: dict = {"success": False, "error": message}
    if trace:
        payload["trace"] = traceback.format_exc()
    _out(payload)
    sys.exit(exit_code)


# ─── Filesystem helpers ───────────────────────────────────────────────────────


def _ensure_state_dir() -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)


def _read_json(path: Path, default: dict) -> dict:
    data = read_json(path, dict(default))
    return data if isinstance(data, dict) else dict(default)


def _write_json(path: Path, data: dict) -> None:
    _ensure_state_dir()
    atomic_write_json(path, data, indent=2, sort_keys=True)


def _unlink(path: Path) -> None:
    try:
        path.unlink()
    except FileNotFoundError:
        pass


def invalidate_status_cache() -> None:
    _unlink(STATUS_CACHE_PATH)


def publish_status_snapshot(payload: dict) -> None:
    snapshot = dict(payload)
    snapshot.pop("_cached_at", None)
    snapshot.setdefault("powered", False)
    snapshot.setdefault("connected_name", "")
    snapshot.setdefault("paired_devices", [])
    snapshot["ok"] = bool(snapshot.get("success", True))
    atomic_write_json(SHARED_STATUS_PATH, snapshot, indent=None, sort_keys=True)


# ─── Process helper ───────────────────────────────────────────────────────────


def _run(*args: str, timeout: int = 8) -> subprocess.CompletedProcess:
    return subprocess.run(
        list(args),
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )


# ─── MAC validation ───────────────────────────────────────────────────────────


def _normalize_mac(value: str) -> str:
    mac = (value or "").strip().upper()
    if not MAC_RE.match(mac):
        raise ValueError(f"invalid MAC address: {value!r}")
    return mac


# ─── Config sanitization ──────────────────────────────────────────────────────


def _coerce_bool(value: object, default: bool) -> bool:
    """Strict bool coercion — only actual booleans or None are accepted."""
    if isinstance(value, bool):
        return value
    return default


def _sanitize_config(raw: object) -> dict:
    cfg = dict(DEFAULT_CONFIG)
    if not isinstance(raw, dict):
        return cfg

    cfg["enabled"] = _coerce_bool(raw.get("enabled"), True)
    cfg["trusted_only"] = _coerce_bool(raw.get("trusted_only"), True)

    for key, lo, hi in (
        ("retry_interval_sec", 5, 300),
        ("disconnect_snooze_sec", 30, 3600),
    ):
        try:
            cfg[key] = max(lo, min(hi, int(raw[key])))
        except (KeyError, TypeError, ValueError):
            pass  # keep default

    order: list[str] = []
    for item in (raw.get("device_order") or [])[: MAX_DEVICE_ORDER * 2]:
        try:
            mac = _normalize_mac(str(item))
        except ValueError:
            continue
        if mac not in order:
            order.append(mac)
        if len(order) >= MAX_DEVICE_ORDER:
            break
    cfg["device_order"] = order

    overrides: dict = {}
    raw_overrides = raw.get("device_overrides")
    if isinstance(raw_overrides, dict):
        for mac_raw, value in raw_overrides.items():
            try:
                n_mac = _normalize_mac(str(mac_raw))
            except ValueError:
                continue
            if isinstance(value, dict):
                auto = _coerce_bool(value.get("auto_connect"), True)
            else:
                auto = _coerce_bool(value, True)
            overrides[n_mac] = {"auto_connect": auto}
    cfg["device_overrides"] = overrides
    return cfg


def _sanitize_runtime(raw: object) -> dict:
    runtime = dict(DEFAULT_RUNTIME)
    if not isinstance(raw, dict):
        return runtime

    for key in ("last_attempt_ts", "last_success_ts"):
        try:
            runtime[key] = max(0, int(raw[key]))
        except (KeyError, TypeError, ValueError):
            pass

    try:
        mac = _normalize_mac(str(raw.get("last_success_mac", "")))
        runtime["last_success_mac"] = mac
    except ValueError:
        pass

    cooldowns: dict = {}
    now = int(time.time())
    raw_cd = raw.get("device_cooldowns")
    if isinstance(raw_cd, dict):
        for mac_raw, ts in raw_cd.items():
            try:
                n_mac = _normalize_mac(str(mac_raw))
                expires = int(ts)
            except (ValueError, TypeError):
                continue
            if expires > now:
                cooldowns[n_mac] = expires
    runtime["device_cooldowns"] = cooldowns
    return runtime


# ─── Config / runtime I/O ─────────────────────────────────────────────────────


def load_config() -> dict:
    cfg = _sanitize_config(_read_json(CONFIG_PATH, DEFAULT_CONFIG))
    if not CONFIG_PATH.exists():
        _write_json(CONFIG_PATH, cfg)
    return cfg


def save_config(cfg: dict) -> None:
    _write_json(CONFIG_PATH, _sanitize_config(cfg))
    invalidate_status_cache()


def load_runtime() -> dict:
    return _sanitize_runtime(_read_json(RUNTIME_PATH, DEFAULT_RUNTIME))


def save_runtime(runtime: dict) -> None:
    _write_json(RUNTIME_PATH, _sanitize_runtime(runtime))
    invalidate_status_cache()


# ─── bluetoothctl wrappers ────────────────────────────────────────────────────


def bluetooth_powered() -> bool:
    return "Powered: yes" in _run("bluetoothctl", "show", timeout=SHOW_TIMEOUT).stdout


def _read_power_after_change(wanted_on: bool) -> bool:
    current = bluetooth_powered()
    for attempt in range(POWER_VERIFY_RETRIES):
        current = bluetooth_powered()
        if current == wanted_on:
            return current
        if attempt < POWER_VERIFY_RETRIES - 1:
            time.sleep(POWER_VERIFY_SLEEP)
    return current


def adapter_status() -> dict:
    show_proc = _run("bluetoothctl", "show", timeout=SHOW_TIMEOUT)
    adapter_name = ""
    powered = False
    for raw in show_proc.stdout.splitlines():
        line = raw.strip()
        if line.startswith("Name: "):
            adapter_name = line[6:].strip()
        elif line == "Powered: yes":
            powered = True
    return {"powered": powered, "adapter_name": adapter_name}


def _parse_devices(stdout: str) -> list[dict]:
    devices: list[dict] = []
    for raw in stdout.splitlines():
        line = raw.strip()
        if not line.startswith("Device "):
            continue
        parts = line.split(" ", 2)
        if len(parts) < 3:
            continue
        try:
            mac = _normalize_mac(parts[1])
        except ValueError:
            continue
        devices.append({"mac": mac, "name": parts[2].strip() or mac})
    return devices


def paired_devices() -> list[dict]:
    return _parse_devices(
        _run("bluetoothctl", "devices", "Paired", timeout=LIST_TIMEOUT).stdout
    )


def connected_devices() -> list[dict]:
    return _parse_devices(
        _run("bluetoothctl", "devices", "Connected", timeout=LIST_TIMEOUT).stdout
    )


def device_info(mac: str) -> dict:
    proc = _run("bluetoothctl", "info", mac, timeout=INFO_TIMEOUT)
    info: dict = {
        "mac": mac,
        "name": mac,
        "connected": False,
        "trusted": False,
        "paired": False,
        "blocked": False,
    }
    for raw in proc.stdout.splitlines():
        line = raw.strip()
        if line.startswith("Name: "):
            info["name"] = line[6:].strip() or info["name"]
        elif line.startswith("Alias: ") and info["name"] == mac:
            info["name"] = line[7:].strip() or info["name"]
        elif line == "Connected: yes":
            info["connected"] = True
        elif line == "Trusted: yes":
            info["trusted"] = True
        elif line == "Paired: yes":
            info["paired"] = True
        elif line == "Blocked: yes":
            info["blocked"] = True
    return info


def _device_is_connected(mac: str) -> bool:
    """
    Queries bluetoothctl up to CONNECT_VERIFY_RETRIES times with a short sleep,
    because the stack may take a moment to reflect the new state.
    """
    for attempt in range(CONNECT_VERIFY_RETRIES):
        if device_info(mac).get("connected", False):
            return True
        if attempt < CONNECT_VERIFY_RETRIES - 1:
            time.sleep(CONNECT_VERIFY_SLEEP)
    return False


# ─── Priority helper ──────────────────────────────────────────────────────────


def _priority_index(mac: str, cfg: dict) -> int:
    try:
        return cfg["device_order"].index(mac)
    except ValueError:
        return 10_000


# ─── Status payload ───────────────────────────────────────────────────────────


def get_status_payload() -> dict:
    cached = _read_json(STATUS_CACHE_PATH, {})
    try:
        if (
            cached
            and time.time() - float(cached.get("_cached_at", 0)) < STATUS_CACHE_TTL
        ):
            cached.pop("_cached_at", None)
            return cached
    except (TypeError, ValueError):
        pass

    cfg = load_config()
    runtime = load_runtime()
    now = int(time.time())
    connected = connected_devices()
    connected_macs = {item["mac"] for item in connected}
    adapter = adapter_status()

    devices: list[dict] = []
    for item in paired_devices():
        info = device_info(item["mac"])
        info["connected"] = info["mac"] in connected_macs or info["connected"]
        override = cfg["device_overrides"].get(info["mac"], {})
        cooldown_until = runtime["device_cooldowns"].get(info["mac"], 0)
        devices.append(
            {
                "mac": info["mac"],
                "name": info["name"] or item["name"],
                "connected": info["connected"],
                "trusted": info["trusted"],
                "paired": info["paired"],
                "blocked": info["blocked"],
                "auto_connect": override.get("auto_connect", True),
                "cooldown_until": cooldown_until,
                "cooldown_active": cooldown_until > now,
                "priority": _priority_index(info["mac"], cfg),
            }
        )

    devices.sort(key=lambda d: (d["priority"], d["name"].lower(), d["mac"]))

    payload = {
        "success": True,
        "powered": adapter["powered"],
        "adapter_name": adapter["adapter_name"],
        "connected_count": len(connected),
        "connected_name": connected[0]["name"] if connected else "",
        "paired_devices": devices,
        "config": cfg,
        "runtime": runtime,
    }
    cached_payload = dict(payload)
    cached_payload["_cached_at"] = time.time()
    _write_json(STATUS_CACHE_PATH, cached_payload)
    return payload


# ─── Runtime mutation helpers ─────────────────────────────────────────────────


def _remember_success(mac: str) -> None:
    runtime = load_runtime()
    runtime["last_success_ts"] = int(time.time())
    runtime["last_success_mac"] = mac
    runtime["device_cooldowns"].pop(mac, None)
    save_runtime(runtime)


def _set_device_cooldown(mac: str, seconds: int) -> None:
    runtime = load_runtime()
    runtime["device_cooldowns"][mac] = int(time.time()) + max(0, seconds)
    save_runtime(runtime)


def _clear_device_cooldown(mac: str) -> None:
    runtime = load_runtime()
    runtime["device_cooldowns"].pop(mac, None)
    save_runtime(runtime)


# ─── Commands ─────────────────────────────────────────────────────────────────


def cmd_status() -> None:
    payload = get_status_payload()
    publish_status_snapshot(payload)
    _out(payload)


def cmd_save_config(raw_json: str) -> None:
    try:
        payload = json.loads(raw_json)
    except json.JSONDecodeError as exc:
        _err(f"invalid JSON: {exc}")
    save_config(payload)
    publish_status_snapshot(get_status_payload())
    _out({"success": True, "config": load_config()})


def cmd_connect(mac: str) -> None:
    target = _normalize_mac(mac)
    _clear_device_cooldown(target)
    proc = _run("bluetoothctl", "connect", target, timeout=CONNECT_TIMEOUT)
    connected = _device_is_connected(target)
    if connected:
        _remember_success(target)
    invalidate_status_cache()
    publish_status_snapshot(get_status_payload())
    _out(
        {
            "success": connected,
            "mac": target,
            "stdout": proc.stdout.strip(),
            "stderr": proc.stderr.strip(),
        }
    )


def cmd_disconnect(mac: str) -> None:
    target = _normalize_mac(mac)
    proc = _run("bluetoothctl", "disconnect", target, timeout=DISCONNECT_TIMEOUT)
    success = proc.returncode == 0
    if success:
        _set_device_cooldown(target, load_config()["disconnect_snooze_sec"])
    invalidate_status_cache()
    publish_status_snapshot(get_status_payload())
    _out(
        {
            "success": success,
            "mac": target,
            "stdout": proc.stdout.strip(),
            "stderr": proc.stderr.strip(),
        }
    )


def _autoconnect_candidates(status: dict, *, ignore_cooldowns: bool = False) -> list[dict]:
    cfg = status["config"]
    runtime = status["runtime"]
    now = int(time.time())
    candidates: list[dict] = []
    for dev in status["paired_devices"]:
        if dev["connected"] or dev["blocked"] or not dev["auto_connect"]:
            continue
        if cfg["trusted_only"] and not dev["trusted"]:
            continue
        if not ignore_cooldowns and runtime["device_cooldowns"].get(dev["mac"], 0) > now:
            continue
        candidates.append(dev)
    candidates.sort(key=lambda d: (d["priority"], d["name"].lower(), d["mac"]))
    return candidates


def run_autoconnect(force: bool = False) -> dict:
    status = get_status_payload()
    cfg = status["config"]
    runtime = status["runtime"]
    now = int(time.time())

    if not cfg["enabled"]:
        return {"success": False, "reason": "disabled"}
    if not status["powered"]:
        return {"success": False, "reason": "powered_off"}
    if status["connected_count"] > 0:
        return {"success": False, "reason": "already_connected"}

    elapsed = now - int(runtime.get("last_attempt_ts", 0))
    if not force and elapsed < cfg["retry_interval_sec"]:
        return {
            "success": False,
            "reason": "cooldown",
            "retry_in": cfg["retry_interval_sec"] - elapsed,
        }

    candidates = _autoconnect_candidates(status, ignore_cooldowns=force)
    if not candidates:
        return {"success": False, "reason": "no_candidates"}

    # stamp attempt before trying (avoids hammering on fast failures)
    runtime["last_attempt_ts"] = now
    save_runtime(runtime)

    attempts: list[dict] = []
    for dev in candidates:
        proc = _run("bluetoothctl", "connect", dev["mac"], timeout=CONNECT_TIMEOUT)
        connected = _device_is_connected(dev["mac"])
        attempts.append(
            {
                "mac": dev["mac"],
                "name": dev["name"],
                "success": connected,
                "stdout": proc.stdout.strip(),
                "stderr": proc.stderr.strip(),
            }
        )
        if connected:
            _remember_success(dev["mac"])
            return {
                "success": True,
                "reason": "connected",
                "device": dev,
                "attempts": attempts,
            }

    if not force:
        for attempt in attempts:
            _set_device_cooldown(attempt["mac"], AUTOCONNECT_FAILURE_COOLDOWN_SEC)

    return {"success": False, "reason": "connect_failed", "attempts": attempts}


def _cmd_autoconnect(force: bool) -> None:
    result = run_autoconnect(force)
    publish_status_snapshot(get_status_payload())
    _out(result)


def cmd_autoconnect() -> None:
    _cmd_autoconnect(False)


def cmd_force_autoconnect() -> None:
    _cmd_autoconnect(True)


def cmd_power(state: str) -> None:
    wanted = state.strip().lower()
    if wanted not in ("on", "off"):
        _err("power state must be 'on' or 'off'")
    proc = _run("bluetoothctl", "power", wanted, timeout=SHOW_TIMEOUT)
    powered = _read_power_after_change(wanted == "on")
    invalidate_status_cache()
    publish_status_snapshot(get_status_payload())
    _out(
        {
            "success": proc.returncode == 0 and powered == (wanted == "on"),
            "state": wanted,
            "powered": powered,
            "stdout": proc.stdout.strip(),
            "stderr": proc.stderr.strip(),
        }
    )


def _scan_event_from_line(line: str) -> dict | None:
    if "[NEW] Device" not in line:
        return None
    match = MAC_RE.search(line)
    if not match:
        return None
    mac = match.group(0).upper()
    name = line[match.end() :].strip().strip('"\\')
    if (
        not name
        or name == mac
        or re.match(r"^([0-9A-Fa-f]{2}-){5}[0-9A-Fa-f]{2}$", name)
    ):
        return None
    return {"event": "found", "mac": mac, "name": name}


def cmd_scan_stream() -> None:
    proc = subprocess.Popen(
        ["bluetoothctl"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1,
    )
    assert proc.stdin is not None
    assert proc.stdout is not None
    deadline = time.monotonic() + 15
    seen: set[str] = set()
    try:
        proc.stdin.write("scan on\n")
        proc.stdin.flush()
        while time.monotonic() < deadline and proc.poll() is None:
            readable, _, _ = select.select([proc.stdout], [], [], 0.25)
            if not readable:
                continue
            line = proc.stdout.readline()
            if not line:
                continue
            if "Discovery stopped" in line or "Discovering: no" in line:
                break
            event = _scan_event_from_line(line)
            if event and event["mac"] not in seen:
                seen.add(event["mac"])
                _out(event)
    finally:
        try:
            proc.stdin.write("scan off\n")
            proc.stdin.flush()
        except (BrokenPipeError, OSError):
            pass
        try:
            proc.terminate()
            proc.wait(timeout=1)
        except subprocess.TimeoutExpired:
            proc.kill()
        _out({"event": "done"})


# ─── Dispatch ─────────────────────────────────────────────────────────────────

COMMANDS: dict[str, tuple] = {
    "status": (cmd_status, 0),
    "save_config": (cmd_save_config, 1),
    "connect": (cmd_connect, 1),
    "disconnect": (cmd_disconnect, 1),
    "power": (cmd_power, 1),
    "autoconnect": (cmd_autoconnect, 0),
    "force_autoconnect": (cmd_force_autoconnect, 0),
    "scan-stream": (cmd_scan_stream, 0),
}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        _err("usage: bt_autoconnect.py <command> [args...]")

    command = sys.argv[1]
    if command not in COMMANDS:
        _err(f"unknown command {command!r}. available: {', '.join(COMMANDS)}")

    fn, required = COMMANDS[command]
    if len(sys.argv) - 2 < required:
        _err(f"'{command}' requires {required} argument(s), got {len(sys.argv) - 2}")

    try:
        fn(*sys.argv[2 : 2 + required])
    except ValueError as exc:
        _err(str(exc))
    except Exception as exc:
        _err(str(exc), trace=True)
