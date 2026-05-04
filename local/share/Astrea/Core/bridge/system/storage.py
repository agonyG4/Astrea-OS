#!/usr/bin/env python3
import os
import subprocess
import sys
from pathlib import Path


SENSE_SCRIPT = Path.home() / "GitHub/Bench/StorageSense/sense.py"


def main() -> int:
    if not SENSE_SCRIPT.exists():
        print('{"error":"StorageSense backend not found","data":[]}')
        return 0

    command = [sys.executable, str(SENSE_SCRIPT)] + sys.argv[1:]
    return subprocess.call(command, env=os.environ.copy())


if __name__ == "__main__":
    raise SystemExit(main())
