from pathlib import Path
import unittest


MAIN_QML = Path(__file__).resolve().parents[1] / "Main.qml"


def _function_body(source: str, name: str) -> str:
    marker = f"function {name}"
    start = source.index(marker)
    brace = source.index("{", start)
    depth = 0
    for index in range(brace, len(source)):
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1:index]
    raise AssertionError(f"function {name} body not found")


def _block_after_marker(source: str, marker: str) -> str:
    start = source.index(marker)
    brace = source.index("{", start)
    depth = 0
    for index in range(brace, len(source)):
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1:index]
    raise AssertionError(f"block for {marker} not found")


class ZoomQmlTests(unittest.TestCase):
    def test_zoom_anchor_position_is_not_applied_in_a_later_frame(self):
        source = MAIN_QML.read_text(encoding="utf-8")
        body = _function_body(source, "setZoomAnchored")

        self.assertNotIn("Qt.callLater(applyPendingContentPosition)", body)
        self.assertNotIn("pendingContentX", body)
        self.assertNotIn("pendingContentY", body)

    def test_zoom_preserves_the_image_point_under_the_pointer(self):
        source = MAIN_QML.read_text(encoding="utf-8")
        body = _function_body(source, "setZoomAnchored")

        self.assertIn("var anchorRatio = imageRatioAtView(oldZoom, liveViewPoint.x, liveViewPoint.y)", body)
        self.assertIn("setFlickContentSizeForZoom(zoom)", body)
        self.assertIn("positionImageRatioAtView(anchorRatio.x, anchorRatio.y, liveViewPoint.x, liveViewPoint.y)", body)
        self.assertNotIn("resizeContentForZoom", body)
        self.assertNotIn("returnToBounds", body)

    def test_zoom_does_not_mix_flickable_resize_animation_with_manual_positioning(self):
        source = MAIN_QML.read_text(encoding="utf-8")

        self.assertNotIn("mediaFlick.resizeContent(", source)
        self.assertNotIn("mediaFlick.returnToBounds()", source)
        self.assertIn("mediaFlick.contentWidth = contentWidthForZoom(nextZoom)", source)
        self.assertIn("mediaFlick.contentHeight = contentHeightForZoom(nextZoom)", source)

    def test_wheel_zoom_uses_mousearea_local_position(self):
        source = MAIN_QML.read_text(encoding="utf-8")

        self.assertIn("window.zoomAt(imagePointerArea.mouseX, imagePointerArea.mouseY, steps)", source)
        self.assertNotIn("window.zoomAt(wheel.x, wheel.y, steps)", source)

    def test_pointer_area_is_viewport_overlay_not_flickable_content(self):
        source = MAIN_QML.read_text(encoding="utf-8")
        flickable_body = _block_after_marker(source, "Flickable {\n                id: mediaFlick")

        self.assertNotIn("MouseArea {", flickable_body)
        self.assertIn("id: imagePointerArea", source)
        self.assertIn("anchors.fill: mediaFlick", source)

    def test_toolbar_is_completely_removed(self):
        source = MAIN_QML.read_text(encoding="utf-8")

        self.assertNotIn("id: toolbar", source)
        self.assertNotIn("ChromeButton", source)
        self.assertNotIn("MediaBadge", source)
        self.assertNotIn("toolbar.bottom", source)
        self.assertIn("anchors.top: parent.top", source)

    def test_window_title_stays_stable_for_hyprland_float_rule(self):
        source = MAIN_QML.read_text(encoding="utf-8")

        self.assertIn('title: t("apps.media_viewer.title", "Astrea Image Viewer")', source)
        self.assertIn('Qt.application.name = t("apps.media_viewer.title", "Astrea Image Viewer")', source)
        self.assertNotIn("title: currentItem", source)


if __name__ == "__main__":
    unittest.main()
