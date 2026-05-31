#!/usr/bin/env python3
import importlib.util
from importlib.machinery import SourceFileLoader
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("astrea-performance")


def load_module():
    loader = SourceFileLoader("astrea_performance_under_test", str(SCRIPT))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


class AstreaPerformanceTests(unittest.TestCase):
    def test_parse_scxctl_get_extracts_scheduler_and_mode(self):
        perf = load_module()
        parsed = perf.parse_scxctl_get("running Bpfland in Gaming mode\n")

        self.assertEqual(parsed["scheduler"], "bpfland")
        self.assertEqual(parsed["mode"], "gaming")
        self.assertTrue(parsed["active"])

    def test_scheduler_catalog_contains_user_facing_guidance(self):
        perf = load_module()
        catalog = perf.scheduler_catalog()
        bpfland = next(item for item in catalog if item["id"] == "bpfland")

        self.assertIn("Gaming", bpfland["best_for"])
        self.assertIn("interactive", bpfland["description"].lower())
        self.assertIn("pandemonium", {item["id"] for item in catalog})

    def test_default_config_tracks_sched_ext_preference(self):
        perf = load_module()

        self.assertEqual(perf.DEFAULT_CONFIG["scx_scheduler"], "bpfland")
        self.assertEqual(perf.DEFAULT_CONFIG["scx_mode"], "gaming")


if __name__ == "__main__":
    unittest.main()
