#!/usr/bin/env python3
"""Astrea temporary latency boost daemon.

Receives JSON lines on a Unix socket. Boosts are intentionally short-lived:
when the latest deadline expires, temporary changes are rolled back.
"""

from __future__ import annotations

import argparse
import json
import os
import selectors
import shutil
import signal
import socket
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

DEFAULT_DURATION_MS = 3000
MAX_BURST_MS = 3000
APP_NAME = "Astrea"
CPU_GOVERNOR_GLOB = "/sys/devices/system/cpu/cpufreq/policy*/scaling_governor"
INTEL_NO_TURBO = Path("/sys/devices/system/cpu/intel_pstate/no_turbo")
BURST_HELPER = Path("/usr/local/libexec/astrea-latency-burst-helper")


def xdg_state_home() -> Path:
    return Path(
        os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")
    ).expanduser()


def xdg_runtime_dir() -> Path:
    return Path(
        os.environ.get("XDG_RUNTIME_DIR", xdg_state_home() / APP_NAME / "runtime")
    ).expanduser()


def socket_path() -> Path:
    return xdg_runtime_dir() / APP_NAME / "astrea-latencyd.sock"


def state_dir() -> Path:
    return xdg_state_home() / APP_NAME / "latencyd"


def state_path() -> Path:
    return state_dir() / "state.json"


def history_path() -> Path:
    return state_dir() / "history.jsonl"


def command_available(name: str) -> bool:
    return shutil.which(name) is not None


def run_command(
    args: list[str], timeout: float = 1.5
) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            args,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        return subprocess.CompletedProcess(
            args,
            124,
            (
                exc.stdout.decode("utf-8", "replace")
                if isinstance(exc.stdout, bytes)
                else (exc.stdout or "")
            ),
            (
                exc.stderr.decode("utf-8", "replace")
                if isinstance(exc.stderr, bytes)
                else (exc.stderr or "timeout")
            ),
        )


def run_burst_helper(args: list[str], timeout: float = 1.5) -> dict[str, Any] | None:
    if not BURST_HELPER.exists() or not command_available("sudo"):
        return None
    result = run_command(["sudo", "-n", str(BURST_HELPER), *args], timeout=timeout)
    text = (result.stdout or "").strip()
    if result.returncode != 0:
        return {
            "ok": False,
            "details": [(result.stderr or result.stdout or "helper failed").strip()],
        }
    try:
        payload = json.loads(text or "{}")
    except json.JSONDecodeError:
        return {"ok": False, "details": [f"helper returned invalid json: {text}"]}
    return payload


def read_power_profile() -> str | None:
    if not command_available("powerprofilesctl"):
        return None
    result = run_command(["powerprofilesctl", "get"])
    if result.returncode != 0:
        return None
    value = result.stdout.strip()
    return value or None


def set_power_profile(profile: str) -> str:
    if not command_available("powerprofilesctl"):
        return "powerprofilesctl missing"
    result = run_command(["powerprofilesctl", "set", profile])
    if result.returncode == 0:
        return f"power profile -> {profile}"
    return (result.stderr or result.stdout or "power profile failed").strip()


