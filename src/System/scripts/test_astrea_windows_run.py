#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import os
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("astrea-windows-run")
LOADER = importlib.machinery.SourceFileLoader("astrea_windows_run", str(SCRIPT))
SPEC = importlib.util.spec_from_loader("astrea_windows_run", LOADER)
runner = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(runner)


class AstreaWindowsRunTests(unittest.TestCase):
    def test_dry_run_uses_proton_ge_and_folder_prefix(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            home = root / "home"
            steam = home / ".local/share/Steam"
            proton = steam / "compatibilitytools.d/Proton-GE Latest/proton"
            app_dir = home / "Downloads/App"
            target = app_dir / "setup.exe"
            proton.parent.mkdir(parents=True)
            app_dir.mkdir(parents=True)
            proton.write_text("#!/bin/sh\n", encoding="utf-8")
            proton.chmod(0o755)
            target.write_bytes(b"MZ")

            old_env = os.environ.copy()
            try:
                os.environ["HOME"] = str(home)
                os.environ["XDG_STATE_HOME"] = str(home / ".local/state")
                os.environ["ASTREA_STEAM_ROOT"] = str(steam)
                os.environ["PATH"] = "/usr/bin:/bin"

                payload = runner.run(str(target), dry_run=True)
            finally:
                os.environ.clear()
                os.environ.update(old_env)

            self.assertTrue(payload["ok"])
            self.assertEqual(payload["runner"], "proton-ge")
            self.assertEqual(payload["command"][:2], [str(proton), "run"])
            self.assertEqual(payload["command"][-1], str(target.resolve()))
            self.assertIn("/windows-prefixes/by-folder/", payload["prefix"])
            self.assertTrue(payload["wine_prefix"].endswith("/proton/pfx"))

    def test_rejects_non_windows_files(self):
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "notes.txt"
            target.write_text("hello", encoding="utf-8")

            payload = runner.run(str(target), dry_run=True)

            self.assertFalse(payload["ok"])
            self.assertIn("unsupported", payload["error"])


if __name__ == "__main__":
    unittest.main()
