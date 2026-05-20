#!/usr/bin/env python3
from __future__ import annotations
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("astrea_shared.py")
spec = importlib.util.spec_from_file_location("astrea_shared_under_test", MODULE_PATH)
astrea_shared = importlib.util.module_from_spec(spec)
sys.modules["astrea_shared_under_test"] = astrea_shared
assert spec and spec.loader
spec.loader.exec_module(astrea_shared)


class SharedTests(unittest.TestCase):
    def test_error_payload_shape(self):
        payload = astrea_shared.error_payload("x", code="bad")
        self.assertEqual(payload, {"ok": False, "code": "bad", "message": "x"})

    def test_atomic_write_json(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "a.json"
            astrea_shared.atomic_write_json(p, {"k": 1}, indent=None)
            self.assertIn('"k": 1', p.read_text(encoding="utf-8"))

if __name__ == "__main__":
    unittest.main()
