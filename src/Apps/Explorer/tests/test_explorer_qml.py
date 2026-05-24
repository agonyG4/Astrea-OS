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


if __name__ == "__main__":
    unittest.main()
