#!/usr/bin/env python3

import json
import os
import platform
import socket
import subprocess
from pathlib import Path


def read_text(path: str) -> str:
    try:
        return Path(path).read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def run_output(command: list[str]) -> str:
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return ""

    if result.returncode != 0:
        return ""

    return result.stdout.strip()


def human_bytes(size: int) -> str:
    units = ["B", "KB", "MB", "GB", "TB"]
    value = float(size)
    unit = units[0]
    for candidate in units:
        unit = candidate
        if value < 1024 or candidate == units[-1]:
            break
        value /= 1024
    if unit == "B":
        return f"{int(value)} {unit}"
    if value >= 100:
        return f"{value:.0f} {unit}"
    if value >= 10:
        return f"{value:.1f} {unit}"
    return f"{value:.2f} {unit}"


def distro_name() -> str:
    fields = {}
    try:
        for line in Path("/etc/os-release").read_text(encoding="utf-8").splitlines():
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            fields[key] = value.strip().strip('"')
    except OSError:
        return platform.system()

    return fields.get("PRETTY_NAME") or fields.get("NAME") or platform.system()


def cpu_name() -> str:
    cpuinfo = read_text("/proc/cpuinfo")
    for line in cpuinfo.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        if key.strip().lower() == "model name":
            return value.strip()

    lscpu = run_output(["lscpu"])
    for line in lscpu.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        if key.strip().lower() == "model name":
            return value.strip()

    return "Not detected"


def gpu_name() -> str:
    output = run_output(["lspci"])
    for line in output.splitlines():
        lowered = line.lower()
        if "vga compatible controller" in lowered or "3d controller" in lowered or "display controller" in lowered:
            if ": " in line:
                return line.split(": ", 1)[1].strip()
            return line.strip()

    return "Not detected"


def total_memory() -> tuple[int, str]:
    meminfo = read_text("/proc/meminfo")
    for line in meminfo.splitlines():
        if not line.startswith("MemTotal:"):
            continue
        parts = line.split()
        if len(parts) < 2:
            continue
        try:
            kib = int(parts[1])
        except ValueError:
            break
        total = kib * 1024
        return total, human_bytes(total)

    return 0, "Not detected"


def desktop_name() -> str:
    return (
        os.environ.get("XDG_CURRENT_DESKTOP")
        or os.environ.get("XDG_SESSION_DESKTOP")
        or "Unknown"
    )


def session_type() -> str:
    session = os.environ.get("XDG_SESSION_TYPE", "")
    if not session:
        return "Unknown"
    return session.capitalize()


def machine_name() -> str:
    vendor = read_text("/sys/class/dmi/id/sys_vendor")
    product = read_text("/sys/class/dmi/id/product_name")
    parts = [part for part in [vendor, product] if part and part.lower() != "default string"]
    if parts:
        return " ".join(parts)
    return platform.node() or "Unknown machine"


def collect() -> dict:
    memory_bytes, memory_label = total_memory()
    return {
        "system": {
            "distro": distro_name(),
            "kernel": platform.release(),
            "hostname": socket.gethostname(),
            "architecture": platform.machine() or "Unknown",
            "desktop": desktop_name(),
            "session_type": session_type(),
            "machine": machine_name(),
        },
        "hardware": {
            "cpu": cpu_name(),
            "gpu": gpu_name(),
            "memory_total": memory_label,
            "memory_total_bytes": memory_bytes,
        },
    }


def main() -> None:
    print(json.dumps(collect(), ensure_ascii=False))


if __name__ == "__main__":
    main()
