import json
import io
import subprocess
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import explorer_helper as helper


class ScanConflictsTests(unittest.TestCase):
    def test_no_conflicts(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            src = root / "src"
            dst = root / "dst"
            src.mkdir(); dst.mkdir()
            (src / "a.txt").write_text("a")
            rec = helper._conflict_record(src / "a.txt", dst)
            self.assertIsNone(rec)

    def test_file_file_conflict(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            src = root / "src"; dst = root / "dst"
            src.mkdir(); dst.mkdir()
            (src / "a.txt").write_text("a")
            (dst / "a.txt").write_text("b")
            rec = helper._conflict_record(src / "a.txt", dst)
            self.assertEqual(rec["conflict_kind"], "file-replace")

    def test_dir_dir_conflict(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            src = root / "src"; dst = root / "dst"
            src.mkdir(); dst.mkdir()
            (src / "folder").mkdir(); (dst / "folder").mkdir()
            rec = helper._conflict_record(src / "folder", dst)
            self.assertEqual(rec["conflict_kind"], "directory-merge")

    def test_file_dir_and_dir_file(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            src = root / "src"; dst = root / "dst"
            src.mkdir(); dst.mkdir()
            (src / "node").write_text("a")
            (dst / "node").mkdir()
            rec = helper._conflict_record(src / "node", dst)
            self.assertEqual(rec["conflict_kind"], "file-over-directory")
            (src / "node").unlink(); (src / "node").mkdir()
            (dst / "node").rmdir(); (dst / "node").write_text("b")
            rec2 = helper._conflict_record(src / "node", dst)
            self.assertEqual(rec2["conflict_kind"], "directory-over-file")

class TrashOpsTests(unittest.TestCase):
    def test_trash_and_restore_with_collision_and_unicode(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            home = root / "home"
            trash_files = home / ".local/share/Trash/files"
            trash_info = home / ".local/share/Trash/info"
            src_dir = home / "docs"
            src_dir.mkdir(parents=True)

            name = "a | ' 😀\n.txt"
            source = src_dir / name
            source.write_text("content", encoding="utf-8")

            helper.trash_items(str(trash_files), str(trash_info), [str(source)])
            self.assertFalse(source.exists())
            trashed = list(trash_files.iterdir())
            self.assertEqual(len(trashed), 1)
            info = trash_info / f"{trashed[0].name}.trashinfo"
            body = info.read_text(encoding="utf-8")
            self.assertIn("[Trash Info]", body)
            self.assertIn("Path=", body)
            self.assertIn("DeletionDate=", body)

            # force restore collision at original path
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_text("existing", encoding="utf-8")
            helper.restore_trash_items(str(trash_info), str(home), [str(trashed[0])])
            restored_candidates = list(source.parent.glob("a*txt"))
            self.assertGreaterEqual(len(restored_candidates), 2)

    def test_restore_without_trashinfo_falls_back(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            fallback = root / "fallback"
            trash_files = root / "trash/files"
            trash_info = root / "trash/info"
            trash_files.mkdir(parents=True)
            trash_info.mkdir(parents=True)
            t = trash_files / "orphan.txt"
            t.write_text("x")
            helper.restore_trash_items(str(trash_info), str(fallback), [str(t)])
            self.assertTrue((fallback / "orphan.txt").exists())

    def test_empty_trash(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            trash_files = root / "trash/files"
            trash_info = root / "trash/info"
            (trash_files / "d").mkdir(parents=True)
            (trash_files / "d" / "x.txt").write_text("x")
            trash_info.mkdir(parents=True)
            (trash_info / "x.trashinfo").write_text("meta")
            helper.empty_trash(str(trash_files), str(trash_info))
            self.assertEqual(list(trash_files.iterdir()), [])
            self.assertEqual(list(trash_info.iterdir()), [])

class PasteImageTests(unittest.TestCase):
    def test_image_extension_mapping(self):
        self.assertEqual(helper.image_extension_for_mime("image/png"), "png")
        self.assertEqual(helper.image_extension_for_mime("image/jpeg"), "jpg")
        self.assertEqual(helper.image_extension_for_mime("image/unknown"), "png")

    def test_paste_image_writes_bytes_and_unique_name(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            dest = root / "dest 😀"
            dest.mkdir()
            fixed = "Pasted Image 2026-01-01 10-00-00"
            (dest / f"{fixed}.png").write_bytes(b"old")

            old = helper.time.strftime
            helper.time.strftime = lambda _: "2026-01-01 10-00-00"
            try:
                def fake_runner(cmd, check, stdout, stderr):
                    self.assertEqual(cmd[:3], ["wl-paste", "--no-newline", "--type"])
                    self.assertEqual(cmd[3], "image/png")
                    return subprocess.CompletedProcess(cmd, 0, stdout=b"image-bytes", stderr=b"")

                out = helper.paste_image(str(dest), "image/png", paste_runner=fake_runner)
            finally:
                helper.time.strftime = old

            path = Path(out)
            self.assertTrue(path.exists())
            self.assertEqual(path.read_bytes(), b"image-bytes")
            self.assertTrue(path.name.startswith(fixed))
            self.assertNotEqual(path.name, f"{fixed}.png")

    def test_paste_image_unknown_mime_fallback_and_missing_dest(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            dest = root / "dest"
            dest.mkdir()
            created = helper.paste_image(
                str(dest),
                "image/custom",
                paste_runner=lambda *args, **kwargs: subprocess.CompletedProcess([], 0, stdout=b"x", stderr=b""),
            )
            self.assertTrue(str(created).endswith(".png"))
            with self.assertRaises(SystemExit):
                helper.paste_image(str(root / "missing"), "image/png", paste_runner=lambda *a, **k: None)

class ArchiveHelperTests(unittest.TestCase):
    def test_extract_archive_emits_json_and_unique_destination(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            archive = root / "arquivo 😀.zip"
            archive.write_bytes(b"x")
            (root / "out").mkdir()
            (root / "out 2").mkdir()

            calls = []
            buf = io.StringIO()
            with redirect_stdout(buf):
                helper.extract_archive(
                    str(archive),
                    "out",
                    run_cmd=lambda cmd, **kwargs: calls.append(cmd) or subprocess.CompletedProcess(cmd, 0, b"", b""),
                    which_runner=lambda name: "/usr/bin/" + name if name in ("unzip", "tar", "bsdtar") else None,
                )
            lines = [json.loads(line) for line in buf.getvalue().splitlines() if line.strip()]
            self.assertEqual(lines[0]["event"], "start")
            self.assertEqual(lines[-1]["event"], "done")
            self.assertTrue(lines[0]["destination"].endswith("out 3"))
            self.assertEqual(lines[-1]["percent"], 100)
            self.assertTrue(calls)

    def test_compress_folder_invalid_format_and_missing_tool(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            folder = root / "pasta"
            folder.mkdir()
            buf = io.StringIO()
            with self.assertRaises(SystemExit):
                with redirect_stdout(buf):
                    helper.compress_folder(str(folder), "bad", run_cmd=lambda *a, **k: None)
            err = json.loads(buf.getvalue().splitlines()[-1])
            self.assertEqual(err["code"], "invalid_format")

            buf2 = io.StringIO()
            with self.assertRaises(SystemExit):
                with redirect_stdout(buf2):
                    helper.compress_folder(str(folder), "zip", run_cmd=lambda *a, **k: None, which_runner=lambda _: None)
            err2 = json.loads(buf2.getvalue().splitlines()[-1])
            self.assertEqual(err2["code"], "missing_tool")

    def test_extract_7z_uses_joined_output_flag(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            archive = root / "x.7z"
            archive.write_bytes(b"x")
            captured = {}

            def fake_run(cmd, **kwargs):
                captured["cmd"] = cmd
                return subprocess.CompletedProcess(cmd, 0, b"", b"")

            helper.extract_archive(
                str(archive),
                "dest",
                run_cmd=fake_run,
                which_runner=lambda name: "/usr/bin/7z" if name == "7z" else None,
            )
            self.assertTrue(any(part.startswith("-o") and len(part) > 2 for part in captured["cmd"]))


if __name__ == "__main__":
    unittest.main()
