#!/usr/bin/env python3

import tempfile
import unittest
from pathlib import Path

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


if __name__ == "__main__":
    unittest.main()
