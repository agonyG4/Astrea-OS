#!/usr/bin/env python3
from __future__ import annotations

import os
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BIN = ROOT / "bin"


class AstreaBinLauncherTests(unittest.TestCase):
    def test_user_facing_launchers_are_in_runtime_bin(self) -> None:
        expected = {
            "astrea-explorer-open",
            "astrea-settings-open",
            "astrea-weather-open",
            "astrea-media-open",
            "astrea-wallpapers-open",
            "astrea-shell",
            "astrea-shell-rolling",
            "astrea-gaming",
            "astrea-gamescope-session",
            "astrea-spatialctl",
        }

        missing = sorted(name for name in expected if not (BIN / name).is_file())
        self.assertEqual([], missing)

        not_executable = sorted(name for name in expected if not os.access(BIN / name, os.X_OK))
        self.assertEqual([], not_executable)

    def test_settings_launcher_is_not_tied_to_local_bin_copy(self) -> None:
        source = (BIN / "astrea-settings-open").read_text(encoding="utf-8")

        self.assertIn("script_path=", source)
        self.assertIn("${script_path@Q}", source)
        self.assertNotIn("/.local/bin/astrea-settings-open", source)

    def test_topbar_uses_runtime_settings_launcher(self) -> None:
        source = (ROOT / "Quickshell/bar/ui/components/astrea/AstreaPopup.qml").read_text(encoding="utf-8")

        self.assertIn('root.astreaRoot + "/bin/astrea-settings-open"', source)
        self.assertNotIn('Quickshell.env("HOME") + "/.local/bin/astrea-settings-open"', source)

    def test_auth_helper_has_runtime_installer(self) -> None:
        installer = ROOT / "System/services/install-auth-helper.sh"
        source = installer.read_text(encoding="utf-8")

        self.assertTrue(os.access(installer, os.X_OK))
        self.assertIn("System/auth/auth_helper.c", source)
        self.assertIn("/usr/local/libexec/astrea-auth-helper", source)


if __name__ == "__main__":
    unittest.main()
