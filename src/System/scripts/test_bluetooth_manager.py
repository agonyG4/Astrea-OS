#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import io
import json
import tempfile
import time
import unittest
from contextlib import redirect_stdout
from pathlib import Path


SCRIPT = Path(__file__).with_name("bluetooth_manager.py")


def load_module():
    spec = importlib.util.spec_from_file_location("bluetooth_manager_under_test", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


class BluetoothManagerTests(unittest.TestCase):
    def test_status_command_publishes_shared_status_snapshot(self):
        bt = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            state = Path(tmp)
            bt.STATUS_CACHE_PATH = state / "status-cache.json"
            bt.SHARED_STATUS_PATH = state / "status" / "bluetooth.json"
            bt.get_status_payload = lambda: {
                "success": True,
                "powered": True,
                "connected_name": "Headset",
                "paired_devices": [
                    {
                        "mac": "AA:BB:CC:DD:EE:FF",
                        "name": "Headset",
                        "connected": True,
                    }
                ],
                "_cached_at": 123,
            }

            with redirect_stdout(io.StringIO()):
                bt.cmd_status()

            payload = json.loads(bt.SHARED_STATUS_PATH.read_text())
            self.assertTrue(payload["ok"])
            self.assertTrue(payload["powered"])
            self.assertEqual(payload["connected_name"], "Headset")
            self.assertNotIn("_cached_at", payload)

    def test_failed_autoconnect_sets_device_cooldown(self):
        bt = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            state = Path(tmp)
            bt.CONFIG_PATH = state / "autoconnect.json"
            bt.RUNTIME_PATH = state / "runtime.json"
            bt.STATUS_CACHE_PATH = state / "status-cache.json"
            bt.save_config(dict(bt.DEFAULT_CONFIG, retry_interval_sec=5))
            bt.save_runtime(dict(bt.DEFAULT_RUNTIME, last_attempt_ts=0))

            def fake_status():
                return {
                    "success": True,
                    "powered": True,
                    "connected_count": 0,
                    "paired_devices": [
                        {
                            "mac": "AA:BB:CC:DD:EE:FF",
                            "name": "Controller",
                            "connected": False,
                            "trusted": True,
                            "blocked": False,
                            "auto_connect": True,
                            "priority": 0,
                        }
                    ],
                    "config": bt.load_config(),
                    "runtime": bt.load_runtime(),
                }

            bt.get_status_payload = fake_status
            bt._run = lambda *args, **kwargs: type("Proc", (), {"stdout": "", "stderr": "Host is down"})()
            bt._device_is_connected = lambda _mac: False

            result = bt.run_autoconnect(False)
            runtime = bt.load_runtime()

            self.assertFalse(result["success"])
            self.assertEqual(result["reason"], "connect_failed")
            self.assertGreater(runtime["device_cooldowns"]["AA:BB:CC:DD:EE:FF"], int(time.time()))
            self.assertGreaterEqual(runtime["device_cooldowns"]["AA:BB:CC:DD:EE:FF"] - int(time.time()), bt.AUTOCONNECT_FAILURE_COOLDOWN_SEC - 2)

    def test_force_autoconnect_ignores_device_cooldown(self):
        bt = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            state = Path(tmp)
            bt.CONFIG_PATH = state / "autoconnect.json"
            bt.RUNTIME_PATH = state / "runtime.json"
            bt.STATUS_CACHE_PATH = state / "status-cache.json"
            bt.save_config(dict(bt.DEFAULT_CONFIG, retry_interval_sec=300))
            bt.save_runtime(
                dict(
                    bt.DEFAULT_RUNTIME,
                    last_attempt_ts=int(time.time()),
                    device_cooldowns={"AA:BB:CC:DD:EE:FF": int(time.time()) + 3600},
                )
            )

            attempts = []

            def fake_status():
                return {
                    "success": True,
                    "powered": True,
                    "connected_count": 0,
                    "paired_devices": [
                        {
                            "mac": "AA:BB:CC:DD:EE:FF",
                            "name": "Controller",
                            "connected": False,
                            "trusted": True,
                            "blocked": False,
                            "auto_connect": True,
                            "priority": 0,
                        }
                    ],
                    "config": bt.load_config(),
                    "runtime": bt.load_runtime(),
                }

            def fake_run(*args, **_kwargs):
                attempts.append(args)
                return type("Proc", (), {"stdout": "ok", "stderr": ""})()

            bt.get_status_payload = fake_status
            bt._run = fake_run
            bt._device_is_connected = lambda _mac: True

            result = bt.run_autoconnect(True)

            self.assertTrue(result["success"])
            self.assertEqual(result["reason"], "connected")
            self.assertTrue(attempts)


if __name__ == "__main__":
    unittest.main()
