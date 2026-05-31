#!/usr/bin/env python3
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

BRIDGE_DIR = Path(__file__).resolve().parents[1]


def _load_astrea_shared():
    import importlib.util
    spec = importlib.util.spec_from_file_location("astrea_shared_runtime", BRIDGE_DIR / "astrea_shared.py")
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module

ASTREA_SHARED = _load_astrea_shared()

atomic_write_text = ASTREA_SHARED.atomic_write_text

PROJECT_DIR = ASTREA_SHARED.astrea_root()
FEATURES_DIR = PROJECT_DIR / "Features/Paper"
LEGACY_USER_DATA_DIR = PROJECT_DIR / "Data/user"
USER_DATA_DIR = ASTREA_SHARED.xdg_data_home() / "AstreaOS/user"
USER_CONFIG_DIR = ASTREA_SHARED.xdg_config_home() / "AstreaOS/user"
USER_WALLPAPER_DIR = USER_DATA_DIR / "wallpapers"
LEGACY_USER_WALLPAPER_DIR = LEGACY_USER_DATA_DIR / "wallpapers"
LEGACY_MIGRATION_MARKER = USER_DATA_DIR / ".legacy_wallpapers_migrated"
LIBRARY_DIRS = {
    "user": USER_WALLPAPER_DIR,
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
BLURRED_WALLPAPER_FILE = USER_CONFIG_DIR / "paper/wallpaper_use_blurred.txt"


def read_text(path: Path, default: str = "") -> str:
    try:
        return path.read_text(encoding="utf-8").strip() or default
    except FileNotFoundError:
        return default


def write_text(path: Path, value: str) -> None:
    atomic_write_text(path, f"{value}\n")


def relink(target: Path, source: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_name(f".{target.name}.{os.getpid()}.tmp")
    tmp.unlink(missing_ok=True)
    tmp.symlink_to(source)
    os.replace(tmp, target)


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


def path_is_inside(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except (FileNotFoundError, ValueError):
        return False


def copy_wallpaper_folder(source_dir: Path, target_dir: Path) -> None:
    def ignore_tmp(_: str, names: list[str]) -> list[str]:
        return [name for name in names if name.startswith(".") and name.endswith(".tmp")]

    shutil.copytree(source_dir, target_dir, ignore=ignore_tmp)
    wallpaper = target_dir / "wallpaper.jpg"
    thumb = target_dir / "thumb.jpg"
    if wallpaper.exists() and (not thumb.exists() or wallpaper.stat().st_mtime > thumb.stat().st_mtime):
        ensure_thumb(wallpaper, thumb)


def staging_dir_for(target_dir: Path) -> Path:
    return target_dir.with_name(f".{target_dir.name}.{os.getpid()}.tmp")


def publish_wallpaper_folder(target_dir: Path, source: Path, name: str, source_path_text: str) -> None:
    staging = staging_dir_for(target_dir)
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True, exist_ok=False)
    try:
        wallpaper = staging / "wallpaper.jpg"
        shutil.copy2(source, wallpaper)
        write_text(staging / "name.txt", name)
        write_text(staging / "source_path.txt", source_path_text)
        ensure_thumb(wallpaper, staging / "thumb.jpg")
        os.replace(staging, target_dir)
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        raise


def migrate_legacy_user_wallpapers() -> None:
    if LEGACY_MIGRATION_MARKER.exists():
        return
    if not LEGACY_USER_WALLPAPER_DIR.exists():
        return
    if LEGACY_USER_WALLPAPER_DIR.resolve() == USER_WALLPAPER_DIR.resolve():
        return

    USER_WALLPAPER_DIR.mkdir(parents=True, exist_ok=True)
    for folder in sorted((p for p in LEGACY_USER_WALLPAPER_DIR.iterdir() if p.is_dir()), key=lambda p: p.name.lower()):
        if not (folder / "wallpaper.jpg").exists():
            continue
        target = USER_WALLPAPER_DIR / folder.name
        if target.exists():
            continue
        copy_wallpaper_folder(folder, target)
    write_text(LEGACY_MIGRATION_MARKER, str(LEGACY_USER_WALLPAPER_DIR.resolve()))


def existing_import_for_source(source: Path) -> Path | None:
    if not USER_WALLPAPER_DIR.exists():
        return None
    source_text = str(source.resolve())
    for folder in sorted((p for p in USER_WALLPAPER_DIR.iterdir() if p.is_dir()), key=lambda p: p.name.lower()):
        if read_text(folder / "source_path.txt") == source_text and (folder / "wallpaper.jpg").exists():
            return folder / "wallpaper.jpg"
    return None


def import_external_wallpaper(source: Path, name: str) -> Path:
    existing = existing_import_for_source(source)
    if existing:
        return existing

    USER_WALLPAPER_DIR.mkdir(parents=True, exist_ok=True)
    slug = unique_slug(sanitize_slug(name or source.stem), USER_WALLPAPER_DIR)
    target_dir = USER_WALLPAPER_DIR / slug
    publish_wallpaper_folder(
        target_dir,
        source,
        name or source.stem or "Wallpaper",
        str(source.resolve()),
    )
    return target_dir / "wallpaper.jpg"


def managed_source_for_apply(source: Path, name: str) -> Path:
    migrate_legacy_user_wallpapers()

    managed_roots = [
        USER_WALLPAPER_DIR,
        LIBRARY_DIRS["dynamic"],
        LIBRARY_DIRS["landscapes"],
    ]
    if any(path_is_inside(source, root) for root in managed_roots):
        return source

    if path_is_inside(source, LEGACY_USER_WALLPAPER_DIR):
        folder = source.parent
        slug = folder.name
        target_dir = USER_WALLPAPER_DIR / slug
        if not target_dir.exists():
            USER_WALLPAPER_DIR.mkdir(parents=True, exist_ok=True)
            copy_wallpaper_folder(folder, target_dir)
        return target_dir / source.name

    return import_external_wallpaper(source, name)


def library_item(folder: Path) -> dict | None:
    wallpaper = folder / "wallpaper.jpg"
    thumb = folder / "thumb.jpg"
    blurred = blurred_variant(folder)
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
        "blurredPath": str(blurred) if blurred else "",
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


def blurred_variant(folder: Path) -> Path | None:
    for name in ("blurred.png", "blurred.jpg"):
        candidate = folder / name
        if candidate.exists():
            return candidate
    return None


def wallpaper_variant_for_mode(src: Path, use_blurred: bool) -> Path:
    if not use_blurred:
        return src
    blurred = blurred_variant(src.parent)
    return blurred if blurred else src


def blurred_enabled() -> bool:
    return read_text(BLURRED_WALLPAPER_FILE, "0") == "1"


def set_blurred_enabled(enabled: bool) -> None:
    write_text(BLURRED_WALLPAPER_FILE, "1" if enabled else "0")


def source_for_blur_mode_toggle(enabled: bool) -> Path | None:
    active = current_source("wallpaper")
    if not active:
        return None

    folder = active.parent
    wallpaper = folder / "wallpaper.jpg"
    blurred = blurred_variant(folder)
    if enabled:
        return blurred or active
    if blurred and active == blurred and wallpaper.exists():
        return wallpaper
    return active


def set_transition(index: int) -> None:
    if index < 0 or index >= len(TRANSITIONS):
        raise ValueError("transition index invalido")
    write_text(TRANSITION_FILE, str(index))


def state_payload(scope: str) -> dict:
    if scope == "lockscreen":
        try:
            refresh_active_assets(scope)
        except Exception as exc:
            print(f"[wallpaper] lockscreen asset refresh failed: {exc}", file=sys.stderr)

    state_dir = STATE_DIRS[scope]
    wallpaper = state_dir / "wallpaper.jpg"
    thumb = state_dir / "wallpaper_thumb.jpg"
    active_source = current_source(scope)
    active_blur = active_blur_source(scope, active_source)
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
        "activeSourcePath": str(active_source) if active_source else "",
        "activeSourceExists": bool(active_source and active_source.exists()),
        "activeBlurPath": str(active_blur) if active_blur else "",
        "activeBlurExists": bool(active_blur and active_blur.exists()),
    }
    if scope == "wallpaper":
        payload["transitionIndex"] = transition_index()
        payload["useBlurred"] = blurred_enabled()
    return payload


def scan_library() -> None:
    migrate_legacy_user_wallpapers()
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


def user_items() -> list[dict]:
    migrate_legacy_user_wallpapers()
    items = []
    if USER_WALLPAPER_DIR.exists():
        for folder in sorted((p for p in USER_WALLPAPER_DIR.iterdir() if p.is_dir()), key=lambda p: p.name.lower()):
            item = library_item(folder)
            if item:
                items.append(item)
    return items


def active_scopes_for_folder(folder: Path) -> list[str]:
    folder = folder.resolve()
    active = []
    for scope in STATE_DIRS:
        source = current_source(scope)
        if not source:
            continue
        if path_is_inside(source, folder):
            active.append(scope)
    return active


def list_user_wallpapers() -> None:
    emit_json({"user": user_items()})


def user_folder_for_slug(slug: str) -> Path:
    safe_slug = sanitize_slug(slug)
    folder = USER_WALLPAPER_DIR / safe_slug
    if not folder.exists() or not folder.is_dir():
        raise FileNotFoundError(f"wallpaper nao encontrado: {safe_slug}")
    return folder


def rename_user_wallpaper(slug: str, name: str) -> None:
    folder = user_folder_for_slug(slug)
    clean_name = name.strip() or folder.name.replace("_", " ")
    write_text(folder / "name.txt", clean_name)
    emit_json({"ok": True, "item": library_item(folder)})


def delete_user_wallpaper(slug: str) -> None:
    folder = user_folder_for_slug(slug)
    active = active_scopes_for_folder(folder)
    if active:
        raise RuntimeError("wallpaper em uso: " + ", ".join(active))
    shutil.rmtree(folder)
    emit_json({"ok": True, "slug": folder.name})


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


def active_blur_source(scope: str, active_source: Path | None = None) -> Path | None:
    if scope == "lockscreen":
        blurred = STATE_DIRS[scope] / "blurred.jpg"
        if not blurred.exists():
            return None
        try:
            return blurred.resolve()
        except FileNotFoundError:
            return None

    active = active_source or current_source(scope)
    if not active:
        return None
    return blurred_variant(active.parent)


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


def refresh_active_assets(scope: str) -> None:
    active = current_source(scope)
    if not active:
        return
    refresh_assets(scope, str(active))


def apply_scope(scope: str, src: str, name: str, transition_idx: int | None, no_animate: bool = False) -> None:
    source = Path(src).expanduser().resolve()
    if not source.exists():
        raise FileNotFoundError(f"wallpaper nao encontrado: {source}")
    source = managed_source_for_apply(source, name)
    source = wallpaper_variant_for_mode(source, blurred_enabled() if scope == "wallpaper" else False)

    state_dir = STATE_DIRS[scope]
    wallpaper = state_dir / "wallpaper.jpg"
    thumb = state_dir / "wallpaper_thumb.jpg"

    relink(wallpaper, source)
    write_text(state_dir / "wallpaper_name.txt", name)
    try:
        ensure_thumb(wallpaper, thumb)
    except Exception as exc:
        print(f"[wallpaper] thumbnail refresh failed: {exc}", file=sys.stderr)

    if scope == "lockscreen":
        try:
            refresh_assets(scope, str(source))
        except Exception as exc:
            print(f"[wallpaper] lockscreen asset refresh failed: {exc}", file=sys.stderr)

    preview = thumb if thumb.exists() else wallpaper
    preview_mtime = preview.stat().st_mtime if preview.exists() else source.stat().st_mtime

    payload = {
        "scope": scope,
        "name": name,
        "wallpaperPath": str(wallpaper),
        "thumbPath": str(thumb),
        "previewPath": str(preview),
        "previewMtime": int(preview_mtime),
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
    emit_json(payload)


def set_blurred_mode(enabled: bool, no_animate: bool = False) -> None:
    set_blurred_enabled(enabled)
    source = source_for_blur_mode_toggle(enabled)
    if source and source.exists():
        name = read_text(STATE_DIRS["wallpaper"] / "wallpaper_name.txt", "My Wallpaper")
        apply_scope("wallpaper", str(source), name, transition_index(), no_animate)
    else:
        emit_json(state_payload("wallpaper"))


def add_user_wallpaper(src: str, name: str) -> None:
    source = Path(src).expanduser().resolve()
    if not source.exists():
        raise FileNotFoundError(f"wallpaper nao encontrado: {source}")

    migrate_legacy_user_wallpapers()
    USER_WALLPAPER_DIR.mkdir(parents=True, exist_ok=True)
    slug = unique_slug(sanitize_slug(name), USER_WALLPAPER_DIR)
    target_dir = USER_WALLPAPER_DIR / slug
    publish_wallpaper_folder(target_dir, source, name, str(source))

    emit_json({"slug": slug, "item": library_item(target_dir)})


def main() -> None:
    parser = argparse.ArgumentParser(description="Astrea Wallpaper Manager")
    subparsers = parser.add_subparsers(dest="command", required=True)

    scan_parser = subparsers.add_parser("scan-library")
    scan_parser.set_defaults(handler=lambda _: scan_library())

    list_user_parser = subparsers.add_parser("list-user")
    list_user_parser.set_defaults(handler=lambda _: list_user_wallpapers())

    rename_user_parser = subparsers.add_parser("rename-user")
    rename_user_parser.add_argument("--slug", required=True)
    rename_user_parser.add_argument("--name", required=True)
    rename_user_parser.set_defaults(handler=lambda args: rename_user_wallpaper(args.slug, args.name))

    delete_user_parser = subparsers.add_parser("delete-user")
    delete_user_parser.add_argument("--slug", required=True)
    delete_user_parser.set_defaults(handler=lambda args: delete_user_wallpaper(args.slug))

    state_parser = subparsers.add_parser("state")
    state_parser.add_argument("--scope", choices=STATE_DIRS.keys(), required=True)
    state_parser.set_defaults(handler=lambda args: emit_json(state_payload(args.scope)))

    transition_parser = subparsers.add_parser("set-transition")
    transition_parser.add_argument("--index", type=int, required=True)
    transition_parser.set_defaults(handler=lambda args: set_transition(args.index))

    blur_parser = subparsers.add_parser("set-blurred")
    blur_parser.add_argument("--enabled", choices=("0", "1"), required=True)
    blur_parser.add_argument("--no-animate", action="store_true")
    blur_parser.set_defaults(
        handler=lambda args: set_blurred_mode(args.enabled == "1", args.no_animate)
    )

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
