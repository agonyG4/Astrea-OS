#!/usr/bin/env python3
import contextlib
import io
import json
import pathlib
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
sys.path.insert(0, str(BACKEND))


class EmailCliTest(unittest.TestCase):
    def test_status_is_public_json_contract_without_credentials(self):
        from astrea_email import cli, gmail

        with tempfile.TemporaryDirectory() as temp_dir:
            gmail.DEFAULT_CLIENT_SECRET = pathlib.Path(temp_dir) / "gmail_client_secret.json"
            gmail.TOKEN_PATH = pathlib.Path(temp_dir) / "gmail_token.json"
            output = io.StringIO()

            with contextlib.redirect_stdout(output):
                code = cli.main(["status"])

        payload = json.loads(output.getvalue())
        self.assertEqual(code, 0)
        self.assertTrue(payload["ok"])
        self.assertEqual(payload["provider"], "gmail")
        self.assertFalse(payload["configured"])
        self.assertFalse(payload["authenticated"])
        self.assertEqual(payload["messages"], [])

    def test_gmail_provider_prefix_remains_supported(self):
        from astrea_email import cli, gmail

        with tempfile.TemporaryDirectory() as temp_dir:
            gmail.DEFAULT_CLIENT_SECRET = pathlib.Path(temp_dir) / "gmail_client_secret.json"
            gmail.TOKEN_PATH = pathlib.Path(temp_dir) / "gmail_token.json"
            output = io.StringIO()

            with contextlib.redirect_stdout(output):
                code = cli.main(["gmail", "status"])

        payload = json.loads(output.getvalue())
        self.assertEqual(code, 0)
        self.assertEqual(payload["provider"], "gmail")


if __name__ == "__main__":
    unittest.main()
