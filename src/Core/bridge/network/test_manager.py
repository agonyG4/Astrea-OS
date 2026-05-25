#!/usr/bin/env python3
import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest import mock


MANAGER = Path(__file__).with_name("manager.py")


def load_module():
    spec = importlib.util.spec_from_file_location("network_manager_under_test", MANAGER)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


class NetworkManagerTests(unittest.TestCase):
    def test_split_nmcli_fields_preserves_escaped_colons(self):
        manager = load_module()
        self.assertEqual(
            manager._split_nmcli_fields(r"yes:Studio\:Main:86:WPA2"),
            ["yes", "Studio:Main", "86", "WPA2"],
        )

    def test_parse_wifi_networks_deduplicates_by_strongest_signal(self):
        manager = load_module()
        out = """no:Astrea Fiber:55:WPA2
no:Astrea Fiber:92:WPA2
yes:Casa 5G:74:WPA2 WPA3
"""
        networks = manager._parse_wifi_networks(out)
        self.assertEqual([item["ssid"] for item in networks], ["Casa 5G", "Astrea Fiber"])
        self.assertTrue(networks[0]["active"])
        self.assertEqual(networks[1]["signal"], 92)

    def test_wifi_payload_falls_back_to_simulation_without_wifi_device(self):
        manager = load_module()
        with tempfile.TemporaryDirectory() as tmpdir:
            manager.STATE_DIR = Path(tmpdir)
            manager.SIM_WIFI_STATE = Path(tmpdir) / "wifi-sim.json"
            with mock.patch.object(manager, "get_wifi_device", return_value=None):
                payload = manager._wifi_payload()

        self.assertTrue(payload["success"])
        self.assertTrue(payload["simulated"])
        self.assertFalse(payload["available"])
        self.assertGreaterEqual(len(payload["networks"]), 3)
        self.assertTrue(any(item["active"] for item in payload["networks"]))


if __name__ == "__main__":
    unittest.main()
