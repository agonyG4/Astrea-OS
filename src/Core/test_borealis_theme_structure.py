from pathlib import Path
import unittest


CORE_DIR = Path(__file__).resolve().parent
BOREALIS_DIR = CORE_DIR / "components" / "theme" / "Borealis"


class BorealisThemeStructureTest(unittest.TestCase):
    def test_borealis_theme_module_exists_with_expected_parts(self):
        expected_files = {
            "qmldir",
            "Theme.qml",
            "State.qml",
            "Tokens.qml",
            "Apps.qml",
            "Shell.qml",
        }

        self.assertTrue(BOREALIS_DIR.is_dir())
        self.assertTrue(expected_files.issubset({path.name for path in BOREALIS_DIR.iterdir()}))

    def test_legacy_components_theme_wraps_borealis_theme(self):
        legacy_theme = CORE_DIR / "components" / "theme" / "Theme.qml"
        contents = legacy_theme.read_text(encoding="utf-8")

        self.assertIn("./Borealis", contents)
        self.assertIn("Borealis.Theme", contents)

    def test_shell_and_explorer_themes_are_borealis_adapters(self):
        astrea_root = CORE_DIR.parent
        adapters = [
            astrea_root / "Quickshell" / "bar" / "Theme.qml",
            astrea_root / "Apps" / "Explorer" / "Theme.qml",
        ]

        for adapter in adapters:
            with self.subTest(adapter=adapter):
                contents = adapter.read_text(encoding="utf-8")
                self.assertIn("AstreaComponents", contents)
                self.assertIn("Components.Theme", contents)
                self.assertNotIn("FileView", contents)
                self.assertNotIn("applyThemeConfig", contents)

    def test_explorer_does_not_create_unused_json_worker(self):
        astrea_root = CORE_DIR.parent
        navigation_state = astrea_root / "Apps" / "Explorer" / "state" / "NavigationState.qml"
        contents = navigation_state.read_text(encoding="utf-8")

        self.assertNotIn("WorkerScript", contents)
        self.assertNotIn("JsonWorker.js", contents)

    def test_shell_polkit_agent_is_guarded_for_parallel_smoke_loads(self):
        astrea_root = CORE_DIR.parent
        shell = astrea_root / "Quickshell" / "shell.qml"
        contents = shell.read_text(encoding="utf-8")

        self.assertIn("polkitProbe", contents)
        self.assertIn("ASTREA_FORCE_POLKIT_AGENT", contents)
        self.assertIn("Auth.AstreaPolkitAgent", contents)

    def test_shell_theme_exposes_separate_icon_font(self):
        astrea_root = CORE_DIR.parent
        theme = astrea_root / "Quickshell" / "bar" / "Theme.qml"
        contents = theme.read_text(encoding="utf-8")

        self.assertIn("iconFontFamily", contents)
        self.assertIn("Nerd Font", contents)


if __name__ == "__main__":
    unittest.main()
