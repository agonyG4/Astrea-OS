#!/usr/bin/env python3
import json
import os
import signal
import shutil
import subprocess
import importlib.util
import threading
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
REFRESH_NETWORK_SEC = 2
REFRESH_BLUETOOTH_SEC = 45
REFRESH_HEALTH_SEC = 300
AUTOCONNECT_SEC = 120
MAX_SLEEP_SEC = 5.0
COMMAND_CACHE_SEC = 300
PIPEWIRE_AUDIO_DEBOUNCE_SEC = 0.06
NETWORK_ROUTE_CACHE_SEC = 30
WIFI_SSID_CACHE_SEC = 30

refresh_requested = False
running = True
command_cache: dict[str, tuple[float, bool]] = {}
json_cache: dict[Path, str] = {}
bluetooth_module = None
network_sample: dict[str, tuple[float, int, int]] = {}
network_route_iface = ""
network_route_time = 0.0
wifi_ssid_cache: dict[str, tuple[float, str]] = {}
json_lock = threading.Lock()
audio_monitor_proc: subprocess.Popen | None = None
bluetooth_autoconnect_lock = threading.Lock()
bluetooth_autoconnect_thread: threading.Thread | None = None


def dependency_payload(name: str, *, kind: str = "dependency_missing") -> dict:
    return {
        "ok": False,
        "degraded": True,
        "error": kind,
        "message": f"Missing dependency: {name}",
    }


def command_available(name: str) -> bool:
    now = time.monotonic()
    cached = command_cache.get(name)
    if cached and now - cached[0] < COMMAND_CACHE_SEC:
        return cached[1]
    available = shutil.which(name) is not None
    command_cache[name] = (now, available)
    return available


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
    with json_lock:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        data = (
            json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
            + "\n"
        )
        if json_cache.get(path) == data and path.exists():
            return
        try:
            if path.exists() and path.read_text(encoding="utf-8") == data:
                json_cache[path] = data
                return
        except OSError:
            pass
        tmp = path.with_name(f".{path.name}.tmp")
        tmp.write_text(data, encoding="utf-8")
        tmp.replace(path)
        json_cache[path] = data


def load_bluetooth_module():
    global bluetooth_module
    if bluetooth_module is not None:
        return bluetooth_module
    if not BLUETOOTH_HELPER.exists():
        return None
    spec = importlib.util.spec_from_file_location("astrea_bluetooth_manager", BLUETOOTH_HELPER)
    if spec is None or spec.loader is None:
        return None
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except Exception:
        return None
    bluetooth_module = module
    return module


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


def write_audio_status():
    write_json_if_changed(AUDIO_PATH, audio_status())


def pipewire_audio_monitor():
    global audio_monitor_proc

    if not command_available("pw-mon"):
        return

    while running:
        try:
            proc = subprocess.Popen(
                ["pw-mon"],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
            )
            audio_monitor_proc = proc
        except Exception:
            time.sleep(5)
            continue

        started_at = time.monotonic()
        last_refresh = 0.0

        try:
            if proc.stdout is None:
                proc.wait(timeout=1)
                time.sleep(2)
                continue

            for line in proc.stdout:
                if not running:
                    break
                if time.monotonic() - started_at < 0.8:
                    continue
                if (
                    "Spa:Pod:Object:Param:Props:volume" not in line
                    and "Spa:Pod:Object:Param:Props:mute" not in line
                    and "Spa:Pod:Object:Param:Props:channelVolumes" not in line
                ):
                    continue

                now = time.monotonic()
                if now - last_refresh < PIPEWIRE_AUDIO_DEBOUNCE_SEC:
                    continue
                last_refresh = now
                write_audio_status()
        finally:
            if audio_monitor_proc is proc:
                audio_monitor_proc = None
            try:
                proc.terminate()
                proc.wait(timeout=1)
            except Exception:
                try:
                    proc.kill()
                except Exception:
                    pass

        if running:
            time.sleep(2)


def format_rate(bytes_per_second: float) -> str:
    value = max(0.0, float(bytes_per_second))
    units = ("B/s", "KB/s", "MB/s", "GB/s")
    unit_index = 0
    while value >= 1000.0 and unit_index < len(units) - 1:
        value /= 1000.0
        unit_index += 1
    if unit_index == 0:
        return f"{int(round(value))} {units[unit_index]}"
    return f"{value:.1f} {units[unit_index]}"


