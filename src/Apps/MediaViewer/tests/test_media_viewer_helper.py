import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from urllib.parse import quote

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import media_viewer_helper as helper


class MediaClassificationTests(unittest.TestCase):
    def test_classifies_only_known_images_as_media(self):
        self.assertEqual(helper.media_kind(Path("photo.JPG")), "image")
        self.assertEqual(helper.media_kind(Path("photo.webp")), "image")
        self.assertEqual(helper.media_kind(Path("raw.dng")), "image")
        self.assertEqual(helper.media_kind(Path("clip.mkv")), "other")
        self.assertEqual(helper.media_kind(Path("notes.txt")), "other")


class ScanDirectoryTests(unittest.TestCase):
    def test_scan_emits_sorted_image_items_with_metadata(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / "zeta.mp4").write_bytes(b"video")
            (root / "alpha.png").write_bytes(b"image")
            (root / "notes.txt").write_text("nope")

            payload = helper.scan_directory(root)

            self.assertEqual([item["name"] for item in payload["items"]], ["alpha.png"])
            self.assertEqual([item["kind"] for item in payload["items"]], ["image"])
            self.assertEqual(payload["directory"], str(root))

    def test_open_target_selects_file_in_parent_context(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / "a.jpg").write_bytes(b"image")
            target = root / "b.png"
            target.write_bytes(b"image")

            payload = helper.open_target(target)

            self.assertEqual(payload["directory"], str(root))
            self.assertEqual(payload["selected_index"], 1)
            self.assertEqual(payload["items"][1]["path"], str(target))

    def test_open_target_rejects_video_files(self):
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "clip.mp4"
            target.write_bytes(b"video")

            with self.assertRaisesRegex(ValueError, "Arquivo nao e imagem"):
                helper.open_target(target)

    def test_open_target_accepts_file_uri(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            target = root / "spaced image.png"
            target.write_bytes(b"image")
            uri = "file://" + quote(str(target))

            payload = helper.open_target(uri)

            self.assertEqual(payload["selected_index"], 0)
            self.assertEqual(payload["items"][0]["name"], "spaced image.png")


class CliTests(unittest.TestCase):
    def test_cli_scan_outputs_json(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / "photo.webp").write_bytes(b"image")

            output = helper.main(["scan", str(root)], printer=lambda text: text)

        payload = json.loads(output)
        self.assertEqual(payload["items"][0]["name"], "photo.webp")


class PreviewImageTests(unittest.TestCase):
    def test_preview_uses_original_uri_for_qt_native_formats(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "photo.png"
            path.write_bytes(b"image")

            result = helper.preview_image(path)

        self.assertEqual(result["ok"], True)
        self.assertEqual(result["uri"], path.resolve().as_uri())
        self.assertEqual(result["source"], "direct")

    def test_preview_converts_webp_to_cached_png(self):
        calls = []

        def fake_runner(command, **kwargs):
            calls.append((command, kwargs))
            output = Path(command[-1].removeprefix("png:"))
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(b"png")
            return subprocess.CompletedProcess(command, 0)

        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            path = root / "photo.webp"
            path.write_bytes(b"webp")
            cache = root / "cache"

            result = helper.preview_image(path, runner=fake_runner, cache_dir=cache)

        self.assertEqual(result["ok"], True)
        self.assertEqual(result["source"], "converted")
        self.assertTrue(result["uri"].endswith(".png"))
        self.assertEqual(calls[0][0][0], "magick")
        self.assertIn("timeout", calls[0][1])

    def test_preview_conversion_publishes_cache_atomically(self):
        final_paths = []

        def fake_runner(command, **_kwargs):
            output = Path(command[-1].removeprefix("png:"))
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(b"png")
            final_paths.append(output)
            return subprocess.CompletedProcess(command, 0)

        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            path = root / "photo.webp"
            path.write_bytes(b"webp")
            cache = root / "cache"
            expected_name = helper.preview_cache_path(path, cache).name

            result = helper.preview_image(path, runner=fake_runner, cache_dir=cache)
            published = Path(result["uri"].removeprefix("file://"))

        self.assertEqual(result["ok"], True)
        self.assertNotEqual(final_paths[0], published)
        self.assertEqual(published.name, expected_name)

    def test_preview_conversion_uses_high_quality_display_resampling(self):
        calls = []

        def fake_runner(command, **kwargs):
            calls.append(command)
            output = Path(command[-1].removeprefix("png:"))
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(b"png")
            return subprocess.CompletedProcess(command, 0)

        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            path = root / "photo.webp"
            path.write_bytes(b"webp")

            helper.preview_image(path, runner=fake_runner, cache_dir=root / "cache")

        command = calls[0]
        self.assertIn("-filter", command)
        self.assertIn("Lanczos", command)
        self.assertIn("-define", command)
        self.assertIn("filter:blur=0.92", command)
        self.assertIn("-resize", command)
        self.assertIn("1920x1920>", command)
        self.assertNotIn("-thumbnail", command)

    def test_cli_preview_outputs_json(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "photo.jpg"
            path.write_bytes(b"image")

            output = helper.main(["preview", str(path)], printer=lambda text: text)

        payload = json.loads(output)
        self.assertEqual(payload["ok"], True)
        self.assertEqual(payload["source"], "direct")


if __name__ == "__main__":
    unittest.main()
