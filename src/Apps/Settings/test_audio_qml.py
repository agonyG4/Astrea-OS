#!/usr/bin/env python3
from pathlib import Path
import unittest

SETTINGS_DIR = Path(__file__).resolve().parent
AUDIO_QML = SETTINGS_DIR / "pages" / "connectivity" / "Audio.qml"


class AudioQmlTests(unittest.TestCase):
    def test_spatial_audio_uses_backend_reported_sink_at_runtime(self):
        source = AUDIO_QML.read_text(encoding="utf-8")
        self.assertIn('readonly property string defaultSpatialSinkName: "effect_input.virtual-surround-7.1-astrea"', source)
        self.assertIn("function currentSpatialSinkName()", source)
        self.assertIn('return (root.spatial && root.spatial.sink) ? root.spatial.sink : root.defaultSpatialSinkName', source)
        self.assertIn('["pactl", "set-default-sink", root.currentSpatialSinkName()]', source)
        self.assertNotIn('["pactl", "set-default-sink", root.defaultSpatialSinkName]', source)

    def test_audio_page_uses_i18n_and_theme_icon_font_for_new_strings(self):
        source = AUDIO_QML.read_text(encoding="utf-8")
        self.assertIn("apps.settings.pages.connectivity.audio.text.loading_audio_info", source)
        self.assertNotIn("loading_audio_infoa", source)
        self.assertIn("apps.settings.pages.connectivity.audio.sublabel.spatial_enabled", source)
        self.assertIn("apps.settings.pages.connectivity.audio.text.show_list", source)
        self.assertIn("font.family: Theme.iconFontFamily", source)
        self.assertNotIn('font.family: "JetBrainsMono Nerd Font"', source)


if __name__ == "__main__":
    unittest.main()
