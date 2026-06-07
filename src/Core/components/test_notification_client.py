#!/usr/bin/env python3
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent


class NotificationClientQmlContractTests(unittest.TestCase):
    def test_public_qmldir_exports_notification_client(self):
        qmldir = (ROOT / "qmldir").read_text(encoding="utf-8")

        self.assertIn("NotificationClient 1.0 NotificationClient.qml", qmldir)

    def test_notification_client_uses_astrea_notify_cli_contract(self):
        source = (ROOT / "feedback" / "NotificationClient.qml").read_text(encoding="utf-8")

        self.assertIn("function notify(payload)", source)
        self.assertIn("foregroundPresentation", source)
        self.assertIn("astrea-notify", source)
        self.assertIn('"--event-id"', source)
        self.assertIn('"--thread-id"', source)
        self.assertIn('"--collapse-key"', source)
        self.assertIn('"--presentation"', source)

    def test_root_notification_client_is_a_public_shim(self):
        source = (ROOT / "NotificationClient.qml").read_text(encoding="utf-8")

        self.assertIn('import "./feedback" as Feedback', source)
        self.assertIn("Feedback.NotificationClient", source)


if __name__ == "__main__":
    unittest.main()
