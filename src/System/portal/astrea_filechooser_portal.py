#!/usr/bin/env python3

import json
import mimetypes
import os
import re
import selectors
import subprocess
import tempfile
import time
from pathlib import Path
from urllib.parse import quote

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
import traceback


BUS_NAME = "org.freedesktop.impl.portal.desktop.astrea"
OBJECT_PATH = "/org/freedesktop/portal/desktop"
INTERFACE = "org.freedesktop.impl.portal.FileChooser"
RESULT_PREFIX = "__ASTREA_FILE_DIALOG__"
QSLOG_PATH_PATTERN = re.compile(r'Saving logs to "([^"]+log\.qslog)"')
ASTREA_ROOT = Path(os.environ.get("ASTREA_ROOT", Path.home() / ".local/share/Astrea"))
PORTAL_DIALOG_QML = str(ASTREA_ROOT / "Apps/Explorer/PortalDialog.qml")
QS_BIN = "/usr/bin/qs"
RESPONSE_SUCCESS = dbus.UInt32(0)
RESPONSE_CANCELLED = dbus.UInt32(1)
DEBUG_LOG = Path("/tmp/astrea_filechooser_portal.log")
DEBUG_ENABLED = os.environ.get("ASTREA_FILECHOOSER_DEBUG") == "1" or os.environ.get("BENCH_FILECHOOSER_DEBUG") == "1"


def log_debug(message):
    if not DEBUG_ENABLED:
        return
    try:
        DEBUG_LOG.parent.mkdir(parents=True, exist_ok=True)
        with DEBUG_LOG.open("a", encoding="utf-8") as handle:
            handle.write(message.rstrip() + "\n")
    except Exception:
        pass


def get_session_bus():
    return dbus.SessionBus()


def name_has_owner(bus, name):
    dbus_proxy = dbus.Interface(
        bus.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus"),
        "org.freedesktop.DBus",
    )
    return bool(dbus_proxy.NameHasOwner(name))


def decode_null_terminated_bytes(value):
    if value is None:
        return ""
    if isinstance(value, (dbus.Array, list, tuple)):
        raw = bytes(int(item) for item in value)
    elif isinstance(value, (bytes, bytearray)):
        raw = bytes(value)
    else:
        return str(value)

    return raw.split(b"\x00", 1)[0].decode("utf-8", errors="ignore")


def parse_filters(serialized_filters):
    name_filters = []
    if not serialized_filters:
        return name_filters

    for entry in serialized_filters:
        if len(entry) < 2:
            continue

        label = str(entry[0])
        patterns = []
        for item in entry[1]:
            if len(item) < 2:
                continue

            kind = int(item[0])
            value = str(item[1])
            if kind == 0:
                patterns.append(value)
            elif kind == 1:
                guessed = mimetypes.guess_all_extensions(value, strict=False) or []
                patterns.extend(f"*{ext}" for ext in guessed if ext)

        if patterns:
            name_filters.append(f"{label} ({' '.join(dict.fromkeys(patterns))})")

    return name_filters


def option_to_bool(value):
    if value is None:
        return False
    if isinstance(value, str):
        return value.strip().lower() in ("1", "true", "yes", "on")
    return bool(value)


def filters_include_file_types(serialized_filters):
    if not serialized_filters:
        return False

    for entry in serialized_filters:
        if len(entry) < 2:
            continue

        for item in entry[1]:
            if len(item) < 2:
                continue

            value = str(item[1]).strip()
            if not value:
                continue
            if value in ("*", "*.*"):
                return True
            if value.startswith("*."):
                return True
            if "/" in value and value not in ("inode/directory", "application/x-directory"):
                return True

    return False


def file_uri(path):
    return "file://" + quote(path)


def sanitize_save_file_name(value):
    name = decode_null_terminated_bytes(value).strip()
    if not name:
        return ""
    if name in (".", ".."):
        raise ValueError("invalid save file name")
    if os.path.isabs(name) or "/" in name or "\\" in name:
        raise ValueError("invalid save file name")
    if "\x00" in name or any(ord(ch) < 32 or ord(ch) == 127 for ch in name):
        raise ValueError("invalid save file name")
    return name


def parse_result_from_text(output):
    for line in reversed(output.splitlines()):
        if RESULT_PREFIX in line:
            prefix_index = line.index(RESULT_PREFIX)
            return json.loads(line[prefix_index + len(RESULT_PREFIX):])
    return None


def extract_qslog_path(output):
    match = QSLOG_PATH_PATTERN.search(output)
    if match:
        return Path(match.group(1))
    return None


