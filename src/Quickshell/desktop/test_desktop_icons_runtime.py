#!/usr/bin/env python3
from pathlib import Path
import unittest

DESKTOP_ICONS = Path(__file__).with_name("DesktopIcons.qml")
DESKTOP_LOADER = Path(__file__).with_name("DesktopIconsLoader.qml")


class DesktopIconsRuntimeTests(unittest.TestCase):
    def test_refresh_uses_stdout_json_without_write_side_effects(self):
        source = DESKTOP_ICONS.read_text()
        self.assertIn('appLoadProcess.command = ["python3", scriptPath, "--json"]', source)
        self.assertNotIn('--write"]', source)

    def test_loader_skips_config_process_when_component_disabled(self):
        source = DESKTOP_LOADER.read_text()
        self.assertIn("running: root.componentEnabled", source)
        self.assertIn("onComponentEnabledChanged", source)


if __name__ == "__main__":
    unittest.main()
