#!/usr/bin/env python3

import importlib.util
import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).with_name("storage.py")
spec = importlib.util.spec_from_file_location("storage_bridge", MODULE_PATH)
storage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(storage)


class StorageAutoRefreshTest(unittest.TestCase):
    def test_missing_cache_needs_auto_refresh(self):
        self.assertTrue(storage.cache_needs_auto_refresh({"cache_exists": False}))

    def test_stale_cache_needs_auto_refresh(self):
        self.assertTrue(storage.cache_needs_auto_refresh({
            "cache_exists": True,
            "cache_updated_ago_seconds": storage.AUTO_REFRESH_AFTER_SECONDS + 1,
        }))

    def test_fresh_cache_does_not_need_auto_refresh(self):
        self.assertFalse(storage.cache_needs_auto_refresh({
            "cache_exists": True,
            "cache_updated_ago_seconds": 10,
        }))

    def test_start_auto_refresh_spawns_background_worker_once(self):
        with tempfile.TemporaryDirectory() as tmp:
            state_dir = Path(tmp)
            with mock.patch.object(storage, "STATE_DIR", state_dir), \
                    mock.patch.object(storage, "REFRESH_STATUS", state_dir / "storage-refresh.json"), \
                    mock.patch.object(storage, "REFRESH_LOCK", state_dir / "storage-refresh.lock"), \
                    mock.patch.object(storage, "REFRESH_LOG", state_dir / "storage-refresh.log"), \
                    mock.patch.object(storage, "refresh_running", return_value=False), \
                    mock.patch.object(storage.subprocess, "Popen") as popen:
                popen.return_value.pid = 12345
                started = storage.start_auto_refresh(Path("/tmp/sense.py"), "stale-cache")

        self.assertTrue(started)
        self.assertEqual(popen.call_count, 1)
        self.assertIn("refresh-background", popen.call_args.args[0])

    def test_json_missing_cache_with_backend_starts_auto_refresh(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            cache_db = root / "missing-cache.db"
            sense_script = root / "sense.py"
            sense_script.write_text("# fake\n", encoding="utf-8")
            stdout = io.StringIO()
            completed = storage.subprocess.CompletedProcess(
                ["python3", str(sense_script), "json"],
                0,
                stdout=json.dumps({"data": []}),
                stderr="",
            )

            with mock.patch.object(storage, "CACHE_DB", cache_db), \
                    mock.patch.object(storage.subprocess, "run", return_value=completed), \
                    mock.patch.object(storage, "compsize_stats", return_value={"exact": False}), \
                    mock.patch.object(storage, "refresh_status", return_value={"running": False}), \
                    mock.patch.object(storage, "start_auto_refresh", return_value=True) as start:
                with redirect_stdout(stdout):
                    storage.print_sense_json(sense_script)

            payload = json.loads(stdout.getvalue())
            start.assert_called_once_with(sense_script, "missing-cache")
            self.assertTrue(payload["refresh_started"])
            self.assertTrue(payload["cache_stale"])
            self.assertFalse(payload["cache_exists"])

    def test_json_does_not_start_duplicate_refresh_when_already_running(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            cache_db = root / "missing-cache.db"
            sense_script = root / "sense.py"
            sense_script.write_text("# fake\n", encoding="utf-8")
            completed = storage.subprocess.CompletedProcess(
                ["python3", str(sense_script), "json"],
                0,
                stdout=json.dumps({"data": []}),
                stderr="",
            )
            stdout = io.StringIO()

            with mock.patch.object(storage, "CACHE_DB", cache_db), \
                    mock.patch.object(storage.subprocess, "run", return_value=completed), \
                    mock.patch.object(storage, "compsize_stats", return_value={"exact": False}), \
                    mock.patch.object(storage, "refresh_status", return_value={"running": True, "reason": "missing-cache"}), \
                    mock.patch.object(storage, "start_auto_refresh") as start:
                with redirect_stdout(stdout):
                    storage.print_sense_json(sense_script)

            payload = json.loads(stdout.getvalue())
            start.assert_not_called()
            self.assertTrue(payload["refresh_running"])
            self.assertFalse(payload["refresh_started"])
            self.assertEqual(payload["refresh_reason"], "missing-cache")

    def test_missing_backend_falls_back_without_auto_refresh(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache_db = Path(tmp) / "missing-cache.db"
            stdout = io.StringIO()

            with mock.patch.object(storage, "CACHE_DB", cache_db), \
                    mock.patch.object(storage, "refresh_status", return_value={"running": False}), \
                    mock.patch.object(storage, "start_auto_refresh") as start:
                with redirect_stdout(stdout):
                    code = storage.print_cached_json()

            payload = json.loads(stdout.getvalue())
            self.assertEqual(code, 0)
            start.assert_not_called()
            self.assertEqual(payload["error"], "No cache found")
            self.assertFalse(payload["refresh_started"])
            self.assertFalse(payload["refresh_running"])
            self.assertTrue(payload["cache_stale"])

    def test_background_refresh_only_runs_storage_scan_by_default(self):
        with tempfile.TemporaryDirectory() as tmp:
            state_dir = Path(tmp)
            with mock.patch.object(storage, "STATE_DIR", state_dir), \
                    mock.patch.object(storage, "REFRESH_STATUS", state_dir / "storage-refresh.json"), \
                    mock.patch.object(storage, "REFRESH_LOCK", state_dir / "storage-refresh.lock"), \
                    mock.patch.object(storage, "REFRESH_LOG", state_dir / "storage-refresh.log"), \
                    mock.patch.object(storage.subprocess, "run") as run:
                run.return_value.returncode = 0
                run.return_value.stderr = ""

                code = storage.run_refresh_background(Path("/tmp/sense.py"), "stale-cache")

        self.assertEqual(code, 0)
        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(len(commands), 1)
        self.assertEqual(commands[0][-2:], ["scan", "--quiet"])
        self.assertNotIn("index-home", commands[0])

    def test_parse_compsize_bytes_reports_zstd_savings(self):
        output = """
Processed 3 files.
Type       Perc     Disk Usage   Uncompressed Referenced
TOTAL       50%           1024           2048       2048
none       100%            512            512        512
zstd        33%            512           1536       1536
"""

        stats = storage.parse_compsize_bytes(output)

        self.assertEqual(stats["compressed_saved"], 1024)
        self.assertEqual(stats["zstd_saved"], 1024)
        self.assertEqual(stats["compressed_total"], 1536)
        self.assertTrue(stats["exact"])

    def test_parse_compsize_human_output_reports_zstd_compressed_total(self):
        output = """
Processed 1268983 files, 2252820 regular extents (2475235 refs), 446793 inline.
Type       Perc     Disk Usage   Uncompressed Referenced
TOTAL       85%      517G         607G         623G
none       100%      475G         475G         479G
zstd        31%       42G         132G         144G
prealloc   100%       23M          23M          26M
"""

        stats = storage.parse_compsize_output(output)

        self.assertEqual(stats["compressed_total"], 132_000_000_000)
        self.assertEqual(stats["zstd_disk_usage"], 42_000_000_000)
        self.assertEqual(stats["zstd_saved"], 90_000_000_000)
        self.assertTrue(stats["exact"])

    def test_parse_compsize_human_output_sums_root_and_home_blocks(self):
        output = """
Processed 496690 files, 251166 regular extents (340265 refs), 285965 inline.
Type       Perc     Disk Usage   Uncompressed Referenced
TOTAL       69%       23G          33G          41G
none       100%       17G          17G          19G
zstd        35%      5.3G          15G          21G
Processed 1264021 files, 2256503 regular extents (2494786 refs), 446844 inline.
Type       Perc     Disk Usage   Uncompressed Referenced
TOTAL       84%      511G         603G         620G
none       100%      469G         469G         472G
zstd        31%       42G         134G         147G
prealloc   100%       23M          23M          25M
"""

        stats = storage.parse_compsize_output(output)

        self.assertEqual(stats["compressed_total"], 149_000_000_000)
        self.assertEqual(stats["zstd_disk_usage"], 47_300_000_000)
        self.assertEqual(stats["zstd_saved"], 101_700_000_000)
        self.assertEqual(stats["by_algorithm"]["none"]["disk_usage"], 486_000_000_000)
        self.assertTrue(stats["exact"])


if __name__ == "__main__":
    unittest.main()