def resolve_qslog_path(child_pid, output):
    explicit = extract_qslog_path(output)
    if explicit is not None:
        return explicit

    runtime_dir = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    qslog_path = runtime_dir / "quickshell" / "by-pid" / str(child_pid) / "log.qslog"
    if not qslog_path.exists():
        return None

    try:
        return qslog_path.resolve(strict=False)
    except Exception:
        return qslog_path


def read_qslog_result(qslog_path):
    if qslog_path is None or not qslog_path.exists():
        return None

    try:
        data = qslog_path.read_bytes()
    except Exception:
        return None

    pattern = re.escape(RESULT_PREFIX.encode("utf-8")) + rb'(\{.*?\})'
    matches = list(re.finditer(pattern, data, re.DOTALL))
    for match in reversed(matches):
        try:
            return json.loads(match.group(1).decode("utf-8", errors="ignore"))
        except json.JSONDecodeError:
            continue

    return None


def run_dialog(mode, title, options):
    current_file = decode_null_terminated_bytes(options.get("current_file"))
    start_folder = decode_null_terminated_bytes(options.get("current_folder"))
    current_name = str(options.get("current_name", ""))

    if current_file:
        current_path = Path(current_file)
        if current_path.is_dir():
            start_folder = str(current_path)
        else:
            start_folder = str(current_path.parent)
            if not current_name:
                current_name = current_path.name

    env = os.environ.copy()
    result_file = tempfile.NamedTemporaryFile(
        prefix="astrea_file_dialog_result_",
        suffix=".json",
        dir="/tmp",
        delete=False,
    )
    result_path = result_file.name
    result_file.close()
    dialog_options = json.dumps(
        {
            "mode": mode,
            "title": title or "",
            "startFolder": start_folder or str(Path.home()),
            "acceptLabel": str(options.get("accept_label", "")),
            "currentName": current_name,
            "filters": parse_filters(options.get("filters")),
            "multiple": option_to_bool(options.get("multiple", False)),
        }
    )
    env["ASTREA_FILE_DIALOG_OPTIONS"] = dialog_options
    env["ASTREA_FILE_DIALOG_RESULT_FILE"] = result_path
    env["BENCH_FILE_DIALOG_OPTIONS"] = dialog_options
    env["BENCH_FILE_DIALOG_RESULT_FILE"] = result_path
    log_debug(f"run_dialog mode={mode} title={title!r}")
    if not Path(PORTAL_DIALOG_QML).is_file():
        log_debug(f"Portal dialog QML not found: {PORTAL_DIALOG_QML}")
        try:
            os.unlink(result_path)
        except FileNotFoundError:
            pass
        return {"accepted": False}

    child = None
    output_buffer = ""
    qslog_path = None
    try:
        try:
            child = subprocess.Popen(
                [QS_BIN, "-p", PORTAL_DIALOG_QML],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                env=env,
                start_new_session=True,
                text=True,
                bufsize=1,
            )
        except OSError as exc:
            log_debug(f"Failed to start portal dialog: {exc}")
            return {"accepted": False}
        selector = selectors.DefaultSelector()
        if child.stdout is not None:
            selector.register(child.stdout, selectors.EVENT_READ)
        deadline = time.monotonic() + 300
        while time.monotonic() < deadline:
            if qslog_path is None:
                qslog_path = resolve_qslog_path(child.pid, output_buffer)

            if os.path.exists(result_path) and os.path.getsize(result_path) > 0:
                with open(result_path, "r", encoding="utf-8") as handle:
                    return json.load(handle)

            qslog_result = read_qslog_result(qslog_path)
            if qslog_result is not None:
                return qslog_result

            events = selector.select(timeout=0.25)
            for key, _mask in events:
                chunk = key.fileobj.readline()
                if not chunk:
                    continue
                output_buffer += chunk
                if qslog_path is None:
                    qslog_path = resolve_qslog_path(child.pid, output_buffer)
                result = parse_result_from_text(output_buffer)
                if result is not None:
                    if child.poll() is None:
                        child.terminate()
                    return result

            exit_code = child.poll()
            if exit_code is not None:
                if qslog_path is None:
                    qslog_path = resolve_qslog_path(child.pid, output_buffer)
                for _ in range(40):
                    if os.path.exists(result_path) and os.path.getsize(result_path) > 0:
                        with open(result_path, "r", encoding="utf-8") as handle:
                            return json.load(handle)
                    qslog_result = read_qslog_result(qslog_path)
                    if qslog_result is not None:
                        return qslog_result
                    time.sleep(0.05)
                if child.stdout is not None:
                    remainder = child.stdout.read() or ""
                    output_buffer += remainder
                result = parse_result_from_text(output_buffer)
                if result is not None:
                    return result
                log_debug(f"qs exited before result exit_code={exit_code}")
                break
    finally:
        if child and child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=2)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=2)
        try:
            os.unlink(result_path)
        except FileNotFoundError:
            pass

    return {"accepted": False}


