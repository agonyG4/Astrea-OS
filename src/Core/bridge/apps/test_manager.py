#!/usr/bin/env python3

import tempfile
import unittest
from pathlib import Path

import manager


class ManagerActionsTest(unittest.TestCase):
    def test_settings_desktop_file_is_protected(self):
        self.assertTrue(manager.is_protected_app({"id": "astrea-settings.desktop"}))
        self.assertFalse(manager.is_protected_app({"id": "astrea-weather.desktop"}))

    def test_create_desktop_shortcut_copies_entry_to_desktop_dir(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "astrea-weather.desktop"
            desktop_dir = Path(tmp) / "Desktop"
            source.write_text("[Desktop Entry]\nType=Application\nName=Weather\n", encoding="utf-8")

            result = manager.create_desktop_shortcut(source, desktop_dir)

            target = desktop_dir / "astrea-weather.desktop"
            self.assertEqual(result["target"], str(target))
            self.assertTrue(target.exists())
            self.assertIn("Name=Weather", target.read_text(encoding="utf-8"))
            self.assertTrue(target.stat().st_mode & 0o111)


if __name__ == "__main__":
    unittest.main()
