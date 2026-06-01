#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import threading
import unittest
from pathlib import Path
from unittest import mock


SERVICE = Path(__file__).with_name("astrea_statusd.py")


def load_module():
    spec = importlib.util.spec_from_file_location("astrea_statusd_under_test", SERVICE)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


class AstreaStatusdTests(unittest.TestCase):
    def test_default_route_iface_prefers_lowest_metric_proc_route(self):
        statusd = load_module()
        route = """Iface\tDestination\tGateway\tFlags\tRefCnt\tUse\tMetric\tMask\tMTU\tWindow\tIRTT
wlan0\t00000000\t0164A8C0\t0003\t0\t0\t600\t00000000\t0\t0\t0
eno1\t00000000\t0164A8C0\t0003\t0\t0\t100\t00000000\t0\t0\t0
lo\t0000007F\t00000000\t0001\t0\t0\t0\t000000FF\t0\t0\t0
"""
        self.assertEqual(statusd.default_route_iface_from_proc(route), "eno1")

    def test_wifi_ssid_is_cached_between_network_samples(self):
        statusd = load_module()
        statusd.wifi_ssid_cache.clear()

        with mock.patch.object(statusd, "command_available", return_value=True), \
             mock.patch.object(statusd, "run_cmd") as run_cmd, \
             mock.patch.object(statusd.time, "monotonic", side_effect=[10.0, 12.0]):
            run_cmd.return_value.stdout = "AstreaNet\n"

            self.assertEqual(statusd.wifi_ssid_for_iface("wlan0"), "AstreaNet")
            self.assertEqual(statusd.wifi_ssid_for_iface("wlan0"), "AstreaNet")
            self.assertEqual(run_cmd.call_count, 1)

    def test_bluetooth_autoconnect_request_runs_in_background_once(self):
        statusd = load_module()
        started = threading.Event()
        release = threading.Event()
        calls = []

        def slow_autoconnect():
            calls.append(True)
            started.set()
            release.wait(1)

        with mock.patch.object(statusd, "bluetooth_autoconnect", side_effect=slow_autoconnect):
            self.assertTrue(statusd.request_bluetooth_autoconnect())
            self.assertFalse(statusd.request_bluetooth_autoconnect())
            self.assertTrue(started.wait(0.5))
            thread = statusd.bluetooth_autoconnect_thread
            self.assertIsNotNone(thread)
            release.set()
            thread.join(1)

        self.assertEqual(len(calls), 1)
        self.assertIsNone(statusd.bluetooth_autoconnect_thread)


if __name__ == "__main__":
    unittest.main()
