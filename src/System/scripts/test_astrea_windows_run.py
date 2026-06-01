#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import json
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
    def _write_executable(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/bin/sh\n", encoding="utf-8")
        path.chmod(0o755)

    def _write_pe(self, path: Path, machine: int = 0x014c) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        data = bytearray(160)
        data[0:2] = b"MZ"
        data[0x3c:0x40] = (0x80).to_bytes(4, "little")
        data[0x80:0x84] = b"PE\0\0"
        data[0x84:0x86] = machine.to_bytes(2, "little")
        path.write_bytes(bytes(data))

    def test_dry_run_uses_proton_ge_and_shared_prefix(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            home = root / "home"
            steam = home / ".local/share/Steam"
            proton = steam / "compatibilitytools.d/Proton-GE Latest/proton"
            app_dir = home / "Downloads/App"
            target = app_dir / "setup.exe"
            other_app_dir = home / "Documents/OtherApp"
            other_target = other_app_dir / "setup.exe"
            proton.parent.mkdir(parents=True)
            app_dir.mkdir(parents=True)
            other_app_dir.mkdir(parents=True)
            proton.write_text("#!/bin/sh\n", encoding="utf-8")
            proton.chmod(0o755)
            target.write_bytes(b"MZ")
            other_target.write_bytes(b"MZ")

            old_env = os.environ.copy()
            try:
                os.environ["HOME"] = str(home)
                os.environ["XDG_DATA_HOME"] = str(home / ".local/share")
                os.environ["XDG_STATE_HOME"] = str(home / ".local/state")
                os.environ["ASTREA_STEAM_ROOT"] = str(steam)
                os.environ["PATH"] = ""

                payload = runner.run(str(target), dry_run=True)
                other_payload = runner.run(str(other_target), dry_run=True)
            finally:
                os.environ.clear()
                os.environ.update(old_env)

            self.assertTrue(payload["ok"])
            self.assertEqual(payload["runner"], "proton-ge")
            self.assertEqual(payload["command"][:2], [str(proton), "run"])
            self.assertEqual(payload["command"][-1], str(target.resolve()))
            self.assertEqual(payload["prefix"], other_payload["prefix"])
            self.assertIn("/.local/share/AstreaOS/windows-prefixes/shared/proton", payload["prefix"])
            self.assertTrue(payload["wine_prefix"].endswith("/AstreaOS/windows-prefixes/shared/proton/pfx"))
            self.assertIn("/.local/state/AstreaOS/windows-prefixes/logs/", payload["log"])
            self.assertNotEqual(payload["log"], other_payload["log"])

    def test_proton_ge_launch_sets_non_steam_umu_identity(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            home = root / "home"
            steam = home / ".local/share/Steam"
            proton = steam / "compatibilitytools.d/Proton-GE Latest/proton"
            target = home / "Games/App/app.exe"
            proton.parent.mkdir(parents=True)
            proton.write_text("#!/bin/sh\n", encoding="utf-8")
            proton.chmod(0o755)
            self._write_pe(target, 0x8664)

            old_env = os.environ.copy()
            try:
                os.environ["HOME"] = str(home)
                os.environ["XDG_DATA_HOME"] = str(home / ".local/share")
                os.environ["XDG_STATE_HOME"] = str(home / ".local/state")
                os.environ["ASTREA_STEAM_ROOT"] = str(steam)
                os.environ["PATH"] = ""

                plan = runner.build_launch(target)
            finally:
                os.environ.clear()
                os.environ.update(old_env)

            command, env = plan[0], plan[1]
            self.assertEqual(command[:2], [str(proton), "run"])
            self.assertTrue(env.get("UMU_ID", "").startswith("astrea-"))
            self.assertEqual(env.get("GAMEID"), env.get("UMU_ID"))
            self.assertEqual(env.get("STORE"), "none")
            self.assertEqual(env.get("PROTONPATH"), str(proton.parent))

    def test_proton_ge_launch_exposes_steam_runtime_interface(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            home = root / "home"
            steam = home / ".local/share/Steam"
            proton = steam / "compatibilitytools.d/Proton-GE Latest/proton"
            runtime_bin = steam / "steamapps/common/SteamLinuxRuntime_sniper/pressure-vessel/bin"
            runtime_iface = runtime_bin / "steam-runtime-launcher-interface-0"
            target = home / "Games/App/app.exe"
            proton.parent.mkdir(parents=True)
            proton.write_text("#!/bin/sh\n", encoding="utf-8")
            proton.chmod(0o755)
            self._write_executable(runtime_iface)
            self._write_pe(target, 0x8664)

            old_env = os.environ.copy()
            try:
                os.environ["HOME"] = str(home)
                os.environ["XDG_DATA_HOME"] = str(home / ".local/share")
                os.environ["XDG_STATE_HOME"] = str(home / ".local/state")
                os.environ["ASTREA_STEAM_ROOT"] = str(steam)
                os.environ["PATH"] = ""

                plan = runner.build_launch(target)
            finally:
                os.environ.clear()
                os.environ.update(old_env)

            env = plan[1]
            self.assertEqual(env.get("PATH", "").split(os.pathsep)[0], str(runtime_bin))

    def test_prefers_lutris_umu_run_when_available_outside_path(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            home = root / "home"
            steam = home / ".local/share/Steam"
            proton = steam / "compatibilitytools.d/GE-Proton10-34/proton"
            umu_run = home / ".local/share/lutris/runtime/umu/umu-run"
            target = home / "Games/App/app.exe"
            proton.parent.mkdir(parents=True)
            proton.write_text("#!/bin/sh\n", encoding="utf-8")
            proton.chmod(0o755)
            self._write_executable(umu_run)
            self._write_pe(target, 0x8664)

            old_env = os.environ.copy()
            try:
                os.environ["HOME"] = str(home)
                os.environ["XDG_DATA_HOME"] = str(home / ".local/share")
                os.environ["XDG_STATE_HOME"] = str(home / ".local/state")
                os.environ["ASTREA_STEAM_ROOT"] = str(steam)
                os.environ["PATH"] = ""

                payload = runner.run(str(target), dry_run=True)
            finally:
                os.environ.clear()
                os.environ.update(old_env)

            self.assertTrue(payload["ok"])
            self.assertEqual(payload["runner"], "umu-proton-ge")
            self.assertEqual(payload["command"], [str(umu_run), str(target.resolve())])
            self.assertEqual(payload["protonpath"], str(proton.parent))
            self.assertTrue(payload["umu_id"].startswith("astrea-"))

    def test_umu_run_uses_proton_ge_latest_path_when_available(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            home = root / "home"
            steam = home / ".local/share/Steam"
            latest = steam / "compatibilitytools.d/Proton-GE Latest/proton"
            older_ge = steam / "compatibilitytools.d/GE-Proton10-34/proton"
            umu_run = home / ".local/share/lutris/runtime/umu/umu-run"
            target = home / "Games/App/app.exe"
            for proton in (latest, older_ge):
                proton.parent.mkdir(parents=True, exist_ok=True)
                proton.write_text("#!/bin/sh\n", encoding="utf-8")
                proton.chmod(0o755)
            self._write_executable(umu_run)
            self._write_pe(target, 0x8664)

            old_env = os.environ.copy()
            try:
                os.environ["HOME"] = str(home)
                os.environ["XDG_DATA_HOME"] = str(home / ".local/share")
                os.environ["XDG_STATE_HOME"] = str(home / ".local/state")
                os.environ["ASTREA_STEAM_ROOT"] = str(steam)
                os.environ["PATH"] = ""

                payload = runner.run(str(target), dry_run=True)
            finally:
                os.environ.clear()
                os.environ.update(old_env)

            self.assertTrue(payload["ok"])
            self.assertEqual(payload["runner"], "umu-proton-ge")
            self.assertEqual(payload["command"], [str(umu_run), str(target.resolve())])
            self.assertEqual(payload["protonpath"], str(latest.parent))

    def test_dry_run_skips_gamemode_for_32_bit_pe_without_lib32_gamemode(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            home = root / "home"
            bin_dir = root / "bin"
            lib32_dir = root / "empty-lib32"
            steam = home / ".local/share/Steam"
            proton = steam / "compatibilitytools.d/Proton-GE Latest/proton"
            target = home / "Games/App/app.exe"
            config_dir = home / ".config/AstreaOS/gaming"
            self._write_executable(bin_dir / "gamemoderun")
            lib32_dir.mkdir()
            proton.parent.mkdir(parents=True)
            proton.write_text("#!/bin/sh\n", encoding="utf-8")
            proton.chmod(0o755)
            self._write_pe(target, 0x014c)
            config_dir.mkdir(parents=True)
            (config_dir / "compatibility.json").write_text(json.dumps({
                "runner": "proton",
                "use_proton_profile": False,
                "gamemode": True,
                "mangohud": False,
                "gamescope": False,
            }), encoding="utf-8")

            old_env = os.environ.copy()
            try:
                os.environ["HOME"] = str(home)
                os.environ["XDG_CONFIG_HOME"] = str(home / ".config")
                os.environ["XDG_DATA_HOME"] = str(home / ".local/share")
                os.environ["XDG_STATE_HOME"] = str(home / ".local/state")
                os.environ["ASTREA_STEAM_ROOT"] = str(steam)
                os.environ["ASTREA_LIB32_DIRS"] = str(lib32_dir)
                os.environ["PATH"] = str(bin_dir)

                payload = runner.run(str(target), dry_run=True)
            finally:
                os.environ.clear()
                os.environ.update(old_env)

            self.assertTrue(payload["ok"])
            self.assertEqual(payload["machine"], "i386")
            self.assertEqual(payload["command"][:2], [str(proton), "run"])
            self.assertIn("32-bit", " ".join(payload["warnings"]))

    def test_run_reports_immediate_proton_failure(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            home = root / "home"
            steam = home / ".local/share/Steam"
            proton = steam / "compatibilitytools.d/Proton-GE Latest/proton"
            target = home / "Games/App/app.exe"
            config_dir = home / ".config/AstreaOS/gaming"
            proton.parent.mkdir(parents=True)
            proton.write_text("#!/bin/sh\nexit 33\n", encoding="utf-8")
            proton.chmod(0o755)
            self._write_pe(target, 0x8664)
            config_dir.mkdir(parents=True)
            (config_dir / "compatibility.json").write_text(json.dumps({
                "runner": "proton",
                "use_proton_profile": False,
                "gamemode": False,
                "mangohud": False,
                "gamescope": False,
            }), encoding="utf-8")

            old_env = os.environ.copy()
            try:
                os.environ["HOME"] = str(home)
                os.environ["XDG_CONFIG_HOME"] = str(home / ".config")
                os.environ["XDG_DATA_HOME"] = str(home / ".local/share")
                os.environ["XDG_STATE_HOME"] = str(home / ".local/state")
                os.environ["ASTREA_STEAM_ROOT"] = str(steam)
                os.environ["ASTREA_WINDOWS_STARTUP_WAIT_MS"] = "500"
                os.environ["PATH"] = ""

                payload = runner.run(str(target), dry_run=False)
            finally:
                os.environ.clear()
                os.environ.update(old_env)

            self.assertFalse(payload["ok"])
            self.assertEqual(payload["exit_code"], 33)
            self.assertIn("exited during startup", payload["error"])

    def test_rejects_non_windows_files(self):
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "notes.txt"
            target.write_text("hello", encoding="utf-8")

            payload = runner.run(str(target), dry_run=True)

            self.assertFalse(payload["ok"])
            self.assertIn("unsupported", payload["error"])

    def test_dry_run_can_use_wine_runner_from_compatibility_config(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            home = root / "home"
            bin_dir = root / "bin"
            target = home / "Downloads/App/setup.exe"
            config_dir = home / ".config/AstreaOS/gaming"
            wine = bin_dir / "wine"
            self._write_executable(wine)
            target.parent.mkdir(parents=True)
            target.write_bytes(b"MZ")
            config_dir.mkdir(parents=True)
            (config_dir / "compatibility.json").write_text(json.dumps({
                "runner": "wine",
                "use_proton_profile": False,
                "gamemode": False,
                "mangohud": False,
                "gamescope": False,
            }), encoding="utf-8")

            old_env = os.environ.copy()
            try:
                os.environ["HOME"] = str(home)
                os.environ["XDG_CONFIG_HOME"] = str(home / ".config")
                os.environ["XDG_DATA_HOME"] = str(home / ".local/share")
                os.environ["XDG_STATE_HOME"] = str(home / ".local/state")
                os.environ["PATH"] = str(bin_dir)

                payload = runner.run(str(target), dry_run=True)
            finally:
                os.environ.clear()
                os.environ.update(old_env)

            self.assertTrue(payload["ok"])
            self.assertEqual(payload["runner"], "wine")
            self.assertEqual(payload["command"], [str(wine), str(target.resolve())])

    def test_dry_run_wraps_proton_with_gamescope_and_gamemode(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            home = root / "home"
            bin_dir = root / "bin"
            steam = home / ".local/share/Steam"
            proton = steam / "compatibilitytools.d/Proton-GE Latest/proton"
            target = home / "Games/App/app.exe"
            config_dir = home / ".config/AstreaOS/gaming"
            for name in ("gamemoderun", "gamescope"):
                self._write_executable(bin_dir / name)
            proton.parent.mkdir(parents=True)
            proton.write_text("#!/bin/sh\n", encoding="utf-8")
            proton.chmod(0o755)
            target.parent.mkdir(parents=True)
            target.write_bytes(b"MZ")
            config_dir.mkdir(parents=True)
            (config_dir / "compatibility.json").write_text(json.dumps({
                "runner": "proton",
                "use_proton_profile": False,
                "gamemode": True,
                "mangohud": True,
                "gamescope": True,
            }), encoding="utf-8")
            (config_dir / "proton.json").write_text(json.dumps({
                "use_gamescope_profile": False,
                "gamescope_width": 1600,
                "gamescope_height": 900,
                "gamescope_refresh": 75,
                "gamescope_fullscreen": True,
            }), encoding="utf-8")

            old_env = os.environ.copy()
            try:
                os.environ["HOME"] = str(home)
                os.environ["XDG_CONFIG_HOME"] = str(home / ".config")
                os.environ["XDG_DATA_HOME"] = str(home / ".local/share")
                os.environ["XDG_STATE_HOME"] = str(home / ".local/state")
                os.environ["ASTREA_STEAM_ROOT"] = str(steam)
                os.environ["PATH"] = str(bin_dir)

                payload = runner.run(str(target), dry_run=True)
            finally:
                os.environ.clear()
                os.environ.update(old_env)

            command = payload["command"]
            self.assertTrue(payload["ok"])
            self.assertEqual(command[0], str(bin_dir / "gamemoderun"))
            self.assertEqual(command[1], str(bin_dir / "gamescope"))
            self.assertIn("--mangoapp", command)
            self.assertIn("-W", command)
            self.assertIn("1600", command)
            self.assertIn("-H", command)
            self.assertIn("900", command)
            self.assertIn("-r", command)
            self.assertIn("75", command)
            self.assertIn("--", command)
            separator = command.index("--")
            self.assertEqual(command[separator + 1:separator + 3], [str(proton), "run"])

    def test_dry_run_does_not_expose_or_override_windows_user(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            home = root / "home"
            steam = home / ".local/share/Steam"
            proton = steam / "compatibilitytools.d/Proton-GE Latest/proton"
            target = home / "Downloads/App/app.exe"
            config_dir = home / ".config/AstreaOS/gaming"
            proton.parent.mkdir(parents=True)
            proton.write_text("#!/bin/sh\n", encoding="utf-8")
            proton.chmod(0o755)
            target.parent.mkdir(parents=True)
            target.write_bytes(b"MZ")
            config_dir.mkdir(parents=True)
            (config_dir / "compatibility.json").write_text(json.dumps({
                "runner": "proton",
                "windows_user": "legacy-value",
            }), encoding="utf-8")

            old_env = os.environ.copy()
            try:
                os.environ.clear()
                os.environ["HOME"] = str(home)
                os.environ["USER"] = "agony"
                os.environ["XDG_CONFIG_HOME"] = str(home / ".config")
                os.environ["XDG_DATA_HOME"] = str(home / ".local/share")
                os.environ["XDG_STATE_HOME"] = str(home / ".local/state")
                os.environ["ASTREA_STEAM_ROOT"] = str(steam)
                os.environ["PATH"] = ""

                command, env, _, _, _, _ = runner.build_launch(target)
                payload = runner.run(str(target), dry_run=True)
            finally:
                os.environ.clear()
                os.environ.update(old_env)

            self.assertEqual(command[:2], [str(proton), "run"])
            self.assertEqual(env.get("USER"), "agony")
            self.assertNotEqual(env.get("USERNAME"), "legacy-value")
            self.assertNotIn("windows_user", payload)


if __name__ == "__main__":
    unittest.main()
