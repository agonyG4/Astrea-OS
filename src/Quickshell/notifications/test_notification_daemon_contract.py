#!/usr/bin/env python3
import importlib.util
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("notification_daemon", ROOT / "notification_daemon.py")
notification_daemon = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(notification_daemon)


class NotificationDaemonContractTests(unittest.TestCase):
    def daemon_stub(self):
        daemon = object.__new__(notification_daemon.NotificationDaemon)
        daemon.next_id = 10
        daemon.notifications = {}
        daemon.history = {}
        daemon.active_event_index = {}
        daemon.active_collapse_index = {}
        daemon.history_event_index = {}
        daemon.delivered_events = {}
        return daemon

    def test_new_event_gets_a_fresh_notification_id(self):
        daemon = self.daemon_stub()

        notification_id, history_only = daemon._resolve_notification_request(
            replaces_id=0,
            event_id="email:msg-1",
            collapse_key="email:inbox",
        )

        self.assertEqual(notification_id, 10)
        self.assertFalse(history_only)
        self.assertEqual(daemon.next_id, 11)

    def test_duplicate_event_without_active_notification_is_history_only(self):
        daemon = self.daemon_stub()
        daemon.history = {
            7: {
                "id": 7,
                "summary": "New email",
                "eventId": "email:msg-1",
                "collapseKey": "email:inbox",
            }
        }

        notification_id, history_only = daemon._resolve_notification_request(
            replaces_id=0,
            event_id="email:msg-1",
            collapse_key="email:inbox",
        )

        self.assertEqual(notification_id, 7)
        self.assertTrue(history_only)
        self.assertEqual(daemon.next_id, 10)

    def test_collapse_key_reuses_active_notification(self):
        daemon = self.daemon_stub()
        daemon.notifications = {
            5: {
                "id": 5,
                "summary": "2 new emails",
                "eventId": "email:msg-old",
                "collapseKey": "email:inbox",
            }
        }

        notification_id, history_only = daemon._resolve_notification_request(
            replaces_id=0,
            event_id="email:msg-2",
            collapse_key="email:inbox",
        )

        self.assertEqual(notification_id, 5)
        self.assertFalse(history_only)
        self.assertEqual(daemon.next_id, 10)

    def test_delivered_event_is_suppressed_even_after_collapsed_history_changes(self):
        daemon = self.daemon_stub()
        daemon.notifications = {
            5: {
                "id": 5,
                "summary": "Newest email",
                "eventId": "email:new",
                "collapseKey": "email:inbox",
            }
        }
        daemon.history = {
            5: {
                "id": 5,
                "summary": "Newest email",
                "eventId": "email:new",
                "collapseKey": "email:inbox",
            }
        }
        daemon.delivered_events = {"email:old": 5, "email:new": 5}

        notification_id, history_only = daemon._resolve_notification_request(
            replaces_id=0,
            event_id="email:old",
            collapse_key="email:inbox",
        )

        self.assertEqual(notification_id, 5)
        self.assertTrue(history_only)
        self.assertEqual(daemon.next_id, 10)

    def test_remember_history_indexes_event_and_active_notification_indexes_collapse(self):
        daemon = self.daemon_stub()
        notification = {
            "id": 12,
            "summary": "Indexed email",
            "eventId": "email:indexed",
            "collapseKey": "email:inbox",
        }

        daemon._remember_history(notification)
        daemon._store_active_notification(notification)

        self.assertEqual(daemon.history_event_index["email:indexed"], 12)
        self.assertEqual(daemon.delivered_events["email:indexed"], 12)
        self.assertEqual(daemon.active_event_index["email:indexed"], 12)
        self.assertEqual(daemon.active_collapse_index["email:inbox"], 12)

    def test_astrea_hints_are_normalized(self):
        metadata = notification_daemon._astrea_metadata_from_hints({
            "x-astrea-event-id": "email:msg-1",
            "x-astrea-thread-id": "email:thread-1",
            "x-astrea-collapse-key": "email:inbox",
            "x-astrea-presentation": "list",
            "x-astrea-interruption-level": "time-sensitive",
        })

        self.assertEqual(metadata["eventId"], "email:msg-1")
        self.assertEqual(metadata["threadId"], "email:thread-1")
        self.assertEqual(metadata["collapseKey"], "email:inbox")
        self.assertEqual(metadata["presentation"], "list")
        self.assertEqual(metadata["interruptionLevel"], "time-sensitive")


if __name__ == "__main__":
    unittest.main()
