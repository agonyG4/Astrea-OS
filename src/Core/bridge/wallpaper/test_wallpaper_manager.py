#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import os
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image


MODULE_PATH = Path(__file__).with_name("wallpaper_manager.py")


def load_manager(root: Path):
    os.environ["ASTREA_ROOT"] = str(root / "Astrea")
    os.environ["XDG_CONFIG_HOME"] = str(root / "config")
    os.environ["XDG_DATA_HOME"] = str(root / "data")
    sys.path.insert(0, str(MODULE_PATH.parent))
    spec = importlib.util.spec_from_file_location("wallpaper_manager_under_test", MODULE_PATH)
    manager = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(manager)
    return manager


class WallpaperManagerTests(unittest.TestCase):
    def test_lockscreen_state_repairs_broken_blur_link(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            manager = load_manager(root)

            source_dir = manager.USER_WALLPAPER_DIR / "Persona_5"
            source_dir.mkdir(parents=True)
            source = source_dir / "wallpaper.jpg"
            Image.new("RGB", (32, 32), (30, 70, 140)).save(source)

            state_dir = manager.STATE_DIRS["lockscreen"]
            state_dir.mkdir(parents=True)
            manager.relink(state_dir / "wallpaper.jpg", source)
            manager.relink(state_dir / "blurred.jpg", root / "old-store" / "Persona_5" / "blurred.jpg")

            manager.state_payload("lockscreen")

            blur_link = state_dir / "blurred.jpg"
            self.assertTrue(blur_link.is_symlink())
            self.assertTrue(blur_link.exists())
            self.assertEqual(blur_link.resolve(), source_dir / "blurred.jpg")

    def test_state_payload_reports_active_source_and_blur_health(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            manager = load_manager(root)

            source_dir = manager.USER_WALLPAPER_DIR / "Coffe"
            source_dir.mkdir(parents=True)
            source = source_dir / "wallpaper.jpg"
            blurred = source_dir / "blurred.jpg"
            Image.new("RGB", (32, 32), (110, 70, 40)).save(source)
            Image.new("RGB", (32, 32), (90, 55, 35)).save(blurred)

            state_dir = manager.STATE_DIRS["wallpaper"]
            state_dir.mkdir(parents=True)
            manager.relink(state_dir / "wallpaper.jpg", source)

            payload = manager.state_payload("wallpaper")

            self.assertEqual(payload["activeSourcePath"], str(source))
            self.assertTrue(payload["activeSourceExists"])
            self.assertEqual(payload["activeBlurPath"], str(blurred))
            self.assertTrue(payload["activeBlurExists"])


if __name__ == "__main__":
    unittest.main()
