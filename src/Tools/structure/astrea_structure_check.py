#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

REQUIRED_DIRS = [
    "Apps",
    "Assets",
    "Backend",
    "Core",
    "Core/bridge",
    "Core/bridge/apps",
    "Core/bridge/audio",
    "Core/bridge/network",
    "Core/bridge/system",
    "Core/bridge/wallpaper",
    "Core/components",
    "Docs/Architecture",
    "Features",
    "Quickshell",
    "Runtime",
    "System",
    "Tools/structure",
    "UI",
]

REQUIRED_LINKS = {
    "Assets/audio": "../audio",
    "UI/shell": "../Quickshell",
    "UI/components": "../Core/components",
    "UI/assets": "../Assets/ui",
    "Backend/bridge": "../Core/bridge",
    "Backend/services": "../System/services",
    "Backend/portal": "../System/portal",
    "Backend/auth": "../System/auth",
    "Runtime/bin": "../bin",
    "Runtime/scripts": "../System/scripts",
    "Runtime/config": "../System/config",
    "Runtime/i18n": "../System/i18n",
}

LIVE_ENTRYPOINTS = [
    "Quickshell/shell.qml",
    "Apps/Settings/main.qml",
    "Core/components/qmldir",
    "Core/components/Theme.qml",
    "Core/components/theme/Theme.qml",
    "Core/bridge/astrea_shared.py",
    "Core/bridge/state_json.py",
    "System/services/astrea_statusd.py",
]

APP_BACKENDS_THAT_STAY_WITH_APPS = [
    "Apps/Weather/backend",
]

GENERATED_DIR_NAMES = {
    "__pycache__",
    ".pytest_cache",
    "node_modules",
    "target",
}

IGNORED_GENERATED_PARTS = {
    ".codex-backups",
}


def fail(message: str) -> None:
    raise AssertionError(message)


def check_required_dirs() -> None:
    for relative in REQUIRED_DIRS:
        path = ROOT / relative
        if not path.is_dir():
            fail(f"missing directory: {relative}")


def check_required_links() -> None:
    for relative, target in REQUIRED_LINKS.items():
        path = ROOT / relative
        if not path.is_symlink():
            fail(f"missing symlink: {relative}")
        actual = os.readlink(path)
        if actual != target:
            fail(f"wrong symlink target for {relative}: {actual!r} != {target!r}")
        if not path.exists():
            fail(f"broken symlink: {relative} -> {actual}")


def check_live_entrypoints() -> None:
    for relative in LIVE_ENTRYPOINTS:
        path = ROOT / relative
        if not path.exists():
            fail(f"missing live entrypoint: {relative}")


def check_app_backend_boundary() -> None:
    backend_apps = ROOT / "Backend/apps"
    if backend_apps.exists():
        fail("do not move app-owned backends into Backend/apps")

    for relative in APP_BACKENDS_THAT_STAY_WITH_APPS:
        path = ROOT / relative
        if not path.is_dir():
            fail(f"missing app-owned backend: {relative}")
        if path.is_symlink():
            fail(f"app-owned backend must remain real app-local directory: {relative}")


def check_no_broken_symlinks() -> None:
    for path in ROOT.rglob("*"):
        if ".codex-backups" in path.parts:
            continue
        if path.is_symlink() and not path.exists():
            fail(f"broken symlink: {path.relative_to(ROOT)} -> {os.readlink(path)}")


def check_no_generated_dirs() -> None:
    for path in ROOT.rglob("*"):
        if any(part in IGNORED_GENERATED_PARTS for part in path.parts):
            continue
        if path.is_dir() and path.name in GENERATED_DIR_NAMES:
            fail(f"generated directory should not live in runtime tree: {path.relative_to(ROOT)}")


def main() -> int:
    checks = [
        check_required_dirs,
        check_required_links,
        check_live_entrypoints,
        check_app_backend_boundary,
        check_no_broken_symlinks,
        check_no_generated_dirs,
    ]
    for check in checks:
        check()
    print("Astrea structure check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
