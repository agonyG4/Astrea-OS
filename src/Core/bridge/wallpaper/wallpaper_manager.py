#!/usr/bin/env python3
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_DIR = Path.home() / ".local/share/Astrea"
FEATURES_DIR = PROJECT_DIR / "Features/Paper"
USER_DATA_DIR = PROJECT_DIR / "Data/user"
USER_CONFIG_DIR = Path.home() / ".config/AstreaOS/user"
LIBRARY_DIRS = {
    "user": USER_DATA_DIR / "wallpapers",
    "dynamic": FEATURES_DIR / "library/dynamic",
    "landscapes": FEATURES_DIR / "library/landscapes",
}
STATE_DIRS = {
    "wallpaper": USER_CONFIG_DIR / "paper/wallpaper",
    "lockscreen": USER_CONFIG_DIR / "paper/lockscreen",
}
TRANSITIONS = [
    "simple",
    "fade",
    "left",
    "right",
    "top",
    "bottom",
    "wipe",
    "wave",
    "grow",
    "center",
    "outer",
    "any",
    "random",
]
TRANSITION_FILE = USER_CONFIG_DIR / "paper/wallpaper_transition.txt"


def read_text(path: Path, default: str = "") -> str:
    try:
        return path.read_text(encoding="utf-8").strip() or default
    except FileNotFoundError:
        return default


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f"{value}\n", encoding="utf-8")


def relink(target: Path, source: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() or target.is_symlink():
        target.unlink()
    target.symlink_to(source)


def ensure_thumb(src: Path, dest: Path) -> None:
    from img_cache import process_image

    process_image(src, dest)


def sanitize_slug(name: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "_", name.strip())
    slug = re.sub(r"_+", "_", slug).strip("._-")
    return slug or "wallpaper"


def unique_slug(base_slug: str, parent: Path) -> str:
    slug = base_slug
    suffix = 2
    while (parent / slug).exists():
        slug = f"{base_slug}_{suffix}"
        suffix += 1
    return slug


def library_item(folder: Path) -> dict | None:
    wallpaper = folder / "wallpaper.jpg"
    thumb = folder / "thumb.jpg"
    if not wallpaper.exists():
        return None

    if not thumb.exists() or wallpaper.stat().st_mtime > thumb.stat().st_mtime:
        ensure_thumb(wallpaper, thumb)

    return {
        "slug": folder.name,
        "name": read_text(folder / "name.txt", folder.name.replace("_", " ")),
        "wallpaperPath": str(wallpaper),
        "thumbPath": str(thumb),
        "thumbMtime": int(thumb.stat().st_mtime),
        "baseDir": str(folder.parent),
    }


def emit_json(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=True))


def transition_index() -> int:
    try:
        value = int(read_text(TRANSITION_FILE, "0"))
        if 0 <= value < len(TRANSITIONS):
            return value
    except ValueError:
        pass
    return 0


def set_transition(index: int) -> None:
    if index < 0 or index >= len(TRANSITIONS):
        raise ValueError("transition index invalido")
    write_text(TRANSITION_FILE, str(index))


def state_payload(scope: str) -> dict:
    state_dir = STATE_DIRS[scope]
    wallpaper = state_dir / "wallpaper.jpg"
    thumb = state_dir / "wallpaper_thumb.jpg"
    active_source = current_source(scope)
    defaults = {
        "wallpaper": "My Wallpaper",
        "lockscreen": "Lockscreen Wallpaper",
    }
    payload = {
        "scope": scope,
        "name": read_text(state_dir / "wallpaper_name.txt", defaults[scope]),
        "wallpaperPath": str(wallpaper),
        "thumbPath": str(thumb),
        "previewPath": str(thumb if thumb.exists() else (active_source or wallpaper)),
        "previewMtime": int(thumb.stat().st_mtime) if thumb.exists() else int(wallpaper.stat().st_mtime) if wallpaper.exists() else 0,
    }
    if scope == "wallpaper":
        payload["transitionIndex"] = transition_index()
    return payload


def scan_library() -> None:
    payload = {}
    for key, directory in LIBRARY_DIRS.items():
        items = []
        if directory.exists():
            for folder in sorted((p for p in directory.iterdir() if p.is_dir()), key=lambda p: p.name.lower()):
                item = library_item(folder)
                if item:
                    items.append(item)
        payload[key] = items
    emit_json(payload)


def run_awww(src: Path, transition_idx: int) -> None:
    transition = TRANSITIONS[transition_idx]
    subprocess.run(
        [
            "awww",
            "img",
            str(src),
            "--transition-type",
            transition,
            "--transition-duration",
            "1.5",
            "--transition-fps",
            "60",
        ],
        check=True,
    )


def spawn_detached(args: list[str]) -> None:
    subprocess.Popen(
        args,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        stdin=subprocess.DEVNULL,
        start_new_session=True,
        env=os.environ.copy(),
    )


def current_source(scope: str) -> Path | None:
    wallpaper = STATE_DIRS[scope] / "wallpaper.jpg"
    if not wallpaper.exists():
        return None
    try:
        return wallpaper.resolve()
    except FileNotFoundError:
        return None


