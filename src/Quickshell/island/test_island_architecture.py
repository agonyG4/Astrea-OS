#!/usr/bin/env python3
import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parent


def read(relative_path):
    return (ROOT / relative_path).read_text(encoding="utf-8")


class IslandArchitectureTest(unittest.TestCase):
    def test_core_modules_are_exported(self):
        island_qmldir = read("qmldir")
        core_qmldir = read("core/qmldir")
        modes_qmldir = read("modes/qmldir")
        music_qmldir = read("modes/music/qmldir")
        idle_qmldir = read("modes/idle/qmldir")
        gamemode_qmldir = read("modes/gamemode/qmldir")

        self.assertIn("IslandModeHost", island_qmldir)
        self.assertIn("IslandState", core_qmldir)
        self.assertIn("IslandGeometry", core_qmldir)
        self.assertIn("IslandInteraction", core_qmldir)
        self.assertIn("ModeContainer", modes_qmldir)
        self.assertIn("MusicMode", music_qmldir)
        self.assertIn("IdleMode", idle_qmldir)
        self.assertIn("GamemodeMode", gamemode_qmldir)

    def test_root_preserves_public_music_contract(self):
        island = read("Island.qml")

        self.assertRegex(island, r"property\s+alias\s+musicBars\s*:\s*islandState\.musicBars")
        self.assertRegex(island, r"property\s+alias\s+cavaBars\s*:\s*islandState\.cavaBars")
        self.assertIn("Core.IslandState", island)
        self.assertIn("islandState: islandState", island)

    def test_content_uses_geometry_module_for_dimensions(self):
        content = read("IslandContent.qml")

        self.assertIn("Core.IslandGeometry", content)
        self.assertIn("Core.IslandInteraction", content)
        self.assertRegex(content, r"width:\s*geometry\.width")
        self.assertRegex(content, r"height:\s*geometry\.height")
        self.assertRegex(content, r"radius:\s*geometry\.radius")

        width_block = re.search(r"width:\s*\{(?P<body>.*?)\n\s*\}", content, re.S)
        self.assertIsNone(width_block, "IslandContent should not own mode width branching")

    def test_idle_mode_is_wired(self):
        mode_host = read("IslandModeHost.qml")
        idle_mode = read("modes/idle/IdleMode.qml")

        self.assertIn('./modes/idle" as Idle', mode_host)
        self.assertIn("Idle.IdleMode", mode_host)
        self.assertIn("IdleCompactView", idle_mode)

    def test_host_uses_mode_wrappers(self):
        mode_host = read("IslandModeHost.qml")

        self.assertIn("Modes.ModeContainer", mode_host)
        self.assertIn("Music.MusicMode", mode_host)
        self.assertIn("Gamemode.GamemodeMode", mode_host)
        self.assertNotIn("Music.MusicCompactBars", mode_host)
        self.assertNotIn("Music.MusicArtwork", mode_host)
        self.assertNotIn("Music.MusicView", mode_host)

    def test_music_artwork_masks_album_art(self):
        artwork = read("modes/music/MusicArtwork.qml")

        self.assertIn("OpacityMask", artwork)
        self.assertIn("maskSource: artClipMask", artwork)


if __name__ == "__main__":
    unittest.main()
