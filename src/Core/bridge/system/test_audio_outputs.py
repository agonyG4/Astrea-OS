#!/usr/bin/env python3

import unittest

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


if __name__ == "__main__":
    unittest.main()
