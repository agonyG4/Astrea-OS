#!/usr/bin/env python3

import unittest
import tempfile
from pathlib import Path
from unittest import mock

import audio
import app_icons


class OutputStateTests(unittest.TestCase):
    def test_build_outputs_state_splits_visible_and_hidden_without_hiding_effective_default(self):
        sinks = [
            {"name": audio.SPATIAL_SINK, "description": "Spatial", "virtual": True},
            {"name": "headset", "description": "Headset", "virtual": False},
            {"name": "hdmi", "description": "Monitor", "virtual": False},
            {"name": "spdif", "description": "SPDIF", "virtual": False},
        ]
        spatial = {"enabled": True, "target_sink": "headset"}

        state = audio.build_outputs_state(
            sinks,
            spatial,
            default_sink=audio.SPATIAL_SINK,
            hidden_names={"headset", "spdif"},
        )

        self.assertEqual([item["name"] for item in state["visible"]], ["headset", "hdmi"])
        self.assertEqual([item["name"] for item in state["hidden"]], ["spdif"])
        self.assertEqual([item["name"] for item in state["all"]], ["headset", "hdmi", "spdif"])
        self.assertTrue(state["visible"][0]["effective_default"])
        self.assertTrue(state["visible"][0]["hidden"])
        self.assertFalse(state["hidden"][0]["effective_default"])


class AppIconTests(unittest.TestCase):
    def test_steam_appid_for_process_reads_ancestor_env(self):
        props = {"application.process.id": "10"}

        def parent(pid):
            return {"10": "9", "9": "1"}.get(str(pid), "")

        def env(pid):
            if str(pid) == "9":
                return {"STEAM_COMPAT_APP_ID": "1234"}
            return {}

        with mock.patch.object(app_icons, "_process_parent_pid", side_effect=parent), \
             mock.patch.object(app_icons, "_process_environ", side_effect=env), \
             mock.patch.object(app_icons, "_process_cmdline", return_value=""), \
             mock.patch.object(app_icons, "_process_cwd", return_value=""):
            self.assertEqual(app_icons._steam_appid_for_process(props), "1234")

    def test_steam_appid_for_process_reads_compatdata_path_from_cmdline(self):
        props = {"application.process.id": "10"}
        cmdline = "/mnt/steam/steamapps/compatdata/5678/pfx/drive_c/Game/MIST.exe"

        with mock.patch.object(app_icons, "_process_parent_pid", return_value=""), \
             mock.patch.object(app_icons, "_process_environ", return_value={}), \
             mock.patch.object(app_icons, "_process_cmdline", return_value=cmdline), \
             mock.patch.object(app_icons, "_process_cwd", return_value=""):
            self.assertEqual(app_icons._steam_appid_for_process(props), "5678")

    def test_steam_manifest_match_uses_exe_stem_for_wine_names(self):
        fields = {"appid": "999", "name": "MIST", "installdir": "MIST"}

        self.assertGreaterEqual(
            app_icons._steam_manifest_match_score(fields, ["mist"], "MIST.exe"),
            75,
        )

    def test_wine_executable_paths_map_wine_drive(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            prefix = root / "prefix"
            drive_c = root / "drive_c"
            exe = drive_c / "Game" / "MIST.exe"
            (prefix / "dosdevices").mkdir(parents=True)
            exe.parent.mkdir(parents=True)
            exe.touch()
            (prefix / "dosdevices" / "c:").symlink_to(drive_c)

            context = {
                "env": {"WINEPREFIX": str(prefix)},
                "cmdline": r"C:\Game\MIST.exe",
                "cwd": "",
            }
            props = {"application.process.id": "10", "application.name": "MIST.exe"}
            with mock.patch.object(app_icons, "_process_contexts", return_value=[context]):
                self.assertEqual(app_icons._wine_executable_paths("MIST.exe", props), [exe])

    def test_local_icon_for_executable_finds_nearby_game_icon(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            exe = root / "MIST.exe"
            icon_dir = root / "game"
            icon = icon_dir / "icon.png"
            icon_dir.mkdir()
            exe.touch()
            icon.write_bytes(b"not a real image")

            self.assertEqual(app_icons._local_icon_for_executable(exe), str(icon))

    def test_best_ico_frame_prefers_largest_square_frame(self):
        identify_output = "0 16 16\n1 24 24\n2 32 32\n3 48 48\n4 64 64\n5 128 128\n6 256 256\n"

        self.assertEqual(app_icons._best_ico_frame_from_identify(identify_output), (6, 256))

    def test_annotate_hypr_clients_adds_resolved_icon(self):
        clients = [{"class": "steam_app_default", "title": "MIST", "pid": 42}]

        with mock.patch.object(app_icons, "resolve_app_icon", return_value=("mist", "/tmp/mist.png")):
            annotated = app_icons.annotate_hypr_clients(clients)

        self.assertEqual(annotated[0]["astreaIcon"], "/tmp/mist.png")
        self.assertEqual(annotated[0]["astreaIconName"], "mist")


if __name__ == "__main__":
    unittest.main()