def build_results_from_selection(selection):
    files = selection.get("files") or []
    uris = []
    for item in files:
        if not isinstance(item, dict):
            continue
        path = str(item.get("filePath", "")).strip()
        if path:
            uris.append(file_uri(path))

    if not uris:
        uri = file_uri(selection["filePath"])
        uris.append(uri)

    return dbus.Dictionary({"uris": dbus.Array(uris, signature="s")}, signature="sv")


def build_results_for_save_files(folder_selection, files):
    folder = folder_selection["filePath"]
    uris = []
    for raw_name in files:
        name = sanitize_save_file_name(raw_name)
        if not name:
            continue
        uris.append(file_uri(os.path.join(folder, name)))

    return dbus.Dictionary({"uris": dbus.Array(uris, signature="s")}, signature="sv")


class AstreaFileChooser(dbus.service.Object):
    def __init__(self, bus):
        self.bus_name = dbus.service.BusName(
            BUS_NAME,
            bus=bus,
            allow_replacement=False,
            replace_existing=False,
            do_not_queue=True,
        )
        super().__init__(self.bus_name, OBJECT_PATH)

    @dbus.service.method(INTERFACE, in_signature="osssa{sv}", out_signature="ua{sv}")
    def OpenFile(self, handle, app_id, parent_window, title, options):
        try:
            log_debug(
                f"OpenFile handle={handle!r} app_id={app_id!r} parent_window={parent_window!r} "
                f"title={title!r} option_keys={sorted(str(key) for key in options.keys())}"
            )
            directory = option_to_bool(options.get("directory", False))
            has_file_filters = filters_include_file_types(options.get("filters"))
            mode = "select_folder" if directory and not has_file_filters else "open_file"
            log_debug(
                f"OpenFile resolved mode={mode!r} directory={directory!r} "
                f"has_file_filters={has_file_filters!r}"
            )
            selection = run_dialog(mode, title, options)
            if not selection.get("accepted"):
                return RESPONSE_CANCELLED, dbus.Dictionary({}, signature="sv")
            return RESPONSE_SUCCESS, build_results_from_selection(selection)
        except Exception:
            log_debug("OpenFile exception:\n" + traceback.format_exc())
            return RESPONSE_CANCELLED, dbus.Dictionary({}, signature="sv")

    @dbus.service.method(INTERFACE, in_signature="osssa{sv}", out_signature="ua{sv}")
    def SaveFile(self, handle, app_id, parent_window, title, options):
        try:
            log_debug(
                f"SaveFile handle={handle!r} app_id={app_id!r} parent_window={parent_window!r} "
                f"title={title!r} option_keys={sorted(str(key) for key in options.keys())}"
            )
            selection = run_dialog("save_file", title, options)
            if not selection.get("accepted"):
                return RESPONSE_CANCELLED, dbus.Dictionary({}, signature="sv")
            return RESPONSE_SUCCESS, build_results_from_selection(selection)
        except Exception:
            log_debug("SaveFile exception:\n" + traceback.format_exc())
            return RESPONSE_CANCELLED, dbus.Dictionary({}, signature="sv")

    @dbus.service.method(INTERFACE, in_signature="osssa{sv}", out_signature="ua{sv}")
    def SaveFiles(self, handle, app_id, parent_window, title, options):
        try:
            log_debug(
                f"SaveFiles handle={handle!r} app_id={app_id!r} parent_window={parent_window!r} "
                f"title={title!r} option_keys={sorted(str(key) for key in options.keys())}"
            )
            selection = run_dialog("select_folder", title, options)
            if not selection.get("accepted"):
                return RESPONSE_CANCELLED, dbus.Dictionary({}, signature="sv")
            return RESPONSE_SUCCESS, build_results_for_save_files(selection, options.get("files", []))
        except Exception:
            log_debug("SaveFiles exception:\n" + traceback.format_exc())
            return RESPONSE_CANCELLED, dbus.Dictionary({}, signature="sv")


def main():
    DBusGMainLoop(set_as_default=True)
    bus = get_session_bus()
    if name_has_owner(bus, BUS_NAME):
        return
    AstreaFileChooser(bus)
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
