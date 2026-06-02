#!/usr/bin/env python3

import tempfile
import unittest
from pathlib import Path
from unittest import mock

import importlib.util
import sys

APP_INDEX_PATH = Path(__file__).with_name("app_index.py")
spec = importlib.util.spec_from_file_location("app_index_under_test", APP_INDEX_PATH)
app_index = importlib.util.module_from_spec(spec)
sys.modules["app_index_under_test"] = app_index
assert spec and spec.loader
spec.loader.exec_module(app_index)


class FolderCreationTests(unittest.TestCase):
    def test_next_folder_path_uses_incremental_names(self):
        with tempfile.TemporaryDirectory() as tmp:
            desktop = Path(tmp)
            (desktop / "Nova Pasta").mkdir()
            (desktop / "Nova Pasta 2").mkdir()

            self.assertEqual(
                app_index.next_folder_path(desktop).name,
                "Nova Pasta 3",
            )


class IconInstallTests(unittest.TestCase):
    def test_install_png_icon_does_not_leave_partial_target_on_copy_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source.png"
            source.write_bytes(b"png")
            target = root / "icon.png"

            def failing_copy(_source, dest):
                Path(dest).write_bytes(b"partial")
                raise OSError("copy failed")

            with mock.patch.object(app_index, "hicolor_icon_path", return_value=target), \
                    mock.patch.object(app_index.shutil, "copyfile", side_effect=failing_copy):
                self.assertFalse(app_index.install_png_icon("123", source, 256))

            self.assertFalse(target.exists())


if __name__ == "__main__":
    unittest.main()
