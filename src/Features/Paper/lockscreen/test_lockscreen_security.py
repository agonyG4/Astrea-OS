#!/usr/bin/env python3
from pathlib import Path
import re
import unittest


LOCKSCREEN = Path(__file__).with_name("Lockscreen.qml")


class LockscreenSecurityTests(unittest.TestCase):
    def setUp(self):
        self.source = LOCKSCREEN.read_text()

    def test_lockscreen_inhibits_compositor_shortcuts(self):
        self.assertIn("ShortcutInhibitor", self.source)
        self.assertRegex(self.source, r"ShortcutInhibitor\s*\{[^}]*enabled:\s*true")
        self.assertRegex(self.source, r"ShortcutInhibitor\s*\{[^}]*window:\s*lockWindow")


    def test_auth_helper_path_uses_astrea_root_fallback(self):
        self.assertIn('Quickshell.env("ASTREA_ROOT") || (homeDir + "/.local/share/Astrea")', self.source)
        self.assertIn('readonly property string authHelperPath: astreaRoot + "/System/auth/auth_helper"', self.source)
        self.assertIn('command: [root.authHelperPath, root.currentUser]', self.source)

    def test_no_meta_key_unlock_bypass(self):
        self.assertNotIn("Qt.MetaModifier", self.source)
        self.assertNotRegex(
            self.source,
            r"Keys\.onPressed:[\s\S]*?unlockAnimation\.start\(\)",
        )

    def test_password_is_not_passed_in_process_arguments(self):
        self.assertNotRegex(
            self.source,
            r"command:\s*\[[^\]]*passwordField\.text[^\]]*\]",
        )
        self.assertIn("stdinEnabled: true", self.source)
        self.assertIn('authProcess.write(passwordField.text + "\\n")', self.source)


if __name__ == "__main__":
    unittest.main()