def refresh_assets(scope: str, expected_src: str) -> None:
    from blur_lockscreen import generate_blur

    expected = Path(expected_src).expanduser().resolve()
    active = current_source(scope)
    if active != expected:
        return

    state_dir = STATE_DIRS[scope]
    wallpaper = state_dir / "wallpaper.jpg"
    thumb = state_dir / "wallpaper_thumb.jpg"
    ensure_thumb(wallpaper, thumb)

    active = current_source(scope)
    if active != expected:
        return

    if scope == "wallpaper":
        generate_blur(wallpaper)
    else:
        generate_blur(wallpaper, state_dir / "blurred.jpg")


def apply_scope(scope: str, src: str, name: str, transition_idx: int | None, no_animate: bool = False) -> None:
    source = Path(src).expanduser().resolve()
    if not source.exists():
        raise FileNotFoundError(f"wallpaper nao encontrado: {source}")

    state_dir = STATE_DIRS[scope]
    wallpaper = state_dir / "wallpaper.jpg"
    thumb = state_dir / "wallpaper_thumb.jpg"

    relink(wallpaper, source)
    write_text(state_dir / "wallpaper_name.txt", name)

    payload = {
        "scope": scope,
        "name": name,
        "wallpaperPath": str(wallpaper),
        "thumbPath": str(thumb),
        "previewPath": str(source),
        "previewMtime": int(source.stat().st_mtime),
    }

    if scope == "wallpaper":
        idx = transition_idx if transition_idx is not None else transition_index()
        set_transition(idx)
        payload["transitionIndex"] = idx

        if not no_animate:
            spawn_detached(
                [
                    sys.executable,
                    str(Path(__file__).resolve()),
                    "run-awww",
                    "--src",
                    str(source),
                    "--transition-index",
                    str(idx),
                ]
            )

        spawn_detached(
            [
                sys.executable,
                str(Path(__file__).resolve()),
                "refresh-assets",
                "--scope",
                scope,
                "--expected-src",
                str(source),
            ]
        )
    else:
        spawn_detached(
            [
                sys.executable,
                str(Path(__file__).resolve()),
                "refresh-assets",
                "--scope",
                scope,
                "--expected-src",
                str(source),
            ]
        )

    emit_json(payload)


def add_user_wallpaper(src: str, name: str) -> None:
    source = Path(src).expanduser().resolve()
    if not source.exists():
        raise FileNotFoundError(f"wallpaper nao encontrado: {source}")

    LIBRARY_DIRS["user"].mkdir(parents=True, exist_ok=True)
    slug = unique_slug(sanitize_slug(name), LIBRARY_DIRS["user"])
    target_dir = LIBRARY_DIRS["user"] / slug
    target_dir.mkdir(parents=True, exist_ok=True)

    wallpaper = target_dir / "wallpaper.jpg"
    shutil.copy2(source, wallpaper)
    write_text(target_dir / "name.txt", name)
    ensure_thumb(wallpaper, target_dir / "thumb.jpg")

    emit_json({"slug": slug, "item": library_item(target_dir)})


def main() -> None:
    parser = argparse.ArgumentParser(description="Astrea Wallpaper Manager")
    subparsers = parser.add_subparsers(dest="command", required=True)

    scan_parser = subparsers.add_parser("scan-library")
    scan_parser.set_defaults(handler=lambda _: scan_library())

    state_parser = subparsers.add_parser("state")
    state_parser.add_argument("--scope", choices=STATE_DIRS.keys(), required=True)
    state_parser.set_defaults(handler=lambda args: emit_json(state_payload(args.scope)))

    transition_parser = subparsers.add_parser("set-transition")
    transition_parser.add_argument("--index", type=int, required=True)
    transition_parser.set_defaults(handler=lambda args: set_transition(args.index))

    run_awww_parser = subparsers.add_parser("run-awww")
    run_awww_parser.add_argument("--src", required=True)
    run_awww_parser.add_argument("--transition-index", type=int, required=True)
    run_awww_parser.set_defaults(
        handler=lambda args: run_awww(Path(args.src).expanduser().resolve(), args.transition_index)
    )

    refresh_parser = subparsers.add_parser("refresh-assets")
    refresh_parser.add_argument("--scope", choices=STATE_DIRS.keys(), required=True)
    refresh_parser.add_argument("--expected-src", required=True)
    refresh_parser.set_defaults(handler=lambda args: refresh_assets(args.scope, args.expected_src))

    apply_parser = subparsers.add_parser("apply")
    apply_parser.add_argument("--scope", choices=STATE_DIRS.keys(), required=True)
    apply_parser.add_argument("--src", required=True)
    apply_parser.add_argument("--name", required=True)
    apply_parser.add_argument("--transition-index", type=int)
    apply_parser.add_argument("--no-animate", action="store_true")
    apply_parser.set_defaults(
        handler=lambda args: apply_scope(
            args.scope,
            args.src,
            args.name,
            args.transition_index,
            args.no_animate,
        )
    )

    add_user_parser = subparsers.add_parser("add-user")
    add_user_parser.add_argument("--src", required=True)
    add_user_parser.add_argument("--name", required=True)
    add_user_parser.set_defaults(handler=lambda args: add_user_wallpaper(args.src, args.name))

    args = parser.parse_args()

    try:
        args.handler(args)
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