def read_text(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError:
        return None


def write_text(path: Path, value: str) -> tuple[bool, str]:
    try:
        path.write_text(value, encoding="utf-8")
        return True, f"{path} -> {value.strip()}"
    except OSError as exc:
        return False, f"{path}: {exc}"


def privilege_unavailable(action: str) -> str:
    return f"privileged helper required for {action}"



def cpu_governor_paths() -> list[Path]:
    return sorted(
        Path("/sys/devices/system/cpu/cpufreq").glob("policy*/scaling_governor")
    )


def snapshot_cpu_governors() -> dict[str, str]:
    snapshot: dict[str, str] = {}
    for path in cpu_governor_paths():
        value = read_text(path)
        if value:
            snapshot[str(path)] = value
    return snapshot


def set_cpu_governor(governor: str) -> list[str]:
    details: list[str] = []
    paths = cpu_governor_paths()
    changed_direct = 0
    for path in paths:
        ok, detail = write_text(path, governor + "\n")
        if ok:
            changed_direct += 1
        elif len(details) < 4:
            details.append(detail)

    if changed_direct == len(paths) and paths:
        return [f"cpu governors -> {governor} direct ({changed_direct})"]
    if changed_direct > 0:
        details.append(
            f"cpu governors -> {governor} direct partial ({changed_direct}/{len(paths)})"
        )

    if command_available("cpupower"):
        result = run_command(["cpupower", "frequency-set", "-g", governor], timeout=1.5)
        if result.returncode == 0:
            details.append(f"cpupower governor -> {governor}")
            return details
        details.append(
            f"cpupower: {(result.stderr or result.stdout or 'failed').strip()}"
        )

    details.append(privilege_unavailable("cpu governor"))
    return details


def privileged_burst() -> tuple[dict[str, Any] | None, list[str]]:
    payload = run_burst_helper(["burst"])
    if payload is None:
        return None, ["burst helper unavailable"]
    details = [str(item) for item in payload.get("details", [])]
    if payload.get("ok"):
        return (
            payload.get("snapshot")
            if isinstance(payload.get("snapshot"), dict)
            else None
        ), [
            "burst helper ok",
            *details,
        ]
    return None, ["burst helper failed", *details]


def privileged_restore(snapshot: dict[str, Any] | None) -> list[str]:
    if not snapshot:
        return ["no privileged burst snapshot"]
    payload = run_burst_helper(["restore", json.dumps(snapshot, separators=(",", ":"))])
    if payload is None:
        return ["burst helper unavailable for restore"]
    details = [str(item) for item in payload.get("details", [])]
    return [
        (
            "burst helper restore ok"
            if payload.get("ok")
            else "burst helper restore failed"
        ),
        *details,
    ]


def privileged_pid_boost(pid: int) -> list[str]:
    payload = run_burst_helper(["pid", str(pid)])
    if payload is None:
        return ["burst helper unavailable for pid"]
    details = [str(item) for item in payload.get("details", [])]
    return [
        "burst helper pid ok" if payload.get("ok") else "burst helper pid failed",
        *details,
    ]


def restore_cpu_governors(snapshot: dict[str, str]) -> list[str]:
    if not snapshot:
        return ["no cpu governor snapshot"]
    details: list[str] = []
    failed: dict[str, str] = {}
    for path_text, governor in snapshot.items():
        ok, detail = write_text(Path(path_text), governor + "\n")
        if ok:
            continue
        failed[path_text] = governor
        if len(details) < 4:
            details.append(detail)
    if not failed:
        return [f"cpu governors restored direct ({len(snapshot)})"]
    unique_governors = sorted(set(snapshot.values()))
    if len(unique_governors) == 1 and command_available("cpupower"):
        governor = unique_governors[0]
        result = run_command(["cpupower", "frequency-set", "-g", governor], timeout=1.5)
        if result.returncode == 0:
            details.append(f"cpupower governor restored -> {governor}")
            return details
        details.append(
            f"cpupower restore: {(result.stderr or result.stdout or 'failed').strip()}"
        )
    details.append(privilege_unavailable("cpu governor restore"))
    return details


def set_intel_turbo(enabled: bool) -> str:
    if not INTEL_NO_TURBO.exists():
        return "intel turbo knob missing"
    value = "0\n" if enabled else "1\n"
    ok, detail = write_text(INTEL_NO_TURBO, value)
    if ok:
        return "intel turbo enabled" if enabled else "intel turbo disabled"
    return f"{detail}; {privilege_unavailable('intel turbo')}"


def apply_gpu_burst() -> list[str]:
    # GPU PowerMizer and persistence settings are intentionally not mutated by
    # temporary bursts until the daemon can snapshot and restore vendor state
    # reliably on rollback.
    return ["gpu burst skipped: rollback snapshot unsupported"]


def boost_pid(pid: int) -> list[str]:
    details: list[str] = []
    if pid <= 0 or not Path(f"/proc/{pid}").exists():
        return [f"pid {pid} not found"]

    if command_available("gamemoded"):
        result = run_command(["gamemoded", f"-r{pid}"])
        details.append(
            "gamemode pid toggle ok"
            if result.returncode == 0
            else f"gamemode: {(result.stderr or result.stdout).strip()}"
        )

    helper_details = privileged_pid_boost(pid)
    if not helper_details[0].endswith("ok"):
        if command_available("renice"):
            result = run_command(["renice", "-n", "-15", "-p", str(pid)])
            details.append(
                "renice ok"
                if result.returncode == 0
                else f"renice: {(result.stderr or result.stdout).strip()}"
            )

        if command_available("ionice"):
            result = run_command(["ionice", "-c", "2", "-n", "0", "-p", str(pid)])
            details.append(
                "ionice ok"
                if result.returncode == 0
                else f"ionice: {(result.stderr or result.stdout).strip()}"
            )
    details.extend(helper_details)

    return details or ["no pid boost helpers available"]


def now_ms() -> int:
    return int(time.time() * 1000)


def atomic_write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    tmp.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    tmp.replace(path)


def append_history(payload: dict[str, Any]) -> None:
    path = history_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=False) + "\n")


