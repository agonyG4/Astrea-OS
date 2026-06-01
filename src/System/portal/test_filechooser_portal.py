#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import types
import unittest
from pathlib import Path


PORTAL = Path(__file__).with_name("astrea_filechooser_portal.py")
TEST_DESKTOP = "/home/astrea/Desktop"


def load_portal_module():
    dbus = types.ModuleType("dbus")
    class FakeArray(list):
        def __init__(self, values=(), signature=None):
            super().__init__(values)
            self.signature = signature
    class FakeDictionary(dict):
        def __init__(self, values=(), signature=None):
            super().__init__(values)
            self.signature = signature
    dbus.UInt32 = int
    dbus.Array = FakeArray
    dbus.Dictionary = FakeDictionary
    dbus.SessionBus = lambda: None

    service = types.ModuleType("dbus.service")
    service.Object = object
    service.BusName = lambda *args, **kwargs: object()
    service.method = lambda *args, **kwargs: (lambda fn: fn)
    dbus.service = service

    mainloop = types.ModuleType("dbus.mainloop")
    glib = types.ModuleType("dbus.mainloop.glib")
    glib.DBusGMainLoop = lambda *args, **kwargs: None

    gi = types.ModuleType("gi")
    repository = types.ModuleType("gi.repository")
    repository.GLib = types.SimpleNamespace(MainLoop=lambda: types.SimpleNamespace(run=lambda: None))

    originals = {name: sys.modules.get(name) for name in (
        "dbus", "dbus.service", "dbus.mainloop", "dbus.mainloop.glib", "gi", "gi.repository"
    )}
    sys.modules.update({
        "dbus": dbus,
        "dbus.service": service,
        "dbus.mainloop": mainloop,
        "dbus.mainloop.glib": glib,
        "gi": gi,
        "gi.repository": repository,
    })
    try:
        spec = importlib.util.spec_from_file_location("astrea_filechooser_portal_under_test", PORTAL)
        module = importlib.util.module_from_spec(spec)
        assert spec and spec.loader
        spec.loader.exec_module(module)
        return module
    finally:
        for name, value in originals.items():
            if value is None:
                sys.modules.pop(name, None)
            else:
                sys.modules[name] = value


class FileChooserPortalTests(unittest.TestCase):
    def test_save_files_rejects_path_traversal_names(self):
        portal = load_portal_module()
        with self.assertRaises(ValueError):
            portal.build_results_for_save_files({"filePath": TEST_DESKTOP}, ["../escape.txt"])

    def test_save_files_accepts_plain_file_names(self):
        portal = load_portal_module()
        result = portal.build_results_for_save_files({"filePath": TEST_DESKTOP}, ["note.txt"])
        self.assertEqual(list(result["uris"]), ["file:///home/astrea/Desktop/note.txt"])

    def test_open_file_result_accepts_multiple_files(self):
        portal = load_portal_module()
        result = portal.build_results_from_selection({
            "accepted": True,
            "files": [
                {"filePath": "/home/astrea/Desktop/a file.txt"},
                {"filePath": "/home/astrea/Desktop/b.txt"},
            ],
        })
        self.assertEqual(list(result["uris"]), [
            "file:///home/astrea/Desktop/a%20file.txt",
            "file:///home/astrea/Desktop/b.txt",
        ])


if __name__ == "__main__":
    unittest.main()
