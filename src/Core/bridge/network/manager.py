#!/usr/bin/env python3
import sys
import json
import os
import shutil
import subprocess
import re
import traceback
import ipaddress

WARP_SERVICE = "warp-svc.service"
WARP_TRAY_SERVICE = "warp-taskbar.service"


# ─── helpers ────────────────────────────────────────────────────────────────

def _run(*args, timeout=5):
    """Run a subprocess and return stdout. Raises on failure."""
    return subprocess.check_output(args, timeout=timeout, stderr=subprocess.DEVNULL).decode()


def _out(data: dict):
    print(json.dumps(data))


def _err(msg: str, trace: bool = False):
    payload = {"error": msg}
    if trace:
        payload["trace"] = traceback.format_exc()
    _out(payload)


def _is_valid_ip(ip: str) -> bool:
    try:
        ipaddress.ip_address(ip)
        return True
    except ValueError:
        return False


def _validate_dns_servers(dns_str: str) -> tuple[bool, str]:
    """Returns (valid, error_message). Empty string or 'auto' always valid."""
    if dns_str.strip().lower() in ("", "auto"):
        return True, ""
    for ip in re.split(r"[,\s]+", dns_str.strip()):
        if ip and not _is_valid_ip(ip):
            return False, f"Invalid IP address: {ip}"
    return True, ""


def _parse_dns_lines(out: str) -> list[str]:
    """Parse nmcli -t output for IP4.DNS fields.
    Handles both 'IP4.DNS:' and 'IP4.DNS[1]:' formats."""
    dns = []
    for line in out.strip().splitlines():
        if line.upper().startswith("IP4.DNS"):
            val = line.split(":", 1)[1].strip()
            if val and val not in dns:
                dns.append(val)
    return dns


def _split_nmcli_fields(line: str) -> list[str]:
    """Split nmcli -t fields while preserving escaped ':' characters."""
    fields = []
    buf = []
    escaped = False
    for char in line:
        if escaped:
            buf.append(char)
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            fields.append("".join(buf))
            buf = []
        else:
            buf.append(char)
    if escaped:
        buf.append("\\")
    fields.append("".join(buf))
    return fields


def _wifi_enabled() -> bool:
    try:
        return _run("nmcli", "radio", "wifi", timeout=2).strip().lower() == "enabled"
    except Exception:
        return False


def get_wifi_device() -> dict | None:
    try:
        out = _run("nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device", "status", timeout=2)
    except Exception:
        return None

    for line in out.strip().splitlines():
        fields = _split_nmcli_fields(line)
        if len(fields) >= 3 and fields[1] == "wifi":
            return {"device": fields[0], "state": fields[2]}
    return None


def _parse_wifi_networks(out: str) -> list[dict]:
    by_ssid: dict[str, dict] = {}
    for line in out.strip().splitlines():
        fields = _split_nmcli_fields(line)
        if len(fields) < 4:
            continue
        active_raw, ssid, signal_raw, security = fields[:4]
        ssid = ssid.strip()
        if not ssid:
            continue
        try:
            signal = max(0, min(100, int(signal_raw or "0")))
        except ValueError:
            signal = 0
        item = {
            "ssid": ssid,
            "signal": signal,
            "security": security.strip(),
            "active": active_raw.lower() == "yes",
            "requires_password": bool(security.strip()),
        }
        existing = by_ssid.get(ssid)
        if existing is None or item["active"] or item["signal"] > existing["signal"]:
            by_ssid[ssid] = item
    networks = list(by_ssid.values())
    networks.sort(key=lambda item: (not item["active"], -item["signal"], item["ssid"].lower()))
    for index, item in enumerate(networks):
        item["index"] = index
    return networks


def _wifi_payload() -> dict:
    device = get_wifi_device()
    if not device:
        return {
            "success": True,
            "available": False,
            "enabled": False,
            "device": "",
            "state": "unavailable",
            "connected_ssid": "",
            "networks": [],
        }

    iface = device["device"]
    wifi_enabled = _wifi_enabled()
    if not wifi_enabled:
        return {
            "success": True,
            "available": True,
            "enabled": False,
            "device": iface,
            "state": device["state"],
            "connected_ssid": "",
            "networks": [],
        }

    networks = []
    try:
        out = _run(
            "nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY",
            "device", "wifi", "list", "ifname", iface, timeout=8
        )
        networks = _parse_wifi_networks(out)
    except Exception:
        pass

    active = next((item for item in networks if item.get("active")), None)
    return {
        "success": True,
        "available": True,
        "enabled": wifi_enabled,
        "device": iface,
        "state": device["state"],
        "connected_ssid": active["ssid"] if active else "",
        "networks": networks,
    }


