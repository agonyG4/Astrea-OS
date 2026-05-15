#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

DEFAULT_PATHS = [
    "src/System/launch/src/lib.rs",
    "src/System/launch/src/main.rs",
    "src/System/launch/tests/launcher_tests.rs",
    "src/System/scripts/astrea-performance",
    "src/System/scripts/astrea-spotlight",
    "src/System/scripts/bluetooth_manager.py",
    "src/System/services/astrea-services.sh",
    "src/System/services/astrea_latencyd.py",
    "src/System/services/astrea_statusd.py",
    "src/System/services/install-latency-burst-helper.sh",
    "src/System/services/smoke-launch-latency.sh",
    "src/Apps/Settings/pages/system/Performance.qml",
    "src/Quickshell/bar/modules/bluetooth/BluetoothProcess.qml",
    "src/Quickshell/spotlight/Spotlight.qml",
]


def check_file(path: Path, max_length: int) -> list[str]:
    failures: list[str] = []
    if not path.exists():
        failures.append(f"{path}: missing")
        return failures
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        length = len(line)
        if length > max_length:
            failures.append(f"{path}:{lineno}: line length {length} > {max_length}")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Fail on absurdly long source lines in key Astrea files."
    )
    parser.add_argument("paths", nargs="*", default=DEFAULT_PATHS)
    parser.add_argument("--max-length", type=int, default=300)
    args = parser.parse_args()

    failures: list[str] = []
    for raw_path in args.paths:
        failures.extend(check_file(Path(raw_path), args.max_length))

    if failures:
        print("Source line length check failed:")
        for failure in failures:
            print(f"  {failure}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
