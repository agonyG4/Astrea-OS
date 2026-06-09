#!/usr/bin/env python3

import importlib.util
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SERVICES_PATH = Path(__file__).with_name("services.py")
spec = importlib.util.spec_from_file_location("services_under_test", SERVICES_PATH)
services = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(services)


class AstreaServicesTests(unittest.TestCase):
    def test_list_services_ignores_transient_launch_units(self):
        commands = []

        def runner(command, timeout=5.0):
            commands.append(command)
            unit = command[-1]
            if command[:3] == ["systemctl", "--user", "list-unit-files"]:
                if unit == "astrea-launchd.service":
                    return 0, "astrea-launchd.service enabled\n", ""
                if unit == "astrea-weatherd.service":
                    return 0, "astrea-weatherd.service disabled\n", ""
                return 0, "0 unit files listed.\n", ""
            if command[:3] == ["systemctl", "--user", "is-active"]:
                return (0, "active\n", "") if unit == "astrea-launchd.service" else (3, "inactive\n", "")
            if command[:3] == ["systemctl", "--user", "is-enabled"]:
                return (0, "enabled\n", "") if unit == "astrea-launchd.service" else (1, "disabled\n", "")
            return 0, "", ""

        payload = services.list_services(runner=runner)
        units = [item["unit"] for item in payload["services"]]

        self.assertIn("astrea-launchd.service", units)
        self.assertIn("astrea-weatherd.service", units)
        self.assertNotIn("astrea-launch-123.service", units)
        launchd = next(item for item in payload["services"] if item["key"] == "launchd")
        self.assertTrue(launchd["available"])
        self.assertEqual(launchd["state"], "active")
        self.assertEqual(launchd["enabled_state"], "enabled")

    def test_set_service_enabled_runs_systemctl_enable_now(self):
        commands = []

        def runner(command, timeout=5.0):
            commands.append(command)
            if command[:3] == ["systemctl", "--user", "enable"]:
                return 0, "", ""
            if command[:3] == ["systemctl", "--user", "list-unit-files"]:
                return 0, f"{command[-1]} enabled\n", ""
            if command[:3] == ["systemctl", "--user", "is-active"]:
                return 0, "active\n", ""
            if command[:3] == ["systemctl", "--user", "is-enabled"]:
                return 0, "enabled\n", ""
            return 0, "", ""

        payload = services.set_service_enabled("weather", True, runner=runner)

        self.assertIn(["systemctl", "--user", "enable", "--now", "astrea-weatherd.service"], commands)
        self.assertTrue(payload["ok"])
        weather = next(item for item in payload["services"] if item["key"] == "weather")
        self.assertTrue(weather["enabled"])
        self.assertTrue(weather["active"])

    def test_set_service_enabled_rejects_unknown_key(self):
        with self.assertRaises(ValueError):
            services.set_service_enabled("astrea-launch-123", False, runner=lambda command, timeout=5.0: (0, "", ""))

    def test_file_fallback_reports_installed_enabled_unit_when_user_bus_is_blocked(self):
        def blocked_runner(command, timeout=5.0):
            return 1, "", "Failed to connect to user scope bus via local transport: Operation not permitted"

        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            unit_dir = home / ".config/systemd/user"
            wants_dir = unit_dir / "default.target.wants"
            wants_dir.mkdir(parents=True)
            (unit_dir / "astrea-status.service").write_text("[Unit]\nDescription=Astrea status cache service\n", encoding="utf-8")
            (wants_dir / "astrea-status.service").symlink_to(unit_dir / "astrea-status.service")

            with patch.dict(os.environ, {"HOME": str(home)}):
                payload = services.service_payload(services.SERVICE_BY_KEY["status"], runner=blocked_runner)

        self.assertTrue(payload["available"])
        self.assertTrue(payload["enabled"])
        self.assertEqual(payload["enabled_state"], "enabled")
        self.assertEqual(payload["state"], "unknown")

    def test_filechooser_portal_is_reported_as_on_demand_not_disabled(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            dbus_dir = home / ".local/share/dbus-1/services"
            portal_dir = home / ".local/share/xdg-desktop-portal/portals"
            dbus_dir.mkdir(parents=True)
            portal_dir.mkdir(parents=True)
            (dbus_dir / "org.freedesktop.impl.portal.desktop.astrea.service").write_text(
                "[D-BUS Service]\nName=org.freedesktop.impl.portal.desktop.astrea\n",
                encoding="utf-8",
            )
            (portal_dir / "astrea.portal").write_text(
                "[portal]\nDBusName=org.freedesktop.impl.portal.desktop.astrea\n",
                encoding="utf-8",
            )

            with patch.dict(os.environ, {"HOME": str(home)}):
                payload = services.service_payload(services.SERVICE_BY_KEY["portal"])

        self.assertTrue(payload["available"])
        self.assertTrue(payload["enabled"])
        self.assertFalse(payload["toggleable"])
        self.assertEqual(payload["enabled_state"], "on-demand")
        self.assertEqual(payload["managed_by"], "D-Bus activation")

    def test_polkit_agent_is_reported_as_shell_managed_not_disabled(self):
        payload = services.service_payload(services.SERVICE_BY_KEY["polkit"])

        self.assertTrue(payload["enabled"])
        self.assertFalse(payload["toggleable"])
        self.assertEqual(payload["enabled_state"], "shell")
        self.assertEqual(payload["managed_by"], "Astrea Shell")


if __name__ == "__main__":
    unittest.main()
