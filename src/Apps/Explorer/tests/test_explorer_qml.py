import unittest
from pathlib import Path


APP_ROOT = Path(__file__).resolve().parents[1]


class ExplorerQmlFeatureRemovalTests(unittest.TestCase):
    def test_quicklook_is_not_wired_in_main_app_state_or_preview_state(self):
        sources = {
            "Main.qml": APP_ROOT / "Main.qml",
            "AppState.qml": APP_ROOT / "AppState.qml",
            "state/PreviewState.qml": APP_ROOT / "state/PreviewState.qml",
        }
        combined = "\n".join(path.read_text(encoding="utf-8") for path in sources.values())

        for forbidden in [
            "openQuickLook",
            "syncQuickLookSelection",
            "quickLook",
            "quicklook",
            "explorer-quicklook",
            "ASTREA_QUICKLOOK",
        ]:
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, combined)


class ExplorerQmlShortcutWiringTests(unittest.TestCase):
    def test_main_qml_routes_clipboard_shortcuts_through_actions(self):
        main_qml = (APP_ROOT / "Main.qml").read_text(encoding="utf-8")

        self.assertIn("id: explorerCopyAction", main_qml)
        self.assertIn("id: explorerCutAction", main_qml)
        self.assertIn("id: explorerPasteAction", main_qml)
        self.assertIn("shortcut: StandardKey.Copy", main_qml)
        self.assertIn("shortcut: StandardKey.Cut", main_qml)
        self.assertIn("shortcut: StandardKey.Paste", main_qml)
        self.assertIn("fileClipboardShortcutAllowed", main_qml)

    def test_focus_file_surface_targets_content_item(self):
        main_qml = (APP_ROOT / "Main.qml").read_text(encoding="utf-8")

        self.assertIn("function focusFileSurface()", main_qml)
        self.assertIn("contentItem.forceActiveFocus", main_qml)
        self.assertNotIn("\n        forceActiveFocus()\n", main_qml)

if __name__ == "__main__":
    unittest.main()