# ─── Cloudflare WARP helpers ────────────────────────────────────────────────

def _command_exists(command: str) -> bool:
    return shutil.which(command) is not None


def _run_process(args: list[str], timeout: int = 5) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout,
    )


def _first_line(value: str) -> str:
    return next((line.strip() for line in value.splitlines() if line.strip()), "")


def _systemctl_state(*args: str, user: bool = False, timeout: int = 3) -> str:
    if not _command_exists("systemctl"):
        return "unavailable"

    cmd = ["systemctl"]
    if user:
        cmd.append("--user")
    cmd.extend(args)

    try:
        proc = _run_process(cmd, timeout=timeout)
    except Exception:
        return "unknown"

    value = _first_line(proc.stdout) or _first_line(proc.stderr)
    return value or "unknown"


def _systemctl_action(*args: str, timeout: int = 30) -> tuple[bool, str]:
    if not _command_exists("systemctl"):
        return False, "systemctl not found"

    cmd = ["systemctl", *args]
    try:
        proc = _run_process(cmd, timeout=timeout)
        if proc.returncode == 0:
            return True, ""
        error = _first_line(proc.stderr) or _first_line(proc.stdout)
    except Exception as exc:
        error = str(exc)

    if os.geteuid() == 0:
        return False, error

    for privileged_cmd in (["pkexec", *cmd], ["sudo", "-n", *cmd]):
        if not _command_exists(privileged_cmd[0]):
            continue
        try:
            proc = _run_process(privileged_cmd, timeout=timeout)
        except Exception as exc:
            error = str(exc)
            continue
        if proc.returncode == 0:
            return True, ""
        error = _first_line(proc.stderr) or _first_line(proc.stdout) or error

    return False, error


def _run_warp_cli(*args: str, json_output: bool = False, timeout: int = 8) -> subprocess.CompletedProcess[str]:
    cmd = ["warp-cli", "--accept-tos", "--no-ansi", "--no-paginate"]
    if json_output:
        cmd.append("--json")
    cmd.extend(args)
    return _run_process(cmd, timeout=timeout)


def _humanize_warp_reason(reason: str) -> str:
    if not reason:
        return ""
    spaced = re.sub(r"(?<!^)(?=[A-Z])", " ", reason).strip()
    return spaced[:1].upper() + spaced[1:] if spaced else reason


def _parse_warp_cli_status(raw: str) -> dict:
    text = (raw or "").strip()
    parsed = {
        "connected": False,
        "status": "Unknown",
        "reason": "",
        "network": "",
        "detail": "",
    }

    if not text:
        parsed["status"] = "Unavailable"
        return parsed

    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        data = None

    if isinstance(data, dict):
        if data.get("error"):
            parsed["status"] = "Unavailable"
            parsed["detail"] = str(data.get("error") or "")
            parsed["reason"] = str(data.get("code") or "")
            return parsed

        status = str(
            data.get("status")
            or data.get("state")
            or data.get("connection_status")
            or data.get("status_update")
            or ""
        ).strip()
        reason = str(data.get("reason") or "").strip()
        parsed["status"] = status or "Unknown"
        parsed["reason"] = reason
        parsed["network"] = "healthy" if reason == "NetworkHealthy" else _humanize_warp_reason(reason)
        parsed["connected"] = parsed["status"].lower() == "connected"
        return parsed

    for line in text.splitlines():
        line = line.strip()
        lower = line.lower()
        if lower.startswith("status update:"):
            parsed["status"] = line.split(":", 1)[1].strip() or "Unknown"
        elif lower.startswith("network:"):
            parsed["network"] = line.split(":", 1)[1].strip()
        elif not parsed["detail"]:
            parsed["detail"] = line

    parsed["connected"] = parsed["status"].lower() == "connected"
    return parsed


def _warp_payload() -> dict:
    if not _command_exists("warp-cli"):
        return {
            "success": True,
            "installed": False,
            "connected": False,
            "status": "Not installed",
            "reason": "",
            "network": "",
            "detail": "warp-cli was not found",
            "service_state": "unavailable",
            "service_enabled": "unknown",
            "service_active": False,
            "tray_state": "unknown",
        }

    service_state = _systemctl_state("is-active", WARP_SERVICE)
    service_enabled = _systemctl_state("is-enabled", WARP_SERVICE)
    tray_state = _systemctl_state("is-enabled", WARP_TRAY_SERVICE, user=True)

    try:
        proc = _run_warp_cli("status", json_output=True, timeout=8)
        status_text = proc.stdout if proc.stdout.strip() else proc.stderr
    except Exception as exc:
        status_text = json.dumps({"error": str(exc)})

    parsed = _parse_warp_cli_status(status_text)
    service_active = service_state == "active"

    return {
        "success": True,
        "installed": True,
        "connected": bool(parsed["connected"]),
        "status": parsed["status"],
        "reason": parsed["reason"],
        "network": parsed["network"],
        "detail": parsed["detail"],
        "service_state": service_state,
        "service_enabled": service_enabled,
        "service_active": service_active,
        "tray_state": tray_state,
    }


