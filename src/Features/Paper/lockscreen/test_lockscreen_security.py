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


    def test_auth_helper_uses_system_installed_path(self):
        self.assertIn('Quickshell.env("ASTREA_ROOT") || (homeDir + "/.local/share/Astrea")', self.source)
        self.assertIn('readonly property string authHelperPath: "/usr/local/libexec/astrea-auth-helper"', self.source)
        self.assertNotIn('readonly property string authHelperPath: astreaRoot + "/System/auth/auth_helper"', self.source)
        self.assertIn('command: [root.authHelperPath, root.currentUser]', self.source)

    def test_12_hour_clock_does_not_render_meridiem_suffix(self):
        match = re.search(r"function _formatLockTime\(now\) \{([\s\S]*?)\n    \}", self.source)
        self.assertIsNotNone(match)
        body = match.group(1)

        self.assertIn('root.timeFormat === "12h"', body)
        self.assertIn("(h % 12 || 12)", body)
        self.assertNotRegex(body, r'"AM"|"PM"')

    def test_lockscreen_keeps_baseline_date_layout(self):
        self.assertIn("Qt.formatDate(new Date(), \"dddd, dd 'de' MMMM\")", self.source)
        self.assertNotIn("_weekdaysLong", self.source)
        self.assertNotIn("_monthsLong", self.source)

    def test_click_prompt_is_visible_and_click_opens_password(self):
        self.assertIn("onClicked: mainRect.showPasswordPrompt()", self.source)
        self.assertIn("click_or_press_space_to_unlock", self.source)
        self.assertIn("Clique ou pressione espaço para desbloquear", self.source)

    def test_lockscreen_uses_existing_i18n_message_contract(self):
        self.assertNotIn("AstreaI18n.I18n.tr(", self.source)
        self.assertIn('AstreaI18n.I18n.messages["features.paper.lockscreen.lockscreen.text.click_or_press_space_to_unlock"]', self.source)
        self.assertIn('AstreaI18n.I18n.messages["features.paper.lockscreen.lockscreen.text.senha"]', self.source)

    def test_time_format_still_reads_region_settings(self):
        self.assertIn('readonly property string regionScript: astreaRoot + "/Core/bridge/system/region.py"', self.source)
        self.assertIn('readonly property string regionSettingsPath: homeDir + "/.config/AstreaOS/system/settings.json"', self.source)
        self.assertIn('regionProc.command = ["python3", root.regionScript, "get"]', self.source)
        self.assertIn("_applyRegionPayload", self.source)

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
        self.assertNotIn('authProcess.write(passwordField.text + "\\n")', self.source)
        self.assertIn('property string pendingPassword: ""', self.source)
        self.assertIn('authProcess.write(authProcess.pendingPassword + "\\n")', self.source)
        self.assertRegex(self.source, r"authProcess\.pendingPassword\s*=\s*\"\"")
        self.assertRegex(self.source, r"authProcess\.pendingPassword\s*=\s*text")
        self.assertRegex(self.source, r"text\s*=\s*\"\"[\s\S]*authProcess\.running\s*=\s*true")


if __name__ == "__main__":
    unittest.main()
