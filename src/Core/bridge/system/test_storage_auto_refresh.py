#!/usr/bin/env python3

import importlib.util
import tempfile
import unittest
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


if __name__ == "__main__":
    unittest.main()
