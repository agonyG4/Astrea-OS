#!/usr/bin/env python3

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path
from urllib.request import Request, urlopen


def cache_dir() -> Path:
    base = os.environ.get("XDG_CACHE_HOME")
    if base:
        return Path(base).expanduser() / "astrea"
    return Path.home() / ".cache/astrea"


def fetch(url: str) -> Path:
    target_dir = cache_dir()
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / "island-art-current.jpg"
    request = Request(url, headers={"User-Agent": "Astrea/1"})

    fd, tmp_name = tempfile.mkstemp(prefix=".island-art-current.", suffix=".tmp", dir=str(target_dir))
    tmp = Path(tmp_name)
    try:
        with os.fdopen(fd, "wb") as handle:
            with urlopen(request, timeout=10) as response:
                while True:
                    chunk = response.read(128 * 1024)
                    if not chunk:
                        break
                    handle.write(chunk)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, target)
        return target
    except Exception:
        try:
            tmp.unlink()
        except FileNotFoundError:
            pass
        raise


def main() -> None:
    if len(sys.argv) < 2 or not sys.argv[1]:
        raise SystemExit(2)
    print(fetch(sys.argv[1]))


if __name__ == "__main__":
    main()
