#!/usr/bin/env python3
import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))

from astrea_email.cli import main
from astrea_email.gmail import *  # noqa: F401,F403


if __name__ == "__main__":
    raise SystemExit(main())