@dataclass
class Boost:
    reason: str
    deadline_ms: int
    pid: int | None = None


@dataclass
class LatencyDaemon:
    active: bool = False
    previous_profile: str | None = None
    previous_governors: dict[str, str] = field(default_factory=dict)
    previous_no_turbo: str | None = None
    privileged_snapshot: dict[str, Any] | None = None
    boosts: list[Boost] = field(default_factory=list)
    details: list[str] = field(default_factory=list)
    running: bool = True

    def handle_payload(self, payload: dict[str, Any]) -> None:
        if payload.get("op") != "boost":
            self.record("ignored", payload, ["unknown op"])
            return

        reason = str(payload.get("reason") or "unspecified")
        duration_ms = min(
            int(payload.get("duration_ms") or DEFAULT_DURATION_MS), MAX_BURST_MS
        )
        duration_ms = max(250, duration_ms)
        pid = parse_pid(payload.get("pid"))
        deadline = now_ms() + duration_ms

        if not self.active:
            self.previous_profile = read_power_profile()
            self.previous_governors = snapshot_cpu_governors()
            self.previous_no_turbo = read_text(INTEL_NO_TURBO)
            self.active = True
            self.privileged_snapshot, privileged_details = privileged_burst()
            self.details.extend(privileged_details)
            if self.privileged_snapshot is None:
                self.details.append(set_power_profile("performance"))
                self.details.extend(set_cpu_governor("performance"))
                self.details.append(set_intel_turbo(True))
            self.details.extend(apply_gpu_burst())

        boost_details = [f"boost {reason} for {duration_ms}ms"]
        if pid:
            boost_details.extend(boost_pid(pid))
        self.boosts.append(Boost(reason=reason, deadline_ms=deadline, pid=pid))
        self.prune_expired()
        self.record("boost", payload, boost_details)
        self.write_state()

    def prune_expired(self) -> None:
        current = now_ms()
        self.boosts = [boost for boost in self.boosts if boost.deadline_ms > current]
        if self.active and not self.boosts:
            self.rollback()

    def rollback(self) -> None:
        details: list[str] = []
        if self.previous_profile and self.previous_profile != "performance":
            details.append(set_power_profile(self.previous_profile))
        details.extend(privileged_restore(self.privileged_snapshot))
        if self.privileged_snapshot is None:
            details.extend(restore_cpu_governors(self.previous_governors))
            if self.previous_no_turbo is not None:
                ok, detail = write_text(INTEL_NO_TURBO, self.previous_no_turbo + "\n")
                details.append(
                    "intel turbo restored"
                    if ok
                    else f"{detail}; {privilege_unavailable('intel turbo restore')}"
                )
        self.active = False
        self.previous_profile = None
        self.previous_governors = {}
        self.previous_no_turbo = None
        self.privileged_snapshot = None
        self.details = details
        self.record("rollback", {"op": "rollback"}, details or ["nothing to rollback"])
        self.write_state()

    def next_timeout(self) -> float:
        self.prune_expired()
        if not self.boosts:
            return 5.0
        deadline = min(boost.deadline_ms for boost in self.boosts)
        return max(0.05, min(5.0, (deadline - now_ms()) / 1000))

    def write_state(self) -> None:
        payload = {
            "active": self.active,
            "now_ms": now_ms(),
            "previous_profile": self.previous_profile,
            "current_profile": read_power_profile(),
            "cpu_governors": snapshot_cpu_governors(),
            "boosts": [boost.__dict__ for boost in self.boosts],
            "details": self.details[-12:],
            "socket": str(socket_path()),
        }
        atomic_write_json(state_path(), payload)

    def record(self, event: str, payload: dict[str, Any], details: list[str]) -> None:
        append_history(
            {
                "timestamp_ms": now_ms(),
                "event": event,
                "payload": payload,
                "details": details,
            }
        )


