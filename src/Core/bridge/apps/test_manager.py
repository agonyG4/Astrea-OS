#!/usr/bin/env python3

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

MANAGER_PATH = Path(__file__).with_name("manager.py")
spec = importlib.util.spec_from_file_location("apps_manager_under_test", MANAGER_PATH)
manager = importlib.util.module_from_spec(spec)
sys.modules["apps_manager_under_test"] = manager
assert spec and spec.loader
spec.loader.exec_module(manager)


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

    def test_flatpak_app_id_reads_desktop_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "com.example.App.desktop"
            source.write_text(
                "[Desktop Entry]\n"
                "Type=Application\n"
                "Name=Example\n"
                "Exec=/usr/bin/flatpak run com.example.App\n"
                "X-Flatpak=com.example.App\n",
                encoding="utf-8",
            )

            self.assertEqual(manager.flatpak_app_id({"desktop_file": str(source)}), "com.example.App")

    def test_native_permission_rows_are_not_claimed_supported(self):
        permissions = manager.build_permissions({"id": "native.desktop"}, "")
        self.assertEqual([item["id"] for item in permissions], ["microphone", "camera"])
        self.assertTrue(all(item["supported"] is False for item in permissions))

    def test_override_parser_detects_blocked_microphone_and_camera(self):
        text = "[Context]\nsockets=!pulseaudio;\n[Session Bus Policy]\norg.freedesktop.portal.Camera=none\n"
        self.assertIn("!pulseaudio", manager.override_values(text, "sockets"))
        self.assertTrue(manager.camera_blocked(text))

    def test_uninstall_user_desktop_file_removes_launcher_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "local-app.desktop"
            source.write_text("[Desktop Entry]\nType=Application\nName=Local\n", encoding="utf-8")

            with mock.patch.object(manager, "refresh_desktop_index"):
                result = manager.uninstall_app({"id": "local-app.desktop", "desktop_file": str(source), "source": "user"})

            self.assertFalse(source.exists())
            self.assertEqual(result["message"], "Launcher removido da lista de aplicativos")

    def test_steam_game_launcher_must_be_uninstalled_in_steam(self):
        app = {
            "id": "Stardew Valley.desktop",
            "name": "Stardew Valley",
            "comment": "Play this game on Steam",
            "exec": "steam steam://rungameid/413150",
            "icon": "steam_icon_413150",
            "desktop_file": "/home/agony/.local/share/applications/Stardew Valley.desktop",
            "source": "user",
        }
        info = manager.uninstall_info(app)
        self.assertFalse(info["can"])
        self.assertEqual(info["method"], "steam")

    def test_steam_game_size_uses_manifest_size_on_disk(self):
        with tempfile.TemporaryDirectory() as tmp:
            library = Path(tmp)
            steamapps = library / "steamapps"
            steamapps.mkdir()
            (steamapps / "appmanifest_413150.acf").write_text(
                '"AppState"\n{\n    "appid"        "413150"\n    "name"         "Stardew Valley"\n    "installdir"   "Stardew Valley"\n    "SizeOnDisk"   "708901690"\n}\n',
                encoding="utf-8",
            )
            app = {"id": "Stardew Valley.desktop", "comment": "Play this game on Steam", "exec": "steam steam://rungameid/413150", "icon": "steam_icon_413150", "desktop_file": str(library / "x.desktop"), "source": "user"}
            with mock.patch.object(manager, "steam_library_dirs", return_value=[library], create=True):
                size = manager.app_size(app, "")
        self.assertEqual(size["bytes"], 708901690)

    def test_uninstall_flatpak_runs_flatpak_uninstall(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "com.example.App.desktop"
            source.write_text("[Desktop Entry]\nType=Application\nName=Example\nExec=/usr/bin/flatpak run com.example.App\nX-Flatpak=com.example.App\n", encoding="utf-8")
            with mock.patch.object(manager.subprocess, "run") as run_mock, mock.patch.object(manager, "refresh_desktop_index"):
                result = manager.uninstall_app({"id": source.name, "desktop_file": str(source), "source": "system"})
            run_mock.assert_called_once()
            self.assertEqual(result["target"], "com.example.App")

    def test_uninstall_system_package_runs_pkexec_pacman(self):
        app = {"id": "brave-browser.desktop", "desktop_file": "/usr/share/applications/brave-browser.desktop", "source": "system"}
        with mock.patch.object(manager, "package_owner", return_value="brave-bin"), mock.patch.object(manager.subprocess, "run") as run_mock, mock.patch.object(manager, "refresh_desktop_index"):
            result = manager.uninstall_app(app)
        run_mock.assert_called_once_with(["pkexec", "pacman", "-Rns", "--noconfirm", "brave-bin"], check=True, stdout=manager.subprocess.DEVNULL, stderr=manager.subprocess.PIPE, text=True)
        self.assertEqual(result["message"], "Pacote brave-bin desinstalado")

    def test_main_list_action_is_import_safe_and_returns_zero(self):
        with mock.patch.object(manager, "list_apps", return_value={"apps": [], "total": 0, "user_count": 0, "system_count": 0}), mock.patch("builtins.print"):
            self.assertEqual(manager.main(["list"]), 0)


if __name__ == "__main__":
    unittest.main()
