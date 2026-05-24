#!/usr/bin/env python3
from __future__ import annotations
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

MODULE_PATH = Path(__file__).with_name("astrea_sessiond.py")
spec = importlib.util.spec_from_file_location("astrea_sessiond_under_test", MODULE_PATH)
sessiond = importlib.util.module_from_spec(spec)
sys.modules["astrea_sessiond_under_test"] = sessiond
assert spec and spec.loader
spec.loader.exec_module(sessiond)


class SessiondTests(unittest.TestCase):
    def test_domain_health(self):
        payload = sessiond.domain_state("health")
        self.assertTrue(payload["ok"])
        self.assertEqual(payload["domain"], "health")

    def test_unknown_domain(self):
        payload = sessiond.domain_state("nope")
        self.assertFalse(payload["ok"])
        self.assertEqual(payload["code"], "unknown_domain")

    def test_status_payload_shape(self):
        with tempfile.TemporaryDirectory() as td:
            status_path = Path(td) / "status.json"
            with mock.patch.object(sessiond, "STATUS_PATH", status_path):
                payload = sessiond.status_payload()
                self.assertTrue(payload["ok"])
                self.assertIn("running", payload)
                self.assertIn("socket_path", payload)

    def test_status_payload_reports_health_domain_only(self):
        payload = sessiond.status_payload()
        self.assertIn("health", payload["domains"])
        self.assertEqual(payload["domains"], sorted(payload["domains"]))

    def test_health_state_has_stable_contract(self):
        payload = sessiond.domain_state("health")
        self.assertEqual(payload["state"]["ok"], True)
        self.assertEqual(payload["state"]["domain"], "health")
        self.assertEqual(payload["state"]["version"], 1)
        self.assertIn("timestamp", payload["state"])

if __name__ == "__main__":
    unittest.main()
