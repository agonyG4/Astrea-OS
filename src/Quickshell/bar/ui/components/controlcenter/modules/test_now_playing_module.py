#!/usr/bin/env python3
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parent


class NowPlayingModuleTests(unittest.TestCase):
    def test_card_background_stays_neutral_when_media_is_active(self):
        source = (ROOT / "NowPlayingModule.qml").read_text(encoding="utf-8")
        color_match = re.search(r"^\s*color:\s*(?P<expr>.+)$", source, re.MULTILINE)

        self.assertIsNotNone(color_match)
        color_expr = color_match.group("expr")
        self.assertEqual("Theme.surface", color_expr)
        self.assertNotIn("Theme.accent", color_expr)


if __name__ == "__main__":
    unittest.main()
