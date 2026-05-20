#!/usr/bin/env python3
from __future__ import annotations
import json
from pathlib import Path
import importlib.util
import sys

BRIDGE_DIR = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("astrea_shared_runtime", BRIDGE_DIR / "astrea_shared.py")
mod = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(mod)


def _load_sessiond():
    spec = importlib.util.spec_from_file_location("astrea_sessiond_runtime", BRIDGE_DIR / "astrea_sessiond.py")
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    sys.modules["astrea_sessiond_runtime"] = module
    spec.loader.exec_module(module)
    return module

SESSIOND = _load_sessiond()


def polling_hotspots() -> dict:
    return {
        "qml_process_hotspots": [
            {"area": "Explorer state", "note": "many file operation/list/watch Process nodes"},
            {"area": "Settings Paper", "note": "multiple wallpaper manager and cache Process calls"},
            {"area": "Desktop icons", "note": "signature/watch and several mutation commands"},
            {"area": "Settings connectivity", "note": "audio/network/bluetooth periodic bridge polling"},
            {"area": "Spotlight/Weather", "note": "periodic helper invocations for usage/weather"},
        ],
        "next_daemonization_candidates": ["audio", "bluetooth", "network", "weather", "notifications"],
    }


def check() -> dict:
    return {
        "ok": True,
        "bridge_dir": str(BRIDGE_DIR),
        "astrea_root": str(mod.astrea_root()),
        "application_dirs": [str(p) for p in mod.application_dirs()],
        "desktop_dir": str(mod.xdg_desktop_dir()),
        "sessiond": SESSIOND.status_payload(),
        "runtime_polling_audit": polling_hotspots(),
    }


if __name__ == "__main__":
    print(json.dumps(check(), ensure_ascii=False))