def interface_counters(iface: str) -> tuple[int, int] | None:
    stats_dir = Path("/sys/class/net") / iface / "statistics"
    try:
        rx = int((stats_dir / "rx_bytes").read_text(encoding="utf-8").strip())
        tx = int((stats_dir / "tx_bytes").read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        return None
    return rx, tx


def interface_rates(iface: str) -> tuple[str, str]:
    global network_sample

    counters = interface_counters(iface)
    if counters is None:
        return "0 B/s", "0 B/s"

    now = time.monotonic()
    rx, tx = counters
    previous = network_sample.get(iface)
    network_sample[iface] = (now, rx, tx)

    if previous is None:
        return "0 B/s", "0 B/s"

    previous_time, previous_rx, previous_tx = previous
    elapsed = max(0.001, now - previous_time)
    return (
        format_rate((rx - previous_rx) / elapsed),
        format_rate((tx - previous_tx) / elapsed),
    )


def default_route_iface_from_proc(text: str | None = None) -> str:
    try:
        content = text if text is not None else Path("/proc/net/route").read_text(encoding="utf-8")
    except OSError:
        return ""

    best_iface = ""
    best_metric: int | None = None
    for raw in content.splitlines()[1:]:
        fields = raw.split()
        if len(fields) < 7:
            continue
        iface, destination, _gateway, flags_raw, _refcnt, _use, metric_raw = fields[:7]
        if destination != "00000000":
            continue
        try:
            flags = int(flags_raw, 16)
            metric = int(metric_raw)
        except ValueError:
            continue
        if not (flags & 0x2):
            continue
        if best_metric is None or metric < best_metric:
            best_iface = iface
            best_metric = metric
    return best_iface


def active_network_iface() -> str:
    global network_route_iface, network_route_time

    now = time.monotonic()
    if now - network_route_time < NETWORK_ROUTE_CACHE_SEC:
        return network_route_iface

    iface = default_route_iface_from_proc()
    if iface:
        network_route_iface = iface
        network_route_time = now
        return iface

    route = run_cmd(["ip", "route", "get", "1.1.1.1"], timeout=3).stdout.split()
    iface = ""
    for index, token in enumerate(route):
        if token == "dev" and index + 1 < len(route):
            iface = route[index + 1]
            break

    network_route_iface = iface
    network_route_time = now
    return iface


def wifi_ssid_for_iface(iface: str) -> str:
    now = time.monotonic()
    cached = wifi_ssid_cache.get(iface)
    if cached and now - cached[0] < WIFI_SSID_CACHE_SEC:
        return cached[1]

    ssid = ""
    if command_available("nmcli"):
        wifi = run_cmd(
            ["nmcli", "-t", "-g", "GENERAL.CONNECTION", "device", "show", iface],
            timeout=3,
        ).stdout
        ssid = wifi.strip().splitlines()[0] if wifi.strip() else ""

    wifi_ssid_cache[iface] = (now, ssid)
    return ssid


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
    iface = active_network_iface()
    if not iface:
        return {
            "connected": False,
            "type": "none",
            "ssid": "",
            "download": "0 B/s",
            "upload": "0 B/s",
        }

    if not (Path("/sys/class/net") / iface).exists():
        return {
            "connected": False,
            "type": "none",
            "ssid": "",
            "download": "0 B/s",
            "upload": "0 B/s",
        }

    if (Path("/sys/class/net") / iface / "wireless").exists():
        net_type = "wifi"
        ssid = wifi_ssid_for_iface(iface)
    else:
        net_type = "wired"
        ssid = "Ethernet"

    download, upload = interface_rates(iface)

    return {
        "connected": True,
        "type": net_type,
        "ssid": ssid,
        "download": download,
        "upload": upload,
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
    module = load_bluetooth_module()
    if module is not None and hasattr(module, "get_status_payload"):
        try:
            payload = module.get_status_payload()
        except Exception as exc:
            payload = {"success": False, "error": str(exc)}
        payload.setdefault("powered", False)
        payload.setdefault("connected_name", "")
        payload.setdefault("paired_devices", [])
        payload["ok"] = bool(payload.get("success", True))
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
    if not BLUETOOTH_HELPER.exists():
        return
    module = load_bluetooth_module()
    if module is not None and hasattr(module, "run_autoconnect"):
        try:
            module.run_autoconnect(False)
            return
        except Exception:
            pass
    if command_available("python3"):
        run_cmd(["python3", str(BLUETOOTH_HELPER), "autoconnect"], timeout=20)


def request_bluetooth_autoconnect() -> bool:
    global bluetooth_autoconnect_thread

    with bluetooth_autoconnect_lock:
        if bluetooth_autoconnect_thread and bluetooth_autoconnect_thread.is_alive():
            return False

        def worker():
            global bluetooth_autoconnect_thread
            try:
                bluetooth_autoconnect()
            finally:
                with bluetooth_autoconnect_lock:
                    if bluetooth_autoconnect_thread is threading.current_thread():
                        bluetooth_autoconnect_thread = None

        bluetooth_autoconnect_thread = threading.Thread(target=worker, daemon=True)
        bluetooth_autoconnect_thread.start()
        return True


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
    proc = audio_monitor_proc
    if proc is not None:
        try:
            proc.terminate()
        except Exception:
            pass


def main():
    global refresh_requested, network_route_time
    signal.signal(signal.SIGUSR1, handle_refresh)
    signal.signal(signal.SIGTERM, handle_stop)
    signal.signal(signal.SIGINT, handle_stop)

    threading.Thread(target=pipewire_audio_monitor, daemon=True).start()

    next_audio = next_network = next_bluetooth = next_health = next_autoconnect = 0.0
    bluetooth_powered = False

    while running:
        now = time.monotonic()

        if refresh_requested:
            next_audio = next_network = next_bluetooth = next_health = 0.0
            network_route_time = 0.0
            refresh_requested = False

        if now >= next_audio:
            write_audio_status()
            next_audio = now + REFRESH_AUDIO_SEC

        if now >= next_health:
            write_json_if_changed(HEALTH_PATH, health_payload())
            next_health = now + REFRESH_HEALTH_SEC

        if now >= next_network:
            write_json_if_changed(NETWORK_PATH, network_status())
            next_network = now + REFRESH_NETWORK_SEC

        if now >= next_bluetooth:
            payload = bluetooth_status()
            bluetooth_powered = payload.get("powered") is True
            write_json_if_changed(BLUETOOTH_PATH, payload)
            next_bluetooth = now + REFRESH_BLUETOOTH_SEC

        if now >= next_autoconnect:
            if bluetooth_powered:
                if request_bluetooth_autoconnect():
                    next_bluetooth = min(next_bluetooth, now + 5.0)
            next_autoconnect = now + AUTOCONNECT_SEC

        next_due = min(next_audio, next_network, next_bluetooth, next_health, next_autoconnect)
        sleep_for = max(0.2, min(MAX_SLEEP_SEC, next_due - time.monotonic()))
        time.sleep(sleep_for)


if __name__ == "__main__":
    main()
