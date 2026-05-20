#!/usr/bin/env python3
from __future__ import annotations
import importlib.util
import sys
import tempfile, unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("state_json.py")
spec = importlib.util.spec_from_file_location("state_json_under_test", MODULE_PATH)
state_json = importlib.util.module_from_spec(spec)
sys.modules["state_json_under_test"] = state_json
assert spec and spec.loader
spec.loader.exec_module(state_json)

class StateJsonTests(unittest.TestCase):
    def test_write_rejects_invalid_json(self):
        with tempfile.TemporaryDirectory() as td:
            path=Path(td)/'a.json'
            with self.assertRaises(Exception):
                state_json.write_json_text(str(path), '{bad')

if __name__=='__main__':
    unittest.main()
