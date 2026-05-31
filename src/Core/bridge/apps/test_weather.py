#!/usr/bin/env python3

import importlib.util
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


WEATHER_PATH = Path(__file__).with_name("weather.py")
spec = importlib.util.spec_from_file_location("weather_under_test", WEATHER_PATH)
weather = importlib.util.module_from_spec(spec)
sys.modules["weather_under_test"] = weather
assert spec and spec.loader
spec.loader.exec_module(weather)


class WeatherLocationTests(unittest.TestCase):
    def test_geocode_selection_honors_country_hint(self):
        results = [
            {
                "name": "Springfield",
                "country": "Canada",
                "country_code": "CA",
                "admin1": "Ontario",
                "population": 2_000_000,
            },
            {
                "name": "Springfield",
                "country": "United States",
                "country_code": "US",
                "admin1": "Illinois",
                "population": 100_000,
            },
        ]

        picked = weather.pick_geocode_result(results, "Springfield, United States")

        self.assertEqual(picked["country_code"], "US")

    def test_alert_sources_are_country_scoped(self):
        br_location = {"name": "Itajaí", "admin1": "Santa Catarina", "country_code": "BR"}
        us_location = {"name": "Springfield", "admin1": "Illinois", "country_code": "US"}

        with mock.patch.object(weather, "fetch_inmet_alerts", return_value=[{"source": "INMET"}]) as inmet:
            self.assertEqual(weather.fetch_weather_alerts(br_location), [{"source": "INMET"}])
            self.assertEqual(weather.fetch_weather_alerts(us_location), [])

        inmet.assert_called_once_with("Itajaí", "Santa Catarina")

    def test_empty_location_uses_ip_lookup(self):
        ip_location = {
            "name": "Florianópolis",
            "admin1": "Santa Catarina",
            "country": "Brasil",
            "country_code": "BR",
            "latitude": -27.59,
            "longitude": -48.55,
            "timezone": "America/Sao_Paulo",
            "location_source": "ip",
        }

        with mock.patch.object(weather, "automatic_location_enabled", return_value=True), \
             mock.patch.object(weather, "get_system_location", side_effect=weather.WeatherError("unavailable")), \
             mock.patch.object(weather, "get_ip_location", return_value=ip_location) as lookup:
            resolved = weather.resolve_location("")

        lookup.assert_called_once()
        self.assertEqual(resolved, ip_location)

    def test_empty_location_uses_system_location_before_ip(self):
        system_location = {
            "name": "Curitiba",
            "admin1": "Paraná",
            "country": "Brasil",
            "country_code": "BR",
            "latitude": -25.42,
            "longitude": -49.27,
            "timezone": "America/Sao_Paulo",
            "location_source": "system",
        }

        with mock.patch.object(weather, "automatic_location_enabled", return_value=True), \
             mock.patch.object(weather, "get_system_location", return_value=system_location) as system_lookup, \
             mock.patch.object(weather, "get_ip_location") as ip_lookup:
            resolved = weather.resolve_location("")

        system_lookup.assert_called_once()
        ip_lookup.assert_not_called()
        self.assertEqual(resolved, system_location)

    def test_empty_location_fails_when_automatic_location_is_disabled(self):
        with mock.patch.object(weather, "automatic_location_enabled", return_value=False), \
             mock.patch.object(weather, "get_ip_location") as ip_lookup:
            with self.assertRaises(weather.WeatherError):
                weather.resolve_location("")

        ip_lookup.assert_not_called()

    def test_region_time_format_supports_12_hour_clock(self):
        self.assertEqual(
            weather.format_local_time("2026-05-30T18:15", {"time_format": "12h"}),
            "6:15 PM",
        )

    def test_cache_dir_falls_back_when_default_is_read_only(self):
        original_cache_dir = weather.CACHE_DIR
        original_state_dir = weather.STATE_DIR
        original_cache_ready = weather._CACHE_READY
        real_makedirs = os.makedirs

        with tempfile.TemporaryDirectory() as tmp:
            blocked_cache = os.path.join(tmp, "blocked-cache")
            state_dir = os.path.join(tmp, "state")

            def fake_makedirs(path, exist_ok=False):
                if path == blocked_cache:
                    raise OSError(30, "Read-only file system")
                return real_makedirs(path, exist_ok=exist_ok)

            try:
                weather.CACHE_DIR = blocked_cache
                weather.STATE_DIR = state_dir
                weather._CACHE_READY = False
                with mock.patch.object(weather.os, "makedirs", side_effect=fake_makedirs):
                    weather.ensure_cache_dir()

                self.assertEqual(weather.CACHE_DIR, os.path.join(state_dir, "cache"))
                self.assertTrue(weather._CACHE_READY)
            finally:
                weather.CACHE_DIR = original_cache_dir
                weather.STATE_DIR = original_state_dir
                weather._CACHE_READY = original_cache_ready


if __name__ == "__main__":
    unittest.main()
