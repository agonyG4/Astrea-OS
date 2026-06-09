#!/usr/bin/env python3
import importlib.util
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("notifications", ROOT / "notifications.py")
notifications = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(notifications)


class AstreaNotifyContractTests(unittest.TestCase):
    def test_build_hints_exposes_astrea_identity_fields(self):
        hints = notifications.build_hints(
            event_id="email:msg-1",
            thread_id="email:thread-1",
            collapse_key="email:inbox",
            presentation="list",
            interruption_level="time-sensitive",
            urgency="normal",
        )

        self.assertEqual(hints["x-astrea-event-id"], "email:msg-1")
        self.assertEqual(hints["x-astrea-thread-id"], "email:thread-1")
        self.assertEqual(hints["x-astrea-collapse-key"], "email:inbox")
        self.assertEqual(hints["x-astrea-presentation"], "list")
        self.assertEqual(hints["x-astrea-interruption-level"], "time-sensitive")
        self.assertEqual(hints["urgency"], 1)

    def test_invalid_presentation_falls_back_to_banner(self):
        self.assertEqual(notifications.normalize_presentation("weird"), "banner")

    def test_time_sensitive_urgency_keeps_normal_dbus_urgency(self):
        hints = notifications.build_hints(interruption_level="time-sensitive", urgency="time-sensitive")

        self.assertEqual(hints["urgency"], 1)
        self.assertEqual(hints["x-astrea-interruption-level"], "time-sensitive")


if __name__ == "__main__":
    unittest.main()
