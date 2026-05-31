#!/usr/bin/env python3

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


REGION_PATH = Path(__file__).with_name("region.py")
spec = importlib.util.spec_from_file_location("region_under_test", REGION_PATH)
region = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(region)


class RegionSettingsTests(unittest.TestCase):
    def test_normalize_config_adds_region_defaults(self):
        normalized = region.normalize_config({"language": "pt_BR"})

        self.assertEqual(normalized["language"], "pt_BR")
        self.assertEqual(normalized["region"]["country_code"], "BR")
        self.assertEqual(normalized["region"]["time_format"], "system")
        self.assertTrue(normalized["region"]["automatic_location"])

    def test_effective_time_format_resolves_system_from_country(self):
        self.assertEqual(region.effective_time_format({"country_code": "BR", "time_format": "system"}), "24h")
        self.assertEqual(region.effective_time_format({"country_code": "US", "time_format": "system"}), "12h")
        self.assertEqual(region.effective_time_format({"country_code": "BR", "time_format": "12h"}), "12h")
        self.assertEqual(region.effective_time_format({"country_code": "US", "time_format": "24h"}), "24h")

    def test_save_config_disables_geoclue_when_auto_location_turns_off(self):
        commands = []

        def runner(command, timeout=5.0):
            commands.append(command)
            if command[:2] == ["systemctl", "list-unit-files"]:
                return 0, "geoclue.service enabled\n", ""
            if command[:2] == ["systemctl", "mask"]:
                return 0, "", ""
            return 0, "", ""

        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "settings.json"
            path.write_text(json.dumps({
                "language": "en_US",
                "region": {"automatic_location": True},
            }), encoding="utf-8")

            result = region.save_config(
                {
                    "language": "en_US",
                    "region": {
                        "country_code": "US",
                        "time_format": "12h",
                        "automatic_location": False,
                    },
                },
                path=path,
                runner=runner,
            )

        self.assertFalse(result["config"]["region"]["automatic_location"])
        self.assertIn(["systemctl", "mask", "--now", "geoclue.service"], commands)
        self.assertEqual(result["geolocation_service"]["action"], "disable")


if __name__ == "__main__":
    unittest.main()
