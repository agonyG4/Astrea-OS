#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path

from PIL import Image


MODULE_PATH = Path(__file__).with_name("blur_lockscreen.py")
spec = importlib.util.spec_from_file_location("blur_lockscreen_under_test", MODULE_PATH)
blur_lockscreen = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(blur_lockscreen)


class BlurLockscreenTests(unittest.TestCase):
    def test_generate_blur_creates_blurred_file_and_output_symlink(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            source = root / "wallpaper.png"
            output = root / "active-blur.jpg"
            Image.new("RGB", (16, 16), (20, 80, 160)).save(source)

            blurred = blur_lockscreen.generate_blur(source, output)

            self.assertEqual(blurred, root / "blurred.jpg")
            self.assertTrue(blurred.exists())
            self.assertTrue(output.is_symlink())
            self.assertEqual(output.resolve(), blurred)

    def test_generate_blur_rejects_missing_input(self):
        with tempfile.TemporaryDirectory() as td:
            with self.assertRaises(FileNotFoundError):
                blur_lockscreen.generate_blur(Path(td) / "missing.jpg")


if __name__ == "__main__":
    unittest.main()
