#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).with_name("user_profile.py")
spec = importlib.util.spec_from_file_location("user_profile_under_test", MODULE_PATH)
profile = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(profile)


class UserProfileValidationTests(unittest.TestCase):
    def test_rejects_unsafe_user_names_before_privileged_writes(self):
        for value in ("../root", "agony/admin", "bad\nuser", ""):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    profile.validate_user(value)

    def test_write_display_name_uses_validated_accounts_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with mock.patch.object(profile, "ACCOUNTS_USERS_DIR", root):
                profile.write_display_name("agony", "Astrea User")

            self.assertTrue((root / "agony").is_file())
            self.assertFalse((root / "root").is_file())

    def test_write_sddm_autologin_rejects_newline_session(self):
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(profile, "ASTREA_SDDM_AUTOLOGIN", Path(tmp) / "autologin.conf"):
                with self.assertRaises(ValueError):
                    profile.write_sddm_autologin("agony", True, "hyprland.desktop\nUser=root")


if __name__ == "__main__":
    unittest.main()
