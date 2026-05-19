#!/usr/bin/env python3

import tempfile
import unittest
from pathlib import Path

import app_index


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