# ─── commands ───────────────────────────────────────────────────────────────

def get_default_iface() -> str | None:
    """Return the network interface used by the default route, or None."""
    try:
        out = _run("ip", "route", "show", "default", timeout=2)
        parts = out.split()
        if "dev" in parts:
            return parts[parts.index("dev") + 1]
    except Exception:
        pass
    return None


def cmd_stats():
    iface = get_default_iface()
    if not iface:
        _out({"rx": 0, "tx": 0, "iface": "unknown"})
        return

    try:
        with open("/proc/net/dev") as f:
            for line in f.readlines()[2:]:
                name, _, stats = line.partition(":")
                if name.strip() == iface:
                    vals = stats.split()
                    _out({"rx": int(vals[0]), "tx": int(vals[8]), "iface": iface})
                    return
    except Exception:
        pass

    _out({"rx": 0, "tx": 0, "iface": iface})


def cmd_dns_info():
    iface = get_default_iface()
    if not iface:
        _out({"connection": "", "iface": "", "dns": [], "auto": True})
        return

    # resolve active connection name for this interface
    conn_name = ""
    try:
        out = _run("nmcli", "-t", "-f", "NAME,DEVICE", "connection", "show", "--active", timeout=2)
        for line in out.strip().splitlines():
            parts = re.split(r"(?<!\\):", line)
            if len(parts) >= 2 and parts[-1] == iface:
                conn_name = ":".join(parts[:-1]).replace("\\:", ":")
                break
    except Exception:
        pass

    # check connection profile: is DNS static or automatic?
    profile_dns = []
    is_auto = True
    if conn_name:
        try:
            out = _run("nmcli", "-t", "-f", "IP4.DNS,ipv4.ignore-auto-dns",
                       "connection", "show", conn_name, timeout=2)
            profile_dns = _parse_dns_lines(out)
            for line in out.strip().splitlines():
                if "ignore-auto-dns" in line.lower() and "yes" in line.lower():
                    is_auto = False
                    break
        except Exception:
            pass

    # always grab active DNS from the device (reflects real/DHCP state)
    active_dns = []
    try:
        out = _run("nmcli", "-t", "-f", "IP4.DNS", "dev", "show", iface, timeout=2)
        active_dns = _parse_dns_lines(out)
    except Exception:
        pass

    # prefer active device DNS (real current state), fall back to profile
    dns = active_dns if active_dns else profile_dns

    _out({"connection": conn_name, "iface": iface, "dns": dns, "auto": is_auto})


def cmd_set_dns(conn_name: str, dns_servers: str):
    if not conn_name:
        _err("No connection name specified")
        return

    valid, err = _validate_dns_servers(dns_servers)
    if not valid:
        _err(err)
        return

    is_auto = dns_servers.strip().lower() in ("", "auto")

    try:
        if is_auto:
            _run("nmcli", "con", "mod", conn_name,
                 "ipv4.dns", "",
                 "ipv4.ignore-auto-dns", "no",
                 "ipv6.dns", "",
                 "ipv6.ignore-auto-dns", "no",
                 timeout=5)
        else:
            _run("nmcli", "con", "mod", conn_name,
                 "ipv4.dns", dns_servers,
                 "ipv4.ignore-auto-dns", "yes",
                 "ipv6.dns", "",
                 "ipv6.ignore-auto-dns", "no",
                 timeout=5)

        _run("nmcli", "con", "up", conn_name, timeout=10)
        _out({"success": True})

    except subprocess.CalledProcessError as e:
        _out({"success": False, "error": f"nmcli error (exit {e.returncode})"})
    except Exception as e:
        _out({"success": False, "error": str(e), "trace": traceback.format_exc()})


def cmd_wifi_status():
    _out(_wifi_payload())


def cmd_wifi_connect(ssid: str, password: str = ""):
    device = get_wifi_device()
    if not device:
        _out({"success": False, "error": "No Wi-Fi adapter detected"})
        return

    args = ["nmcli", "device", "wifi", "connect", ssid, "ifname", device["device"]]
    if password:
        args.extend(["password", password])
    try:
        _run(*args, timeout=20)
        _out(_wifi_payload())
    except subprocess.CalledProcessError as e:
        _out({"success": False, "error": f"nmcli error (exit {e.returncode})"})
    except Exception as e:
        _out({"success": False, "error": str(e), "trace": traceback.format_exc()})


