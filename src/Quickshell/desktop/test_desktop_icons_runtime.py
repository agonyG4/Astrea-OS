#!/usr/bin/env python3
from pathlib import Path
import unittest

DESKTOP_ICONS = Path(__file__).with_name("DesktopIcons.qml")


class DesktopIconsRuntimeTests(unittest.TestCase):
    def test_refresh_uses_stdout_json_without_write_side_effects(self):
        source = DESKTOP_ICONS.read_text()
        self.assertIn('appLoadProcess.command = ["python3", scriptPath, "--json"]', source)
        self.assertNotIn('--write"]', source)


if __name__ == "__main__":
    unittest.main()
