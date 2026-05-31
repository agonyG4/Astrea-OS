#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SERVICE = Path(__file__).with_name("astrea_latencyd.py")


def load_module():
    spec = importlib.util.spec_from_file_location("astrea_latencyd_under_test", SERVICE)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class AstreaLatencydTests(unittest.TestCase):
    def test_write_state_persists_rollback_snapshot_for_crash_recovery(self):
        latencyd = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            state_file = Path(tmp) / "state.json"
            privileged_snapshot = {
                "governors": {"/sys/devices/system/cpu/cpufreq/policy0/scaling_governor": "schedutil"},
                "intel_no_turbo": "1",
            }
            daemon = latencyd.LatencyDaemon(
                active=True,
                previous_profile="balanced",
                previous_governors={
                    "/sys/devices/system/cpu/cpufreq/policy0/scaling_governor": "schedutil"
                },
                previous_no_turbo="1",
                privileged_snapshot=privileged_snapshot,
            )

            with mock.patch.object(latencyd, "state_path", return_value=state_file), \
                 mock.patch.object(latencyd, "read_power_profile", return_value="performance"), \
                 mock.patch.object(
                     latencyd,
                     "snapshot_cpu_governors",
                     return_value={
                         "/sys/devices/system/cpu/cpufreq/policy0/scaling_governor": "performance"
                     },
                 ):
                daemon.write_state()

            payload = json.loads(state_file.read_text(encoding="utf-8"))
            self.assertEqual(payload["rollback"]["previous_profile"], "balanced")
            self.assertEqual(payload["rollback"]["privileged_snapshot"], privileged_snapshot)
            self.assertEqual(
                payload["rollback"]["previous_governors"],
                {"/sys/devices/system/cpu/cpufreq/policy0/scaling_governor": "schedutil"},
            )
            self.assertEqual(payload["rollback"]["previous_no_turbo"], "1")

    def test_recover_pending_rollback_restores_previous_boost_snapshot(self):
        latencyd = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            state_file = Path(tmp) / "state.json"
            privileged_snapshot = {
                "governors": {"/sys/devices/system/cpu/cpufreq/policy0/scaling_governor": "schedutil"},
                "intel_no_turbo": "1",
            }
            state_file.write_text(
                json.dumps(
                    {
                        "active": True,
                        "rollback": {
                            "previous_profile": "balanced",
                            "previous_governors": {},
                            "previous_no_turbo": None,
                            "privileged_snapshot": privileged_snapshot,
                        },
                    }
                )
                + "\n",
                encoding="utf-8",
            )

            with mock.patch.object(latencyd, "state_path", return_value=state_file), \
                 mock.patch.object(latencyd, "set_power_profile", return_value="power profile -> balanced"), \
                 mock.patch.object(latencyd, "privileged_restore", return_value=["burst helper restore ok"]) as restore, \
                 mock.patch.object(latencyd, "append_history") as append_history, \
                 mock.patch.object(latencyd, "read_power_profile", return_value="balanced"), \
                 mock.patch.object(latencyd, "snapshot_cpu_governors", return_value={}):
                details = latencyd.recover_pending_rollback()

            restore.assert_called_once_with(privileged_snapshot)
            self.assertIn("recovered stale boost rollback", details)
            append_history.assert_called_once()
            self.assertEqual(append_history.call_args.args[0]["event"], "recover-rollback")


if __name__ == "__main__":
    unittest.main()