def cmd_wifi_disconnect():
    device = get_wifi_device()
    if not device:
        _out({"success": False, "error": "No Wi-Fi adapter detected"})
        return

    try:
        _run("nmcli", "device", "disconnect", device["device"], timeout=10)
        _out(_wifi_payload())
    except subprocess.CalledProcessError as e:
        _out({"success": False, "error": f"nmcli error (exit {e.returncode})"})
    except Exception as e:
        _out({"success": False, "error": str(e), "trace": traceback.format_exc()})


def cmd_wifi_set_enabled(enabled: str):
    target = enabled.strip().lower()
    if target not in ("on", "off", "true", "false", "1", "0", "yes", "no"):
        _out({"success": False, "error": "Expected on or off"})
        return

    device = get_wifi_device()
    if not device:
        _out({"success": False, "error": "No Wi-Fi adapter detected"})
        return

    radio = "on" if target in ("on", "true", "1", "yes") else "off"
    try:
        _run("nmcli", "radio", "wifi", radio, timeout=10)
        _out(_wifi_payload())
    except subprocess.CalledProcessError as e:
        _out({"success": False, "error": f"nmcli error (exit {e.returncode})"})
    except Exception as e:
        _out({"success": False, "error": str(e), "trace": traceback.format_exc()})


def cmd_warp_status():
    _out(_warp_payload())


def cmd_warp_set_enabled(enabled: str):
    target = enabled.strip().lower()
    if target not in ("on", "off", "true", "false", "1", "0", "yes", "no"):
        payload = _warp_payload()
        payload["success"] = False
        payload["error"] = "Expected on or off"
        _out(payload)
        return

    turn_on = target in ("on", "true", "1", "yes")
    success = True
    error = ""

    if turn_on:
        ok, error = _systemctl_action("start", WARP_SERVICE, timeout=45)
        success = success and ok
        if ok:
            try:
                proc = _run_warp_cli("connect", timeout=15)
                if proc.returncode != 0:
                    success = False
                    error = _first_line(proc.stderr) or _first_line(proc.stdout) or error
            except Exception as exc:
                success = False
                error = str(exc)
    else:
        try:
            _run_warp_cli("disconnect", timeout=10)
        except Exception:
            pass
        ok, error = _systemctl_action("stop", WARP_SERVICE, timeout=45)
        success = success and ok

    payload = _warp_payload()
    payload["success"] = success
    if error:
        payload["error"] = error
    _out(payload)


def cmd_warp_restart():
    ok, error = _systemctl_action("restart", WARP_SERVICE, timeout=45)
    success = ok
    if ok:
        try:
            proc = _run_warp_cli("connect", timeout=15)
            if proc.returncode != 0:
                success = False
                error = _first_line(proc.stderr) or _first_line(proc.stdout) or error
        except Exception as exc:
            success = False
            error = str(exc)

    payload = _warp_payload()
    payload["success"] = success
    if error:
        payload["error"] = error
    _out(payload)


# ─── entry point ─────────────────────────────────────────────────────────────

COMMANDS = {
    "stats":    (cmd_stats,    0),
    "dns_info": (cmd_dns_info, 0),
    "set_dns":  (cmd_set_dns,  2),
    "wifi_status":     (cmd_wifi_status,     0),
    "wifi_connect":    (cmd_wifi_connect,    1, 2),
    "wifi_disconnect": (cmd_wifi_disconnect, 0),
    "wifi_set_enabled": (cmd_wifi_set_enabled, 1),
    "warp_status": (cmd_warp_status, 0),
    "warp_set_enabled": (cmd_warp_set_enabled, 1),
    "warp_restart": (cmd_warp_restart, 0),
}

def command_arg_bounds(cmd: str) -> tuple[int, int]:
    entry = COMMANDS[cmd]
    required = int(entry[1])
    maximum = int(entry[2]) if len(entry) > 2 else required
    return required, maximum


if __name__ == "__main__":
    if len(sys.argv) < 2:
        _err("Missing command. Available: " + ", ".join(COMMANDS))
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd not in COMMANDS:
        _err(f"Unknown command '{cmd}'. Available: " + ", ".join(COMMANDS))
        sys.exit(1)

    entry = COMMANDS[cmd]
    fn = entry[0]
    min_args, max_args = command_arg_bounds(cmd)
    got_args = len(sys.argv) - 2
    if got_args < min_args or got_args > max_args:
        if min_args == max_args:
            _err(f"'{cmd}' requires {min_args} argument(s), got {got_args}")
        else:
            _err(f"'{cmd}' requires {min_args}-{max_args} argument(s), got {got_args}")
        sys.exit(1)

    fn(*sys.argv[2:2 + max_args])
