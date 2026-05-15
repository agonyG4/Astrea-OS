#!/usr/bin/env python3
import json
import os
import signal
import shutil
import subprocess
import time
from pathlib import Path

HOME = Path.home()
ASTREA_ROOT = Path(
    os.environ.get("ASTREA_ROOT", HOME / ".local/share/Astrea")
).expanduser()
STATE_DIR = (
    Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")).expanduser()
    / "Astrea/status"
)
BLUETOOTH_HELPER = ASTREA_ROOT / "System/scripts/bluetooth_manager.py"

AUDIO_PATH = STATE_DIR / "audio.json"
NETWORK_PATH = STATE_DIR / "network.json"
BLUETOOTH_PATH = STATE_DIR / "bluetooth.json"
HEALTH_PATH = STATE_DIR / "health.json"

REFRESH_AUDIO_SEC = 10
REFRESH_NETWORK_SEC = 30
REFRESH_BLUETOOTH_SEC = 45
AUTOCONNECT_SEC = 120
MAX_SLEEP_SEC = 5.0

refresh_requested = False
running = True


def dependency_payload(name: str, *, kind: str = "dependency_missing") -> dict:
    return {
        "ok": False,
        "degraded": True,
        "error": kind,
        "message": f"Missing dependency: {name}",
    }


def command_available(name: str) -> bool:
    return shutil.which(name) is not None


def run_cmd(args, timeout=6):
    if not args or not command_available(str(args[0])):
        name = str(args[0]) if args else ""
        return subprocess.CompletedProcess(args, 127, "", f"Missing dependency: {name}")
    try:
        return subprocess.run(
            args, text=True, capture_output=True, timeout=timeout, check=False
        )
    except Exception as exc:
        return subprocess.CompletedProcess(args, 1, "", str(exc))


def write_json_if_changed(path, payload):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    data = (
        json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        + "\n"
    )
    try:
        if path.exists() and path.read_text(encoding="utf-8") == data:
            return
    except OSError:
        pass
    tmp = path.with_name(f".{path.name}.tmp")
    tmp.write_text(data, encoding="utf-8")
    tmp.replace(path)


def audio_status():
    if not command_available("wpctl"):
        payload = dependency_payload("wpctl")
        payload.update({"level": 0, "muted": False})
        return payload
    proc = run_cmd(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], timeout=3)
    muted = "[MUTED]" in proc.stdout
    level = 0
    for token in proc.stdout.replace("[MUTED]", "").split():
        try:
            level = round(float(token) * 100)
            break
        except ValueError:
            pass
    payload = {
        "ok": proc.returncode == 0,
        "level": max(0, min(150, level)),
        "muted": muted,
    }
    if proc.returncode != 0:
        payload.update(
            {"degraded": True, "error": proc.stderr.strip() or "wpctl_failed"}
        )
    return payload


def network_status():
    if not command_available("ip"):
        payload = dependency_payload("ip")
        payload.update(
            {
                "connected": False,
                "type": "none",
                "ssid": "",
                "download": "0 B/s",
                "upload": "0 B/s",
            }
        )
        return payload
    route = run_cmd(["ip", "route", "get", "1.1.1.1"], timeout=3).stdout.split()
    iface = ""
    for index, token in enumerate(route):
        if token == "dev" and index + 1 < len(route):
            iface = route[index + 1]
            break
    if not iface:
        return {
            "connected": False,
            "type": "none",
            "ssid": "",
            "download": "0 B/s",
            "upload": "0 B/s",
        }

    if (Path("/sys/class/net") / iface / "wireless").exists():
        net_type = "wifi"
        ssid = ""
        if command_available("nmcli"):
            wifi = run_cmd(
                ["nmcli", "-t", "-f", "active,ssid", "dev", "wifi"], timeout=4
            ).stdout
            for line in wifi.splitlines():
                if line.startswith("yes:"):
                    ssid = line.split(":", 1)[1]
                    break
    else:
        net_type = "wired"
        ssid = "Ethernet"

    return {
        "connected": True,
        "type": net_type,
        "ssid": ssid,
        "download": "--",
        "upload": "--",
    }


def bluetooth_status():
    if not command_available("python3"):
        payload = dependency_payload("python3")
        payload.update({"powered": False, "connected_name": "", "paired_devices": []})
        return payload
    if not BLUETOOTH_HELPER.exists():
        payload = dependency_payload(str(BLUETOOTH_HELPER), kind="helper_missing")
        payload.update({"powered": False, "connected_name": "", "paired_devices": []})
        return payload
    proc = run_cmd(["python3", str(BLUETOOTH_HELPER), "status"], timeout=8)
    try:
        payload = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError:
        payload = {}
    payload.setdefault("powered", False)
    payload.setdefault("connected_name", "")
    payload.setdefault("paired_devices", [])
    payload["ok"] = proc.returncode == 0
    return payload


def bluetooth_autoconnect():
    if command_available("python3") and BLUETOOTH_HELPER.exists():
        run_cmd(["python3", str(BLUETOOTH_HELPER), "autoconnect"], timeout=20)


def health_payload() -> dict:
    deps = {
        "wpctl": command_available("wpctl"),
        "ip": command_available("ip"),
        "nmcli": command_available("nmcli"),
        "python3": command_available("python3"),
        "bluetooth_helper": BLUETOOTH_HELPER.exists(),
    }
    return {
        "ok": all(deps.values()),
        "degraded": not all(deps.values()),
        "dependencies": deps,
        "updated_at": int(time.time()),
    }


def handle_refresh(_signum, _frame):
    global refresh_requested
    refresh_requested = True


def handle_stop(_signum, _frame):
    global running
    running = False


def main():
    global refresh_requested
    signal.signal(signal.SIGUSR1, handle_refresh)
    signal.signal(signal.SIGTERM, handle_stop)
    signal.signal(signal.SIGINT, handle_stop)

    next_audio = next_network = next_bluetooth = next_autoconnect = 0.0

    while running:
        now = time.monotonic()

        if refresh_requested:
            next_audio = next_network = next_bluetooth = 0.0
            refresh_requested = False

        if now >= next_audio:
            write_json_if_changed(HEALTH_PATH, health_payload())
            write_json_if_changed(AUDIO_PATH, audio_status())
            next_audio = now + REFRESH_AUDIO_SEC

        if now >= next_network:
            write_json_if_changed(NETWORK_PATH, network_status())
            next_network = now + REFRESH_NETWORK_SEC

        if now >= next_bluetooth:
            write_json_if_changed(BLUETOOTH_PATH, bluetooth_status())
            next_bluetooth = now + REFRESH_BLUETOOTH_SEC

        if now >= next_autoconnect:
            bluetooth_autoconnect()
            next_autoconnect = now + AUTOCONNECT_SEC
            next_bluetooth = 0.0

        next_due = min(next_audio, next_network, next_bluetooth, next_autoconnect)
        sleep_for = max(0.2, min(MAX_SLEEP_SEC, next_due - time.monotonic()))
        time.sleep(sleep_for)


if __name__ == "__main__":
    main()
