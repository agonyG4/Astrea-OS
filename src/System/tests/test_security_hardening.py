#!/usr/bin/env python3
from pathlib import Path
import re
import unittest


SYSTEM_ROOT = Path(__file__).resolve().parents[1]
ASTREA_ROOT = SYSTEM_ROOT.parent


class SecurityHardeningTests(unittest.TestCase):
    def test_archive_password_is_not_passed_in_argv(self):
        source = (ASTREA_ROOT / "Apps/Explorer/state/FileOperationsState.qml").read_text()
        self.assertNotIn('"--password"', source)
        self.assertIn("stdinEnabled: true", source)
        self.assertIn("archiveExtractProcess.write", source)

    def test_user_profile_does_not_pkexec_user_writable_self(self):
        source = (ASTREA_ROOT / "Core/bridge/system/user_profile.py").read_text()
        self.assertNotRegex(source, r"pkexec[^\n]*Path\(__file__\)")
        self.assertIn('PROFILE_HELPER = Path("/usr/local/libexec/astrea-user-profile-helper")', source)

    def test_profile_image_helper_validates_target_user_and_paths(self):
        source = (SYSTEM_ROOT / "services/install-profile-image-helper.sh").read_text()
        self.assertIn("case \"$user_name\" in", source)
        self.assertIn("home_real=", source)
        self.assertIn("src_real=", source)
        self.assertRegex(source, r"exit\s+64")

    def test_fetch_art_limits_download_size_and_scheme(self):
        source = (ASTREA_ROOT / "Quickshell/island/scripts/fetch_art.py").read_text()
        self.assertIn("MAX_ART_BYTES", source)
        self.assertIn("ALLOWED_SCHEMES", source)
        self.assertIn("downloaded += len(chunk)", source)
        self.assertIn("artwork too large", source)

    def test_latencyd_has_no_privileged_shell_fallback(self):
        source = (SYSTEM_ROOT / "services/astrea_latencyd.py").read_text()
        self.assertNotIn('["sudo", "-n", "sh", "-c", command]', source)
        self.assertNotIn('["pkexec", "sh", "-c", command]', source)


if __name__ == "__main__":
    unittest.main()
