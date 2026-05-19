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


def scan_conflicts(destination_text: str, paths: list[str]) -> None:
    destination = Path(destination_text).expanduser()
    for raw in paths:
        source = Path(raw).expanduser()
        target = destination / source.name
        if source != target and target.exists():
            print(source.name)


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

    monitor = sub.add_parser("monitor-dir")
    monitor.add_argument("path")

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
        scan_conflicts(args.destination, args.paths)
    elif args.command == "monitor-dir":
        monitor_dir(args.path)


if __name__ == "__main__":
    main()
