#!/usr/bin/env python3
import json
import hashlib
import os
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse


IMAGE_EXTENSIONS = {
    ".avif",
    ".bmp",
    ".cr2",
    ".cr3",
    ".dds",
    ".dng",
    ".exr",
    ".gif",
    ".hdr",
    ".heic",
    ".heif",
    ".ico",
    ".jpeg",
    ".jpg",
    ".jxl",
    ".nef",
    ".orf",
    ".pbm",
    ".pef",
    ".pgm",
    ".png",
    ".ppm",
    ".psd",
    ".qoi",
    ".raf",
    ".raw",
    ".rw2",
    ".svg",
    ".srw",
    ".tif",
    ".tiff",
    ".webp",
    ".xcf",
    ".xpm",
}

DIRECT_IMAGE_EXTENSIONS = {
    ".bmp",
    ".gif",
    ".ico",
    ".jpeg",
    ".jpg",
    ".pbm",
    ".pgm",
    ".png",
    ".ppm",
    ".svg",
    ".tif",
    ".tiff",
    ".xpm",
}

PREVIEW_CACHE_VERSION = "display-lanczos-v1"
PREVIEW_MAX_DIMENSION = 1920
PREVIEW_CONVERT_TIMEOUT = 30

def media_kind(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix in IMAGE_EXTENSIONS:
        return "image"
    return "other"


def media_record(path: Path) -> dict:
    stat = path.stat()
    return {
        "name": path.name,
        "path": str(path),
        "uri": path.resolve().as_uri(),
        "kind": media_kind(path),
        "qt_native": path.suffix.lower() in DIRECT_IMAGE_EXTENSIONS,
        "size": stat.st_size,
        "modified": int(stat.st_mtime * 1000),
    }


def default_cache_dir() -> Path:
    return Path.home() / ".cache" / "Astrea" / "media-viewer" / "previews"


def preview_cache_path(path: Path, cache_dir=None) -> Path:
    path = path.resolve()
    stat = path.stat()
    cache_root = Path(cache_dir) if cache_dir is not None else default_cache_dir()
    fingerprint = f"{PREVIEW_CACHE_VERSION}:{path}:{stat.st_size}:{stat.st_mtime_ns}".encode("utf-8", "surrogateescape")
    return cache_root / (hashlib.sha256(fingerprint).hexdigest() + ".png")


def preview_temp_path(output: Path) -> Path:
    return output.with_name(f".{output.name}.{os.getpid()}.tmp")


def publish_preview(temp_output: Path, output: Path) -> None:
    os.replace(temp_output, output)


def preview_image(path, runner=subprocess.run, cache_dir=None) -> dict:
    path = normalize_target(path)
    if not path.is_file():
        return {"ok": False, "error": "Arquivo nao encontrado"}
    if media_kind(path) != "image":
        return {"ok": False, "error": "Arquivo nao e imagem"}

    if path.suffix.lower() in DIRECT_IMAGE_EXTENSIONS:
        return {"ok": True, "path": str(path), "uri": path.as_uri(), "source": "direct"}

    output = preview_cache_path(path, cache_dir)
    if output.is_file():
        return {"ok": True, "path": str(path), "uri": output.as_uri(), "source": "cache"}

    output.parent.mkdir(parents=True, exist_ok=True)
    temp_output = preview_temp_path(output)
    temp_output.unlink(missing_ok=True)
    magick = "magick" if shutil.which("magick") else ("convert" if shutil.which("convert") else "")
    if magick:
        input_arg = str(path)
        if path.suffix.lower() not in {".svg", ".xcf"}:
            input_arg += "[0]"
        command = [
            magick,
            input_arg,
            "-auto-orient",
            "-filter",
            "Lanczos",
            "-define",
            "filter:blur=0.92",
            "-resize",
            f"{PREVIEW_MAX_DIMENSION}x{PREVIEW_MAX_DIMENSION}>",
            "png:" + str(temp_output),
        ]
        try:
            runner(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=PREVIEW_CONVERT_TIMEOUT)
            publish_preview(temp_output, output)
            return {"ok": True, "path": str(path), "uri": output.as_uri(), "source": "converted"}
        except Exception:
            temp_output.unlink(missing_ok=True)

    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg:
        command = [
            ffmpeg,
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            str(path),
            "-frames:v",
            "1",
            str(temp_output),
        ]
        try:
            runner(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=PREVIEW_CONVERT_TIMEOUT)
            publish_preview(temp_output, output)
            return {"ok": True, "path": str(path), "uri": output.as_uri(), "source": "converted"}
        except Exception:
            temp_output.unlink(missing_ok=True)

    return {"ok": False, "error": "Formato nao suportado pelo Qt e nenhum conversor conseguiu gerar preview"}


def scan_directory(directory: Path) -> dict:
    directory = directory.expanduser().resolve()
    if not directory.is_dir():
        raise NotADirectoryError(str(directory))

    items = []
    for child in directory.iterdir():
        if not child.is_file():
            continue
        if media_kind(child) == "other":
            continue
        items.append(media_record(child))

    items.sort(key=lambda item: item["name"].lower())
    return {
        "directory": str(directory),
        "items": items,
        "selected_index": 0 if items else -1,
    }


def normalize_target(target) -> Path:
    raw = str(target)
    parsed = urlparse(raw)
    if parsed.scheme == "file":
        raw = unquote(parsed.path)
    return Path(raw).expanduser().resolve()


def open_target(target) -> dict:
    path = normalize_target(target)
    if path.is_dir():
        return scan_directory(path)
    if not path.is_file():
        raise FileNotFoundError(str(path))
    if media_kind(path) == "other":
        raise ValueError("Arquivo nao e imagem")

    payload = scan_directory(path.parent)
    selected_index = -1
    path_text = str(path)
    for index, item in enumerate(payload["items"]):
        if item["path"] == path_text:
            selected_index = index
            break
    payload["selected_index"] = selected_index
    return payload


def json_text(payload: dict) -> str:
    return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))


def main(argv=None, printer=print):
    argv = list(sys.argv[1:] if argv is None else argv)
    if not argv or argv[0] in {"-h", "--help"}:
        text = "usage: media_viewer_helper.py scan <directory> | open <target> | preview <image>"
        return printer(text)

    command = argv[0]
    try:
        if command == "scan" and len(argv) == 2:
            text = json_text(scan_directory(Path(argv[1])))
            return printer(text)
        if command == "open" and len(argv) == 2:
            text = json_text(open_target(argv[1]))
            return printer(text)
        if command == "preview" and len(argv) == 2:
            text = json_text(preview_image(argv[1]))
            return printer(text)
    except Exception as exc:
        text = json_text({"ok": False, "error": str(exc)})
        printer(text)
        return 1

    text = json_text({"ok": False, "error": "Comando invalido"})
    printer(text)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
