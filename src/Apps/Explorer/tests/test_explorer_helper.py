import json
import io
import struct
import subprocess
import tarfile
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import explorer_helper as helper


class FeatureRemovalTests(unittest.TestCase):
    def test_quicklook_helper_entrypoints_are_removed(self):
        self.assertFalse(hasattr(helper, "quicklook"))
        self.assertFalse(hasattr(helper, "quicklook_sync"))
        self.assertFalse(hasattr(helper, "_quicklook_command"))


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

    def test_directory_into_own_descendant_is_blocking_conflict(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            src = root / "src"
            child = src / "child"
            child.mkdir(parents=True)
            rec = helper._conflict_record(src, child)
            self.assertEqual(rec["conflict_kind"], "directory-into-self")
            self.assertEqual(rec["supported_policies"], ["skip"])

    def test_broken_destination_symlink_is_reported_as_conflict(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            src = root / "src"; dst = root / "dst"
            src.mkdir(); dst.mkdir()
            (src / "a.txt").write_text("a")
            (dst / "a.txt").symlink_to(root / "missing.txt")

            rec = helper._conflict_record(src / "a.txt", dst)

            self.assertIsNotNone(rec)
            self.assertEqual(rec["destination_type"], "symlink")
            self.assertEqual(rec["conflict_kind"], "name-collision")


class NameSafetyTests(unittest.TestCase):
    def test_create_folder_rejects_path_traversal(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            outside = root.parent / f"{root.name}-outside"

            with self.assertRaises(ValueError):
                helper.create_folder(str(root), f"../{outside.name}")

            self.assertFalse(outside.exists())

    def test_rename_rejects_path_traversal(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            source = root / "old.txt"
            source.write_text("x")
            outside = root.parent / f"{root.name}-outside.txt"

            with self.assertRaises(ValueError):
                helper.rename_path(str(source), f"../{outside.name}")

            self.assertTrue(source.exists())
            self.assertFalse(outside.exists())

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

    def test_trash_moves_broken_symlink_itself(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            trash_files = root / "trash/files"
            trash_info = root / "trash/info"
            source = root / "broken-link"
            source.symlink_to(root / "missing")

            helper.trash_items(str(trash_files), str(trash_info), [str(source)])

            self.assertFalse(source.is_symlink())
            trashed = list(trash_files.iterdir())
            self.assertEqual(len(trashed), 1)
            self.assertTrue(trashed[0].is_symlink())

class PasteImageTests(unittest.TestCase):
    def test_copy_uri_list_percent_encodes_paths(self):
        calls = []

        def fake_runner(cmd, input, text, check):
            calls.append((cmd, input, text, check))
            return subprocess.CompletedProcess(cmd, 0)

        helper.copy_uri_list(["/tmp/a b/ç.txt", "/tmp/hash#file.txt"], runner=fake_runner)

        self.assertEqual(calls[0][0], ["wl-copy", "--type", "text/uri-list"])
        self.assertEqual(calls[0][1], "file:///tmp/a%20b/%C3%A7.txt\nfile:///tmp/hash%23file.txt\n")
        self.assertTrue(calls[0][2])
        self.assertTrue(calls[0][3])

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

class OpenWithTests(unittest.TestCase):
    def test_desktop_entry_parser_keeps_visible_mime_apps(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            app = root / "browser.desktop"
            app.write_text(
                "\n".join([
                    "[Desktop Entry]",
                    "Type=Application",
                    "Name=Browser",
                    "Exec=browser %u",
                    "Icon=browser",
                    "MimeType=text/html;x-scheme-handler/http;",
                ]),
                encoding="utf-8",
            )
            parsed = helper.parse_desktop_entry(app)
            self.assertEqual(parsed["name"], "Browser")
            self.assertIn("text/html", parsed["mime_types"])
            self.assertFalse(parsed["hidden"])

    def test_open_with_apps_returns_only_recommended_desktop_entries(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            apps = root / "applications"
            apps.mkdir()
            (apps / "browser.desktop").write_text(
                "[Desktop Entry]\nType=Application\nName=Browser\nExec=browser %u\nMimeType=text/html;x-scheme-handler/http;\n",
                encoding="utf-8",
            )
            (apps / "editor.desktop").write_text(
                "[Desktop Entry]\nType=Application\nName=Editor\nExec=editor %f\nMimeType=text/html;\nNoDisplay=true\n",
                encoding="utf-8",
            )
            (apps / "notes.desktop").write_text(
                "[Desktop Entry]\nType=Application\nName=Notes\nExec=notes %f\nMimeType=text/plain;\n",
                encoding="utf-8",
            )
            (apps / "service.desktop").write_text(
                "[Desktop Entry]\nType=Application\nName=Service\nExec=service %f\nNoDisplay=true\n",
                encoding="utf-8",
            )
            (apps / "hidden.desktop").write_text(
                "[Desktop Entry]\nType=Application\nName=Hidden\nHidden=true\nExec=hidden %f\nMimeType=text/html;\n",
                encoding="utf-8",
            )
            target = root / "index.html"
            target.write_text("<html></html>", encoding="utf-8")

            result = helper.open_with_apps(
                str(target),
                app_dirs=[apps],
                mime_runner=lambda path: "text/html",
                default_runner=lambda mime: "browser.desktop",
            )

            self.assertEqual(result["mime"], "text/html")
            self.assertEqual(
                [(section["id"], [app["desktop_id"] for app in section["apps"]]) for section in result["sections"]],
                [
                    ("recommended", ["browser.desktop", "editor.desktop"]),
                ],
            )
            self.assertEqual([app["desktop_id"] for app in result["apps"]], ["browser.desktop", "editor.desktop"])
            self.assertTrue(result["sections"][0]["apps"][0]["is_default"])

    def test_open_with_apps_accepts_directories(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            apps = root / "applications"
            apps.mkdir()
            (apps / "files.desktop").write_text(
                "[Desktop Entry]\nType=Application\nName=Files\nExec=files %U\nMimeType=inode/directory;\nCategories=System;FileManager;\n",
                encoding="utf-8",
            )
            (apps / "other.desktop").write_text(
                "[Desktop Entry]\nType=Application\nName=Other\nExec=other %f\nCategories=Utility;\n",
                encoding="utf-8",
            )
            target = root / "Documents"
            target.mkdir()

            result = helper.open_with_apps(
                str(target),
                app_dirs=[apps],
                mime_runner=lambda path: "inode/directory",
                default_runner=lambda mime: "files.desktop",
            )

            self.assertTrue(result["ok"])
            self.assertTrue(result["is_directory"])
            self.assertEqual(result["mime"], "inode/directory")
            self.assertEqual(result["sections"][0]["title"], "Aplicativos recomendados")
            self.assertEqual(result["sections"][0]["apps"][0]["desktop_id"], "files.desktop")
            self.assertEqual(len(result["sections"]), 1)

    def test_open_with_apps_deduplicates_generated_desktop_copies_after_default(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            apps = root / "applications"
            apps.mkdir()
            for desktop_id in ["loupe-2.desktop", "loupe-5.desktop", "loupe.desktop"]:
                (apps / desktop_id).write_text(
                    "[Desktop Entry]\nType=Application\nName=loupe\nExec=loupe %U\nMimeType=image/png;\nNoDisplay=true\n",
                    encoding="utf-8",
                )
            target = root / "photo.png"
            target.write_bytes(b"png")

            result = helper.open_with_apps(
                str(target),
                app_dirs=[apps],
                mime_runner=lambda path: "image/png",
                default_runner=lambda mime: "loupe-5.desktop",
            )

            recommended_ids = [app["desktop_id"] for app in result["sections"][0]["apps"]]
            self.assertEqual(recommended_ids, ["loupe-5.desktop"])

    def test_launch_open_with_uses_gio_without_shell(self):
        calls = []

        def fake_popen(cmd, **kwargs):
            calls.append((cmd, kwargs))

            class Proc:
                pid = 77

            return Proc()

        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            desktop = root / "viewer.desktop"
            target = root / "photo.png"
            desktop.write_text("[Desktop Entry]\nType=Application\nName=Viewer\nExec=viewer %f\n", encoding="utf-8")
            target.write_bytes(b"png")

            result = helper.launch_open_with(str(target), str(desktop), popen=fake_popen)

        self.assertTrue(result["ok"])
        self.assertEqual(calls[0][0][0], "gio")
        self.assertEqual(calls[0][0][1], "launch")
        self.assertIn(target.resolve().as_uri(), calls[0][0])
        self.assertFalse(calls[0][1].get("shell", False))

    def test_set_default_open_with_updates_mime_default(self):
        calls = []

        def fake_runner(cmd, **kwargs):
            calls.append((cmd, kwargs))

            class Result:
                stdout = ""

            return Result()

        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            desktop = root / "viewer.desktop"
            target = root / "photo.png"
            desktop.write_text("[Desktop Entry]\nType=Application\nName=Viewer\nExec=viewer %f\n", encoding="utf-8")
            target.write_bytes(b"png")

            result = helper.set_default_open_with(
                str(target),
                str(desktop),
                mime_runner=lambda path: "image/png",
                default_runner=fake_runner,
            )

        self.assertTrue(result["ok"])
        self.assertEqual(result["mime"], "image/png")
        self.assertEqual(result["default"], "viewer.desktop")
        self.assertEqual(calls[0][0], ["xdg-mime", "default", "viewer.desktop", "image/png"])


class MergedRecentsTests(unittest.TestCase):
    def test_merged_recents_includes_launch_files_desktop_apps_and_xbel_images(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            finder_path = root / "finder-recents.json"
            launch_path = root / "history.jsonl"
            xbel_path = root / "recently-used.xbel"
            image = root / "photo #1.png"
            launched_file = root / "opened.txt"
            desktop = root / "demo.desktop"
            image.write_text("image")
            launched_file.write_text("opened")
            desktop.write_text(
                "\n".join([
                    "[Desktop Entry]",
                    "Type=Application",
                    "Name=Demo App",
                    "Exec=demo",
                ]),
                encoding="utf-8",
            )
            finder_path.write_text(
                json.dumps([
                    {"fileName": "old.txt", "filePath": str(root / "old.txt"), "lastAccessed": 10}
                ]),
                encoding="utf-8",
            )
            launch_path.write_text(
                "\n".join([
                    json.dumps({
                        "timestamp_ms": 100,
                        "kind": "desktop",
                        "target": "demo",
                        "argv": ["gio", "launch", str(desktop)],
                        "status": "ok",
                    }),
                    json.dumps({
                        "timestamp_ms": 200,
                        "kind": "file",
                        "target": str(launched_file),
                        "argv": ["xdg-open", str(launched_file)],
                        "status": "ok",
                    }),
                ]),
                encoding="utf-8",
            )
            xbel_path.write_text(
                f'''<?xml version="1.0" encoding="UTF-8"?>
<xbel version="1.0">
  <bookmark href="{helper._file_url(image)}" added="2026-01-01T00:00:00Z" modified="2026-01-02T00:00:00Z" visited="2026-01-03T00:00:00Z" />
</xbel>
''',
                encoding="utf-8",
            )

            recents = helper.merged_recents(str(finder_path), str(launch_path), str(xbel_path), limit=10)

            paths = {item["filePath"]: item for item in recents}
            self.assertIn(str(launched_file), paths)
            self.assertIn(str(image), paths)
            self.assertIn(str(desktop), paths)
            self.assertEqual(paths[str(desktop)]["fileName"], "Demo App")
            self.assertEqual(paths[str(desktop)]["fileKind"], "Aplicativo")
            self.assertEqual(paths[str(desktop)]["recentSource"], "launch")
            self.assertEqual(paths[str(image)]["recentSource"], "xbel")
            self.assertTrue(paths[str(image)]["filePreviewUrl"].endswith("photo%20%231.png"))

    def test_merged_recents_dedupes_by_newest_access(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            target = root / "same.txt"
            target.write_text("x")
            finder_path = root / "finder-recents.json"
            launch_path = root / "history.jsonl"
            xbel_path = root / "missing.xbel"
            finder_path.write_text(
                json.dumps([{"fileName": "Old Name", "filePath": str(target), "lastAccessed": 10}]),
                encoding="utf-8",
            )
            launch_path.write_text(
                json.dumps({
                    "timestamp_ms": 300,
                    "kind": "file",
                    "target": str(target),
                    "argv": ["xdg-open", str(target)],
                    "status": "ok",
                }) + "\n",
                encoding="utf-8",
            )

            recents = helper.merged_recents(str(finder_path), str(launch_path), str(xbel_path), limit=10)

            self.assertEqual(len([item for item in recents if item["filePath"] == str(target)]), 1)
            self.assertEqual(recents[0]["lastAccessed"], 300)

    def test_merged_recents_scans_unordered_xbel_before_limiting(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            finder_path = root / "finder-recents.json"
            launch_path = root / "history.jsonl"
            xbel_path = root / "recently-used.xbel"
            finder_path.write_text("[]", encoding="utf-8")
            launch_path.write_text("", encoding="utf-8")
            bookmarks = []
            for i in range(8):
                path = root / f"old-{i}.png"
                path.write_text("old")
                bookmarks.append(f'<bookmark href="{helper._file_url(path)}" visited="2026-01-01T00:00:0{i}Z" />')
            newest = root / "newest.png"
            newest.write_text("new")
            bookmarks.append(f'<bookmark href="{helper._file_url(newest)}" visited="2026-02-01T00:00:00Z" />')
            xbel_path.write_text("<xbel>" + "\n".join(bookmarks) + "</xbel>", encoding="utf-8")

            recents = helper.merged_recents(str(finder_path), str(launch_path), str(xbel_path), limit=3)

            self.assertEqual(recents[0]["filePath"], str(newest))
            self.assertEqual(len(recents), 3)

    def test_merged_recents_skips_duplicate_launch_history_until_unique_limit(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            finder_path = root / "finder-recents.json"
            launch_path = root / "history.jsonl"
            xbel_path = root / "missing.xbel"
            repeated = root / "kitty.desktop"
            unique = root / "photo.png"
            repeated.write_text("[Desktop Entry]\nType=Application\nName=Kitty\nExec=kitty\n", encoding="utf-8")
            unique.write_text("png")
            finder_path.write_text("[]", encoding="utf-8")
            records = []
            for i in range(20):
                records.append(json.dumps({
                    "timestamp_ms": 1000 + i,
                    "kind": "desktop",
                    "target": "kitty",
                    "argv": ["gio", "launch", str(repeated)],
                    "status": "ok",
                }))
            records.insert(0, json.dumps({
                "timestamp_ms": 900,
                "kind": "file",
                "target": str(unique),
                "argv": ["xdg-open", str(unique)],
                "status": "ok",
            }))
            launch_path.write_text("\n".join(records), encoding="utf-8")

            recents = helper.merged_recents(str(finder_path), str(launch_path), str(xbel_path), limit=2)

            self.assertEqual({item["filePath"] for item in recents}, {str(repeated), str(unique)})

    def test_merged_recents_ignores_malformed_launch_timestamp(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            target = root / "file.txt"
            target.write_text("x")
            finder_path = root / "finder-recents.json"
            launch_path = root / "history.jsonl"
            xbel_path = root / "missing.xbel"
            finder_path.write_text("[]", encoding="utf-8")
            launch_path.write_text(json.dumps({
                "timestamp_ms": "not-a-number",
                "kind": "file",
                "target": str(target),
                "argv": ["xdg-open", str(target)],
                "status": "ok",
            }) + "\n", encoding="utf-8")

            recents = helper.merged_recents(str(finder_path), str(launch_path), str(xbel_path), limit=10)

            self.assertEqual(recents[0]["filePath"], str(target))
            self.assertEqual(recents[0]["lastAccessed"], target.stat().st_mtime_ns // 1_000_000)

class DirectoryMonitorTests(unittest.TestCase):
    def event_bytes(self, mask):
        return struct.pack("iIII", 1, mask, 0, 0)

    def test_created_file_emits_refresh_but_attrib_alone_does_not(self):
        self.assertTrue(helper._should_emit_directory_change([helper.IN_CREATE]))
        self.assertFalse(helper._should_emit_directory_change([helper.IN_ATTRIB]))

    def test_created_directory_still_emits_refresh(self):
        self.assertTrue(helper._should_emit_directory_change([helper.IN_CREATE | helper.IN_ISDIR]))

    def test_close_write_or_moved_to_emits_thumbnail_refresh(self):
        self.assertTrue(helper._should_emit_directory_change([helper.IN_CLOSE_WRITE]))
        self.assertTrue(helper._should_emit_directory_change([helper.IN_MOVED_TO]))

    def test_delete_and_directory_self_events_still_emit_refresh(self):
        self.assertTrue(helper._should_emit_directory_change([helper.IN_DELETE]))
        self.assertTrue(helper._should_emit_directory_change([helper.IN_DELETE_SELF]))

class ArchiveHelperTests(unittest.TestCase):
    def test_password_stdin_reader_strips_line_endings(self):
        original_stdin = sys.stdin
        try:
            sys.stdin = io.StringIO("secret\r\n")
            self.assertEqual(helper._read_password_from_stdin(), "secret")
        finally:
            sys.stdin = original_stdin

    def test_count_extracted_entries_matches_archive_file_entries(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            dest = root / "dest"
            (dest / "nested").mkdir(parents=True)
            (dest / "nested" / "one.txt").write_text("1")
            (dest / "two.txt").write_text("2")

            self.assertEqual(helper._count_extracted_entries(dest), 2)

    def test_count_extracted_bytes_ignores_directories(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            dest = root / "dest"
            (dest / "nested").mkdir(parents=True)
            (dest / "nested" / "one.bin").write_bytes(b"123")
            (dest / "two.bin").write_bytes(b"45")

            self.assertEqual(helper._count_extracted_bytes(dest), 5)

    def test_archive_password_args_are_passed_to_tools(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            archive = root / "private.7z"
            archive.write_bytes(b"x")

            captured = {}

            def fake_run(cmd, **kwargs):
                captured["cmd"] = cmd
                return subprocess.CompletedProcess(cmd, 0, b"", b"")

            helper.extract_archive(
                str(archive),
                "dest",
                password="secret",
                run_cmd=fake_run,
                list_runner=lambda *a, **k: ["one.txt", "two.txt"],
                which_runner=lambda name: "/usr/bin/7z" if name == "7z" else None,
            )

            self.assertIn("-psecret", captured["cmd"])

    def test_extract_archive_emits_password_required_without_password(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            archive = root / "private.zip"
            archive.write_bytes(b"x")

            buf = io.StringIO()
            with self.assertRaises(SystemExit) as raised:
                with redirect_stdout(buf):
                    helper.extract_archive(
                        str(archive),
                        "dest",
                        run_cmd=lambda *a, **k: subprocess.CompletedProcess([], 0, b"", b""),
                        list_runner=lambda *a, **k: ["one.txt"],
                        password_probe=lambda path: True,
                        which_runner=lambda name: "/usr/bin/" + name if name in ("unzip", "7z") else None,
                    )

            self.assertEqual(raised.exception.code, 3)
            event = json.loads(buf.getvalue().splitlines()[-1])
            self.assertEqual(event["event"], "password_required")
            self.assertEqual(event["mode"], "extract")
            self.assertFalse((root / "dest").exists())

    def test_extract_archive_emits_eta_progress_events(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            archive = root / "archive.zip"
            archive.write_bytes(b"x")

            tick = iter([100.0, 102.0, 104.0])

            def fake_run(cmd, **kwargs):
                destination = Path(cmd[-1])
                (destination / "one.txt").write_text("1")
                (destination / "two.txt").write_text("2")
                return subprocess.CompletedProcess(cmd, 0, b"", b"")

            buf = io.StringIO()
            with redirect_stdout(buf):
                helper.extract_archive(
                    str(archive),
                    "dest",
                    run_cmd=fake_run,
                    list_runner=lambda *a, **k: ["one.txt", "two.txt", "three.txt", "four.txt"],
                    now=lambda: next(tick),
                    which_runner=lambda name: "/usr/bin/" + name if name in ("unzip", "7z") else None,
                )

            events = [json.loads(line) for line in buf.getvalue().splitlines() if line.strip()]
            progress = [event for event in events if event["event"] == "progress"]
            self.assertTrue(progress)
            self.assertEqual(progress[-1]["done"], 4)
            self.assertEqual(progress[-1]["total"], 4)
            self.assertIn("eta_seconds", progress[-1])
            self.assertIn("bytes_done", progress[-1])
            self.assertIn("bytes_total", progress[-1])

    def test_tar_archives_extract_without_prelisting(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            source = root / "source"
            source.mkdir()
            (source / "one.txt").write_text("1", encoding="utf-8")
            (source / "two.txt").write_text("22", encoding="utf-8")
            archive = root / "archive.tar.bz2"
            with tarfile.open(archive, "w:bz2") as tar:
                tar.add(source, arcname="source")

            original_lister = helper._list_archive_entries
            helper._list_archive_entries = lambda *a, **k: (_ for _ in ()).throw(AssertionError("tar prelist called"))
            try:
                buf = io.StringIO()
                with redirect_stdout(buf):
                    helper.extract_archive(
                        str(archive),
                        "dest",
                        password_probe=lambda path: False,
                    )
            finally:
                helper._list_archive_entries = original_lister

            self.assertEqual((root / "dest" / "source" / "one.txt").read_text(encoding="utf-8"), "1")
            self.assertEqual((root / "dest" / "source" / "two.txt").read_text(encoding="utf-8"), "22")
            events = [json.loads(line) for line in buf.getvalue().splitlines() if line.strip()]
            self.assertEqual(events[0]["event"], "start")
            self.assertEqual(events[-1]["event"], "done")
            self.assertEqual(events[-1]["done"], 2)
            self.assertEqual(events[-1]["total"], 2)

    def test_archive_progress_uses_entry_bytes_for_single_large_file(self):
        payload = helper._archive_progress_payload(
            "extract",
            done=0,
            total=1,
            start_time=100.0,
            now=lambda: 105.0,
            bytes_done=50,
            bytes_total=200,
        )

        self.assertEqual(payload["percent"], 25)
        self.assertEqual(payload["bytes_done"], 50)
        self.assertEqual(payload["bytes_total"], 200)
        self.assertIn("eta_seconds", payload)

    def test_extract_archive_ask_policy_reports_existing_destination(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            archive = root / "archive.zip"
            archive.write_bytes(b"x")
            (root / "dest").mkdir()

            buf = io.StringIO()
            with self.assertRaises(SystemExit) as raised:
                with redirect_stdout(buf):
                    helper.extract_archive(
                        str(archive),
                        "dest",
                        conflict_policy="ask",
                        password_probe=lambda path: False,
                        which_runner=lambda name: "/usr/bin/unzip" if name == "unzip" else None,
                    )

            self.assertEqual(raised.exception.code, 4)
            event = json.loads(buf.getvalue().splitlines()[-1])
            self.assertEqual(event["event"], "conflict")
            self.assertEqual(event["destination"], str(root / "dest"))

    def test_extract_archive_merge_uses_existing_destination(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            archive = root / "archive.zip"
            archive.write_bytes(b"x")
            dest = root / "dest"
            dest.mkdir()
            (dest / "old.txt").write_text("old")
            captured = {}

            def fake_run(cmd, **kwargs):
                captured["cmd"] = cmd
                (dest / "new.txt").write_text("new")
                return subprocess.CompletedProcess(cmd, 0, b"", b"")

            helper.extract_archive(
                str(archive),
                "dest",
                conflict_policy="merge",
                run_cmd=fake_run,
                list_runner=lambda *a, **k: ["new.txt"],
                password_probe=lambda path: False,
                which_runner=lambda name: "/usr/bin/unzip" if name == "unzip" else None,
            )

            self.assertEqual(Path(captured["cmd"][-1]), dest)
            self.assertTrue((dest / "old.txt").exists())
            self.assertTrue((dest / "new.txt").exists())

    def test_extract_archive_overwrite_restores_destination_on_failure(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            archive = root / "archive.zip"
            archive.write_bytes(b"x")
            dest = root / "dest"
            dest.mkdir()
            (dest / "old.txt").write_text("old")

            def fake_run(cmd, **kwargs):
                raise subprocess.CalledProcessError(2, cmd, stderr=b"boom")

            with self.assertRaises(SystemExit):
                helper.extract_archive(
                    str(archive),
                    "dest",
                    conflict_policy="overwrite",
                    run_cmd=fake_run,
                    list_runner=lambda *a, **k: ["new.txt"],
                    password_probe=lambda path: False,
                    which_runner=lambda name: "/usr/bin/unzip" if name == "unzip" else None,
                )

            self.assertTrue((dest / "old.txt").exists())

    def test_extract_archive_merge_failure_keeps_existing_destination(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            archive = root / "archive.zip"
            archive.write_bytes(b"x")
            dest = root / "dest"
            dest.mkdir()
            (dest / "old.txt").write_text("old")

            def fake_run(cmd, **kwargs):
                raise subprocess.CalledProcessError(2, cmd, stderr=b"boom")

            with self.assertRaises(SystemExit):
                helper.extract_archive(
                    str(archive),
                    "dest",
                    conflict_policy="merge",
                    run_cmd=fake_run,
                    list_runner=lambda *a, **k: ["new.txt"],
                    password_probe=lambda path: False,
                    which_runner=lambda name: "/usr/bin/unzip" if name == "unzip" else None,
                )

            self.assertTrue((dest / "old.txt").exists())

    def test_extract_archive_emits_json_and_unique_destination(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            archive = root / "arquivo 😀.zip"
            archive.write_bytes(b"x")
            (root / "out").mkdir()
            (root / "out 2").mkdir()
            (root / "out 3").symlink_to(root / "missing")

            calls = []
            buf = io.StringIO()
            with redirect_stdout(buf):
                helper.extract_archive(
                    str(archive),
                    "out",
                    run_cmd=lambda cmd, **kwargs: calls.append(cmd) or subprocess.CompletedProcess(cmd, 0, b"", b""),
                    password_probe=lambda path: False,
                    which_runner=lambda name: "/usr/bin/" + name if name in ("unzip", "tar", "bsdtar") else None,
            )
            lines = [json.loads(line) for line in buf.getvalue().splitlines() if line.strip()]
            self.assertEqual(lines[0]["event"], "start")
            self.assertEqual(lines[-1]["event"], "done")
            self.assertTrue(lines[0]["destination"].endswith("out 4"))
            self.assertEqual(lines[-1]["percent"], 100)
            self.assertTrue(calls)

    def test_extract_archive_rejects_unsafe_destination_name(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            archive = root / "archive.zip"
            archive.write_bytes(b"x")
            buf = io.StringIO()

            with self.assertRaises(SystemExit):
                with redirect_stdout(buf):
                    helper.extract_archive(
                        str(archive),
                        "../escape",
                        run_cmd=lambda *a, **k: subprocess.CompletedProcess([], 0, b"", b""),
                        list_runner=lambda *a, **k: ["one.txt"],
                        password_probe=lambda path: False,
                        which_runner=lambda name: "/usr/bin/unzip" if name == "unzip" else None,
                    )

            self.assertFalse((root.parent / "escape").exists())
            events = [json.loads(line) for line in buf.getvalue().splitlines() if line.strip()]
            self.assertEqual(events[0]["event"], "error")


    def test_extract_archive_rejects_absolute_entry(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            archive = root / "archive.zip"
            archive.write_bytes(b"x")
            buf = io.StringIO()
            with self.assertRaises(SystemExit):
                with redirect_stdout(buf):
                    helper.extract_archive(
                        str(archive),
                        "dest",
                        run_cmd=lambda *a, **k: subprocess.CompletedProcess([], 0, b"", b""),
                        list_runner=lambda *a, **k: ["/etc/passwd"],
                        password_probe=lambda path: False,
                        which_runner=lambda name: "/usr/bin/unzip" if name == "unzip" else None,
                    )
            self.assertFalse((root / "dest").exists())
            events = [json.loads(line) for line in buf.getvalue().splitlines() if line.strip()]
            self.assertTrue(events)
            self.assertEqual(events[0]["event"], "error")

    def test_extract_archive_rejects_dotdot_entry(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            archive = root / "archive.zip"
            archive.write_bytes(b"x")
            buf = io.StringIO()
            with self.assertRaises(SystemExit):
                with redirect_stdout(buf):
                    helper.extract_archive(
                        str(archive),
                        "dest",
                        run_cmd=lambda *a, **k: subprocess.CompletedProcess([], 0, b"", b""),
                        list_runner=lambda *a, **k: ["../escape.txt"],
                        password_probe=lambda path: False,
                        which_runner=lambda name: "/usr/bin/unzip" if name == "unzip" else None,
                    )
            self.assertFalse((root / "dest").exists())
            events = [json.loads(line) for line in buf.getvalue().splitlines() if line.strip()]
            self.assertTrue(events)
            self.assertEqual(events[0]["event"], "error")
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

    def test_compress_folder_zip_emits_done_event_and_writes_next_to_folder(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            folder = root / "pasta"
            folder.mkdir()
            (folder / "one.txt").write_text("1", encoding="utf-8")
            calls = []

            def fake_run(cmd, **kwargs):
                calls.append((cmd, kwargs))
                Path(cmd[2]).write_bytes(b"zip")
                return subprocess.CompletedProcess(cmd, 0, b"", b"")

            buf = io.StringIO()
            with redirect_stdout(buf):
                helper.compress_folder(
                    str(folder),
                    "zip",
                    run_cmd=fake_run,
                    which_runner=lambda name: "/usr/bin/zip" if name == "zip" else None,
                )

            events = [json.loads(line) for line in buf.getvalue().splitlines() if line.strip()]
            destination = root / "pasta.zip"
            self.assertEqual(calls[0][0][:3], ["zip", "-qr", str(destination)])
            self.assertEqual(calls[0][1]["cwd"], str(root))
            self.assertTrue(destination.exists())
            self.assertEqual(events[-1]["event"], "done")
            self.assertEqual(events[-1]["destination"], str(destination))
            self.assertEqual(events[-1]["percent"], 100)

    def test_compress_folder_tar_uses_unique_destination(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            folder = root / "pasta"
            folder.mkdir()
            (root / "pasta.tar").write_bytes(b"old")
            calls = []

            def fake_run(cmd, **kwargs):
                calls.append((cmd, kwargs))
                Path(cmd[2]).write_bytes(b"tar")
                return subprocess.CompletedProcess(cmd, 0, b"", b"")

            buf = io.StringIO()
            with redirect_stdout(buf):
                helper.compress_folder(
                    str(folder),
                    "tar",
                    run_cmd=fake_run,
                    which_runner=lambda name: "/usr/bin/tar" if name == "tar" else None,
                )

            events = [json.loads(line) for line in buf.getvalue().splitlines() if line.strip()]
            destination = root / "pasta 2.tar"
            self.assertEqual(calls[0][0][:3], ["tar", "-cf", str(destination)])
            self.assertTrue(destination.exists())
            self.assertEqual(events[0]["destination"], str(destination))
            self.assertEqual(events[-1]["event"], "done")

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
