#!/usr/bin/env python3
import sys
import json
import subprocess
import re
import traceback


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
    pattern = r"^(\d{1,3}\.){3}\d{1,3}$"
    if not re.match(pattern, ip):
        return False
    return all(0 <= int(p) <= 255 for p in ip.split("."))


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


# ─── entry point ─────────────────────────────────────────────────────────────

COMMANDS = {
    "stats":    (cmd_stats,    0),
    "dns_info": (cmd_dns_info, 0),
    "set_dns":  (cmd_set_dns,  2),
}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        _err("Missing command. Available: " + ", ".join(COMMANDS))
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd not in COMMANDS:
        _err(f"Unknown command '{cmd}'. Available: " + ", ".join(COMMANDS))
        sys.exit(1)

    fn, n_args = COMMANDS[cmd]
    if len(sys.argv) - 2 < n_args:
        _err(f"'{cmd}' requires {n_args} argument(s), got {len(sys.argv) - 2}")
        sys.exit(1)

    fn(*sys.argv[2:2 + n_args])
