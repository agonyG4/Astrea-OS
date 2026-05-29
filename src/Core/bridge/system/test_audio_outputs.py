#!/usr/bin/env python3

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

import audio


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

    def test_legacy_hesuvi_sink_is_reported_as_loaded_spatial_sink(self):
        sinks = [
            {"name": audio.LEGACY_SPATIAL_SINK, "description": "HeSuVi", "virtual": True},
            {"name": "headset", "description": "Headset", "virtual": False, "index": 1},
        ]

        state = audio.spatial_state(sinks, [], audio.LEGACY_SPATIAL_SINK)

        self.assertTrue(state["available"])
        self.assertTrue(state["enabled"])
        self.assertEqual(state["sink"], audio.LEGACY_SPATIAL_SINK)

    def test_spatial_engine_template_renders_runtime_paths_and_target(self):
        original_root = audio.ASTREA_ROOT
        original_template = audio.SPATIAL_ENGINE_TEMPLATE
        try:
            with TemporaryDirectory() as tmp:
                root = Path(tmp) / "Astrea"
                template = root / "System/config/pipewire/astrea-audio-engine.conf"
                template.parent.mkdir(parents=True)
                template.write_text(
                    'filename = "@ASTREA_HRIR_PATH@"\n'
                    '    @ASTREA_TARGET_OBJECT_LINE@\n',
                    encoding="utf-8",
                )
                audio.ASTREA_ROOT = root
                audio.SPATIAL_ENGINE_TEMPLATE = template

                rendered = audio.render_spatial_engine_config("alsa_output.test")

                self.assertIn(str(root / "audio/hrir.wav"), rendered)
                self.assertIn('target.object  = "alsa_output.test"', rendered)
                self.assertNotIn("@ASTREA", rendered)
                self.assertNotIn("/home/agony", rendered)
        finally:
            audio.ASTREA_ROOT = original_root
            audio.SPATIAL_ENGINE_TEMPLATE = original_template


if __name__ == "__main__":
    unittest.main()
