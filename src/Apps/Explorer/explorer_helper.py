#!/usr/bin/env python3

from __future__ import annotations

import argparse
import ctypes
import os
import select
import signal
import shutil
import subprocess
import time
import urllib.parse
from pathlib import Path


def create_folder(base_text: str, name: str) -> None:
    base = Path(base_text).expanduser()
    target = base / name
    index = 2
    while target.exists():
        target = base / f"{name} {index}"
        index += 1
    target.mkdir()


def rename_path(source_text: str, new_name: str) -> None:
    source = Path(source_text).expanduser()
    target = source.parent / new_name
    if source == target:
        return
    if target.exists():
        raise SystemExit(1)
    os.rename(source, target)


def suggest_dirs(base_text: str, prefix: str) -> None:
    base = Path(base_text).expanduser()
    if not base.is_dir():
        return
    matches = []
    for entry in base.iterdir():
        if entry.is_dir() and entry.name.startswith(prefix):
            matches.append(str(entry))
    for entry in sorted(matches)[:12]:
        print(entry)


def process_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def read_pid(path: Path) -> int | None:
    try:
        return int(path.read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        return None


def quicklook(selected: str, pathfile_text: str, pidfile_text: str) -> None:
    pathfile = Path(pathfile_text)
    pidfile = Path(pidfile_text)
    pid = read_pid(pidfile)
    if pid and process_alive(pid):
        try:
            current = pathfile.read_text(encoding="utf-8")
        except OSError:
            current = ""
        if current == selected:
            os.kill(pid, signal.SIGTERM)
            pathfile.unlink(missing_ok=True)
            pidfile.unlink(missing_ok=True)
        else:
            pathfile.write_text(selected, encoding="utf-8")
        return

    pathfile.write_text(selected, encoding="utf-8")
    pidfile.unlink(missing_ok=True)
    quicklook_qml = os.environ.get("ASTREA_QUICKLOOK_QML") or str(Path.home() / "GitHub/Bench/Look/quicklook.qml")
    with open(os.devnull, "wb") as devnull:
        proc = subprocess.Popen(["qs", "-p", quicklook_qml], stdout=devnull, stderr=devnull, start_new_session=True)
    pidfile.write_text(str(proc.pid), encoding="utf-8")


def quicklook_sync(selected: str, pidfile_text: str, pathfile_text: str) -> None:
    pathfile = Path(pathfile_text)
    pid = read_pid(Path(pidfile_text))
    if not pid or not process_alive(pid):
        return
    try:
        current = pathfile.read_text(encoding="utf-8")
    except OSError:
        current = ""
    if current != selected:
        pathfile.write_text(selected, encoding="utf-8")


def network_mount_probe(root_text: str) -> None:
    root = Path(root_text)
    if not root.is_dir():
        raise SystemExit(2)
    for entry in root.iterdir():
        print(entry)
        return


def copy_uri_list(paths: list[str]) -> None:
    payload = "".join(f"file://{path}\n" for path in paths)
    subprocess.run(["wl-copy", "--type", "text/uri-list"], input=payload, text=True, check=True)

IMAGE_MIME_EXTENSIONS = {
    "image/png": "png",
    "image/jpeg": "jpg",
    "image/webp": "webp",
    "image/gif": "gif",
    "image/bmp": "bmp",
    "image/tiff": "tiff",
    "image/x-portable-pixmap": "ppm",
    "image/x-portable-graymap": "pgm",
    "image/x-portable-bitmap": "pbm",
}
ARCHIVE_FORMAT_EXTENSIONS = {"zip": "zip", "rar": "rar", "tar": "tar", "tar.gz": "tar.gz", "tar.xz": "tar.xz"}


def image_extension_for_mime(mime_type: str) -> str:
    return IMAGE_MIME_EXTENSIONS.get(mime_type, "png")


def paste_image(destination_dir_text: str, mime_type: str, paste_runner=None) -> str:
    destination_dir = Path(destination_dir_text).expanduser()
    if not destination_dir.is_dir():
        raise SystemExit(2)

    ext = image_extension_for_mime(mime_type)
    stamp = time.strftime("%Y-%m-%d %H-%M-%S")
    base_name = f"Pasted Image {stamp}"
    target = _unique_target(destination_dir, f"{base_name}.{ext}")

    runner = paste_runner or subprocess.run
    result = runner(
        ["wl-paste", "--no-newline", "--type", mime_type],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    target.write_bytes(result.stdout)
    print(target)
    return str(target)


def _json_event(payload: dict[str, object]) -> None:
    import json
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def _error_code_from_exception(exc: Exception) -> str:
    msg = str(exc).lower()
    if "permission denied" in msg:
        return "permission_denied"
    if "no such file" in msg or "not found" in msg:
        return "not_found"
    return "operation_failed"


def _pick_extractor(archive_path: Path, which_runner=shutil.which) -> list[str]:
    lower = archive_path.name.lower()
    if lower.endswith(".zip"):
        if which_runner("unzip"):
            return ["unzip", "-o", str(archive_path), "-d"]
        if which_runner("bsdtar"):
            return ["bsdtar", "-xf", str(archive_path), "-C"]
        raise RuntimeError("missing_tool: unzip/bsdtar")
    if lower.endswith(".rar"):
        if which_runner("unrar"):
            return ["unrar", "x", "-o+", str(archive_path)]
        if which_runner("7z"):
            return ["7z", "x", "-y", str(archive_path)]
        raise RuntimeError("missing_tool: unrar/7z")
    if lower.endswith(".7z"):
        if which_runner("7z"):
            return ["7z", "x", "-y", str(archive_path)]
        raise RuntimeError("missing_tool: 7z")
    if which_runner("bsdtar"):
        return ["bsdtar", "-xf", str(archive_path), "-C"]
    if which_runner("tar"):
        return ["tar", "-xf", str(archive_path), "-C"]
    raise RuntimeError("missing_tool: bsdtar/tar")


def extract_archive(archive_path_text: str, folder_name: str, run_cmd=None, which_runner=shutil.which) -> None:
    archive_path = Path(archive_path_text).expanduser()
    if not archive_path.exists():
        _json_event({"event": "error", "mode": "extract", "code": "not_found", "message": "archive not found"})
        raise SystemExit(1)
    parent = archive_path.parent
    destination = _unique_target(parent, folder_name or archive_path.name)
    destination.mkdir(parents=True, exist_ok=True)
    _json_event({"event": "start", "mode": "extract", "name": archive_path.name, "destination": str(destination), "total": 1})
    runner = run_cmd or subprocess.run
    try:
        cmd = _pick_extractor(archive_path, which_runner)
        if cmd[0] == "unrar":
            runner(cmd + [str(destination) + "/"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        elif cmd[0] == "7z":
            runner(cmd + [f"-o{destination}"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        else:
            runner(cmd + [str(destination)], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        _json_event({"event": "progress", "mode": "extract", "done": 1, "total": 1, "percent": 100})
        _json_event({"event": "done", "mode": "extract", "destination": str(destination), "done": 1, "total": 1, "percent": 100})
    except RuntimeError as exc:
        _json_event({"event": "error", "mode": "extract", "code": "missing_tool", "message": str(exc), "destination": str(destination)})
        raise SystemExit(1)
    except Exception as exc:
        _json_event({"event": "error", "mode": "extract", "code": _error_code_from_exception(exc), "message": str(exc), "destination": str(destination)})
        raise SystemExit(1)


def compress_folder(folder_path_text: str, archive_format: str, run_cmd=None, which_runner=shutil.which) -> None:
    folder = Path(folder_path_text).expanduser()
    if not folder.is_dir():
        _json_event({"event": "error", "mode": "compress", "code": "not_found", "message": "folder not found"})
        raise SystemExit(1)
    ext = ARCHIVE_FORMAT_EXTENSIONS.get(archive_format)
    if not ext:
        _json_event({"event": "error", "mode": "compress", "code": "invalid_format", "message": "unsupported format"})
        raise SystemExit(1)
    target = _unique_target(folder.parent, f"{folder.name}.{ext}")
    _json_event({"event": "start", "mode": "compress", "name": folder.name, "destination": str(target), "total": 1})
    runner = run_cmd or subprocess.run
    try:
        if archive_format == "zip":
            if not which_runner("zip"): raise RuntimeError("zip")
            runner(["zip", "-qr", str(target), folder.name], check=True, cwd=str(folder.parent), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        elif archive_format == "rar":
            if not which_runner("rar"): raise RuntimeError("rar")
            runner(["rar", "a", "-idq", str(target), folder.name], check=True, cwd=str(folder.parent), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        else:
            if not which_runner("tar"): raise RuntimeError("tar")
            args = {"tar": ["tar", "-cf"], "tar.gz": ["tar", "-czf"], "tar.xz": ["tar", "-cJf"]}[archive_format]
            runner(args + [str(target), folder.name], check=True, cwd=str(folder.parent), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        _json_event({"event": "progress", "mode": "compress", "done": 1, "total": 1, "percent": 100})
        _json_event({"event": "done", "mode": "compress", "destination": str(target), "done": 1, "total": 1, "percent": 100})
    except RuntimeError as exc:
        _json_event({"event": "error", "mode": "compress", "code": "missing_tool", "message": f"missing_tool: {exc}", "destination": str(target)})
        raise SystemExit(1)
    except Exception as exc:
        _json_event({"event": "error", "mode": "compress", "code": _error_code_from_exception(exc), "message": str(exc), "destination": str(target)})
        raise SystemExit(1)


def _path_type(path: Path) -> str:
    try:
        path.lstat()
    except OSError:
        return "missing"
    if path.is_symlink():
        return "symlink"
    if path.is_dir():
        return "directory"
    if path.is_file():
        return "file"
    return "other"


def _conflict_record(source: Path, destination: Path) -> dict[str, object] | None:
    target = destination / source.name
    if source == target:
        return {
            "source": str(source),
            "destination": str(target),
            "name": source.name,
            "source_type": _path_type(source),
            "destination_type": _path_type(target),
            "conflict_kind": "same-path",
            "supported_policies": ["skip"],
        }
    if not target.exists():
        return None

    source_type = _path_type(source)
    destination_type = _path_type(target)
    if source_type == "directory" and destination_type == "directory":
        conflict_kind = "directory-merge"
        policies = ["skip", "overwrite", "keep-both", "merge"]
    elif source_type == "file" and destination_type == "file":
        conflict_kind = "file-replace"
        policies = ["skip", "overwrite", "keep-both", "rename"]
    elif source_type == "directory" and destination_type == "file":
        conflict_kind = "directory-over-file"
        policies = ["skip"]
    elif source_type == "file" and destination_type == "directory":
        conflict_kind = "file-over-directory"
        policies = ["skip"]
    else:
        conflict_kind = "name-collision"
        policies = ["skip", "keep-both"]

    return {
        "source": str(source),
        "destination": str(target),
        "name": source.name,
        "source_type": source_type,
        "destination_type": destination_type,
        "conflict_kind": conflict_kind,
        "supported_policies": policies,
    }


def scan_conflicts(destination_text: str, paths: list[str], output_format: str = "names") -> None:
    import json

    destination = Path(destination_text).expanduser()
    conflicts: list[dict[str, object]] = []
    for raw in paths:
        source = Path(raw).expanduser()
        record = _conflict_record(source, destination)
        if record is not None:
            conflicts.append(record)

    if output_format == "json":
        print(json.dumps(conflicts, ensure_ascii=False))
        return

    for item in conflicts:
        print(item["name"])


IN_CLOSE_WRITE = 0x00000008
IN_MOVED_FROM = 0x00000040
IN_MOVED_TO = 0x00000080
IN_CREATE = 0x00000100
IN_DELETE = 0x00000200
IN_DELETE_SELF = 0x00000400
IN_MOVE_SELF = 0x00000800
IN_ATTRIB = 0x00000004
IN_ONLYDIR = 0x01000000
IN_NONBLOCK = 0x00000800
IN_CLOEXEC = 0x00080000
DIR_WATCH_MASK = IN_CLOSE_WRITE | IN_MOVED_FROM | IN_MOVED_TO | IN_CREATE | IN_DELETE | IN_DELETE_SELF | IN_MOVE_SELF | IN_ATTRIB


def _dir_signature(path: Path) -> tuple:
    try:
        entries = []
        for entry in path.iterdir():
            try:
                stat = entry.stat()
            except OSError:
                continue
            entries.append((entry.name, stat.st_mtime_ns, stat.st_size, stat.st_mode))
        return tuple(sorted(entries))
    except OSError:
        return ()


def _emit_changed() -> None:
    print("changed", flush=True)


def _unique_target(parent: Path, name: str) -> Path:
    candidate = parent / name
    if not candidate.exists():
        return candidate
    stem, ext = os.path.splitext(name)
    index = 2
    while True:
        candidate = parent / f"{stem} {index}{ext}"
        if not candidate.exists():
            return candidate
        index += 1


def _encode_trash_path(path: Path) -> str:
    return urllib.parse.quote(str(path), safe="/")


def _decode_trash_path(path_text: str) -> str:
    return urllib.parse.unquote(path_text)


def trash_items(trash_files_text: str, trash_info_text: str, paths: list[str]) -> None:
    trash_files = Path(trash_files_text).expanduser()
    trash_info = Path(trash_info_text).expanduser()
    trash_files.mkdir(parents=True, exist_ok=True)
    trash_info.mkdir(parents=True, exist_ok=True)
    deletion_date = time.strftime("%Y-%m-%dT%H:%M:%S")

    for raw in paths:
        source = Path(raw).expanduser()
        if not source.exists():
            continue
        destination = _unique_target(trash_files, source.name)
        os.rename(source, destination)
        info_path = trash_info / f"{destination.name}.trashinfo"
        info_path.write_text(
            "[Trash Info]\n"
            f"Path={_encode_trash_path(source)}\n"
            f"DeletionDate={deletion_date}\n",
            encoding="utf-8",
        )


def restore_trash_items(trash_info_text: str, fallback_dir_text: str, paths: list[str]) -> None:
    trash_info = Path(trash_info_text).expanduser()
    fallback_dir = Path(fallback_dir_text).expanduser()
    fallback_dir.mkdir(parents=True, exist_ok=True)

    for raw in paths:
        trashed = Path(raw).expanduser()
        if not trashed.exists():
            continue
        info_path = trash_info / f"{trashed.name}.trashinfo"

        original = ""
        if info_path.exists():
            try:
                for line in info_path.read_text(encoding="utf-8").splitlines():
                    if line.startswith("Path="):
                        original = _decode_trash_path(line[5:])
                        break
            except OSError:
                original = ""

        target = Path(original) if original else (fallback_dir / trashed.name)
        parent = target.parent
        try:
            parent.mkdir(parents=True, exist_ok=True)
        except OSError:
            parent = fallback_dir

        final_target = _unique_target(parent, target.name)
        os.rename(trashed, final_target)
        info_path.unlink(missing_ok=True)


def empty_trash(trash_files_text: str, trash_info_text: str) -> None:
    trash_files = Path(trash_files_text).expanduser()
    trash_info = Path(trash_info_text).expanduser()
    trash_files.mkdir(parents=True, exist_ok=True)
    trash_info.mkdir(parents=True, exist_ok=True)

    for entry in trash_files.iterdir():
        if entry.is_dir() and not entry.is_symlink():
            shutil.rmtree(entry, ignore_errors=True)
        else:
            entry.unlink(missing_ok=True)

    for entry in trash_info.iterdir():
        if entry.is_dir() and not entry.is_symlink():
            shutil.rmtree(entry, ignore_errors=True)
        else:
            entry.unlink(missing_ok=True)


def _drain_inotify(fd: int) -> None:
    try:
        while os.read(fd, 4096):
            pass
    except BlockingIOError:
        return
    except OSError:
        return


def monitor_dir(path_text: str) -> None:
    path = Path(path_text).expanduser()
    if not path.is_dir():
        raise SystemExit(2)

    try:
        libc = ctypes.CDLL("libc.so.6", use_errno=True)
        fd = libc.inotify_init1(IN_NONBLOCK | IN_CLOEXEC)
        if fd < 0:
            raise OSError(ctypes.get_errno())
        wd = libc.inotify_add_watch(fd, os.fsencode(path), DIR_WATCH_MASK | IN_ONLYDIR)
        if wd < 0:
            os.close(fd)
            raise OSError(ctypes.get_errno())
    except Exception:
        last = _dir_signature(path)
        while True:
            time.sleep(1)
            current = _dir_signature(path)
            if current != last:
                last = current
                _emit_changed()
        return

    poller = select.poll()
    poller.register(fd, select.POLLIN | select.POLLERR | select.POLLHUP)
    try:
        while True:
            events = poller.poll(30000)
            if not events:
                continue
            _drain_inotify(fd)
            _emit_changed()
    finally:
        os.close(fd)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Small UI helpers for Astrea Explorer.")
    sub = parser.add_subparsers(dest="command", required=True)

    create = sub.add_parser("create-folder")
    create.add_argument("base")
    create.add_argument("name")

    rename = sub.add_parser("rename")
    rename.add_argument("source")
    rename.add_argument("new_name")

    suggest = sub.add_parser("suggest-dirs")
    suggest.add_argument("base")
    suggest.add_argument("prefix")

    which = sub.add_parser("which")
    which.add_argument("program")

    ql = sub.add_parser("quicklook")
    ql.add_argument("selected")
    ql.add_argument("pathfile")
    ql.add_argument("pidfile")

    qls = sub.add_parser("quicklook-sync")
    qls.add_argument("selected")
    qls.add_argument("pidfile")
    qls.add_argument("pathfile")

    probe = sub.add_parser("network-mount-probe")
    probe.add_argument("root")

    copy_uri = sub.add_parser("copy-uri-list")
    copy_uri.add_argument("paths", nargs="+")

    conflicts = sub.add_parser("scan-conflicts")
    conflicts.add_argument("destination")
    conflicts.add_argument("paths", nargs="+")
    conflicts.add_argument("--format", choices=["names", "json"], default="names")

    monitor = sub.add_parser("monitor-dir")
    monitor.add_argument("path")

    trash = sub.add_parser("trash")
    trash.add_argument("trash_files")
    trash.add_argument("trash_info")
    trash.add_argument("paths", nargs="+")

    restore = sub.add_parser("restore-trash")
    restore.add_argument("trash_info")
    restore.add_argument("fallback_dir")
    restore.add_argument("paths", nargs="+")

    empty = sub.add_parser("empty-trash")
    empty.add_argument("trash_files")
    empty.add_argument("trash_info")

    paste_image_cmd = sub.add_parser("paste-image")
    paste_image_cmd.add_argument("destination_dir")
    paste_image_cmd.add_argument("mime_type")
    extract_cmd = sub.add_parser("extract-archive")
    extract_cmd.add_argument("archive_path")
    extract_cmd.add_argument("folder_name")
    compress_cmd = sub.add_parser("compress-folder")
    compress_cmd.add_argument("folder_path")
    compress_cmd.add_argument("archive_format")

    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.command == "create-folder":
        create_folder(args.base, args.name)
    elif args.command == "rename":
        rename_path(args.source, args.new_name)
    elif args.command == "suggest-dirs":
        suggest_dirs(args.base, args.prefix)
    elif args.command == "which":
        raise SystemExit(0 if shutil.which(args.program) else 1)
    elif args.command == "quicklook":
        quicklook(args.selected, args.pathfile, args.pidfile)
    elif args.command == "quicklook-sync":
        quicklook_sync(args.selected, args.pidfile, args.pathfile)
    elif args.command == "network-mount-probe":
        network_mount_probe(args.root)
    elif args.command == "copy-uri-list":
        copy_uri_list(args.paths)
    elif args.command == "scan-conflicts":
        scan_conflicts(args.destination, args.paths, args.format)
    elif args.command == "monitor-dir":
        monitor_dir(args.path)
    elif args.command == "trash":
        trash_items(args.trash_files, args.trash_info, args.paths)
    elif args.command == "restore-trash":
        restore_trash_items(args.trash_info, args.fallback_dir, args.paths)
    elif args.command == "empty-trash":
        empty_trash(args.trash_files, args.trash_info)
    elif args.command == "paste-image":
        paste_image(args.destination_dir, args.mime_type)
    elif args.command == "extract-archive":
        extract_archive(args.archive_path, args.folder_name)
    elif args.command == "compress-folder":
        compress_folder(args.folder_path, args.archive_format)


if __name__ == "__main__":
    main()