def parse_pid(value: Any) -> int | None:
    try:
        pid = int(value)
    except (TypeError, ValueError):
        return None
    return pid if pid > 0 else None


def install_signal_handlers(daemon: LatencyDaemon) -> None:
    def stop(_signum: int, _frame: Any) -> None:
        daemon.running = False

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)


def serve() -> int:
    path = socket_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        path.unlink()
    except FileNotFoundError:
        pass

    daemon = LatencyDaemon()
    install_signal_handlers(daemon)

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(path))
    os.chmod(path, 0o600)
    server.listen(16)
    server.setblocking(False)

    selector = selectors.DefaultSelector()
    selector.register(server, selectors.EVENT_READ)
    daemon.write_state()

    try:
        while daemon.running:
            for key, _mask in selector.select(daemon.next_timeout()):
                if key.fileobj is server:
                    conn, _addr = server.accept()
                    with conn:
                        data = conn.recv(8192)
                    for line in data.splitlines():
                        try:
                            payload = json.loads(line.decode("utf-8"))
                            daemon.handle_payload(payload)
                        except Exception as exc:
                            daemon.record(
                                "error",
                                {"raw": line.decode("utf-8", "replace")},
                                [str(exc)],
                            )
            daemon.prune_expired()
    finally:
        daemon.rollback()
        selector.close()
        server.close()
        try:
            path.unlink()
        except FileNotFoundError:
            pass
    return 0


def doctor() -> int:
    payload = {
        "socket": str(socket_path()),
        "socket_exists": socket_path().exists(),
        "state": str(state_path()),
        "history": str(history_path()),
        "powerprofilesctl": command_available("powerprofilesctl"),
        "current_profile": read_power_profile(),
        "cpu_governors": snapshot_cpu_governors(),
        "intel_no_turbo": read_text(INTEL_NO_TURBO),
        "renice": command_available("renice"),
        "ionice": command_available("ionice"),
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


def status() -> int:
    try:
        print(state_path().read_text(encoding="utf-8"), end="")
    except FileNotFoundError:
        print("{}")
    return 0


def self_test() -> int:
    path = socket_path()
    if not path.exists():
        print(f"socket missing: {path}", file=sys.stderr)
        return 1
    payload = {
        "op": "boost",
        "reason": "self-test",
        "duration_ms": 750,
        "source": "astrea-latencyd",
    }
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.connect(str(path))
        client.sendall((json.dumps(payload) + "\n").encode("utf-8"))
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Astrea latency boost daemon")
    parser.add_argument(
        "command",
        nargs="?",
        default="serve",
        choices=["serve", "doctor", "status", "self-test"],
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.command == "serve":
        return serve()
    if args.command == "doctor":
        return doctor()
    if args.command == "status":
        return status()
    if args.command == "self-test":
        return self_test()
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
