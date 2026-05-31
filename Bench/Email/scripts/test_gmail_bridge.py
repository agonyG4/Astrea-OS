#!/usr/bin/env python3
import base64
import importlib.util
import pathlib
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).with_name("gmail_bridge.py")
SPEC = importlib.util.spec_from_file_location("gmail_bridge", SCRIPT)
gmail_bridge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(gmail_bridge)


class GmailBridgeHelpersTest(unittest.TestCase):
    def test_build_query_combines_folder_filter_and_text(self):
        query = gmail_bridge.build_query("Inbox", "unread", "from:team Astrea")
        self.assertEqual(query, "in:inbox is:unread from:team Astrea")

    def test_build_query_supports_starred_and_archive(self):
        self.assertEqual(gmail_bridge.build_query("Starred", "all", ""), "is:starred")
        self.assertEqual(gmail_bridge.build_query("Archive", "starred", ""), "-in:inbox -in:trash -in:sent -in:drafts is:starred")

    def test_parse_headers_extracts_display_name_and_address(self):
        headers = {
            "From": "Nina Costa <nina@example.com>",
            "Subject": "Design Review",
            "Date": "Sun, 31 May 2026 09:42:00 -0300",
        }

        parsed = gmail_bridge.parse_headers(headers)

        self.assertEqual(parsed["fromName"], "Nina Costa")
        self.assertEqual(parsed["fromAddress"], "nina@example.com")
        self.assertEqual(parsed["subject"], "Design Review")
        self.assertIn("09:42", parsed["timestamp"])

    def test_extract_plain_text_body_walks_nested_parts(self):
        body = "Hello from Gmail\n\nThis is plain text."
        encoded = base64.urlsafe_b64encode(body.encode("utf-8")).decode("ascii").rstrip("=")
        payload = {
            "mimeType": "multipart/alternative",
            "parts": [
                {"mimeType": "text/html", "body": {"data": "PGI-SFRNTDwvYj4"}},
                {
                    "mimeType": "multipart/mixed",
                    "parts": [{"mimeType": "text/plain", "body": {"data": encoded}}],
                },
            ],
        }

        self.assertEqual(gmail_bridge.extract_plain_text(payload), body)

    def test_normalize_message_exposes_image_attachment_data(self):
        image_bytes = b"\x89PNG\r\n\x1a\n"
        encoded_image = base64.urlsafe_b64encode(image_bytes).decode("ascii").rstrip("=")
        message = {
            "id": "msg-image",
            "labelIds": ["INBOX"],
            "snippet": "Image attached",
            "payload": {
                "mimeType": "multipart/mixed",
                "headers": [
                    {"name": "From", "value": "Nina Costa <nina@example.com>"},
                    {"name": "Subject", "value": "Screenshot"},
                ],
                "parts": [
                    {
                        "mimeType": "text/plain",
                        "body": {
                            "data": base64.urlsafe_b64encode(b"See attached.").decode("ascii").rstrip("=")
                        },
                    },
                    {
                        "filename": "screenshot.png",
                        "mimeType": "image/png",
                        "headers": [
                            {"name": "Content-Disposition", "value": "attachment; filename=screenshot.png"}
                        ],
                        "body": {"attachmentId": "att-1", "size": len(image_bytes)},
                    },
                ],
            },
        }

        normalized = gmail_bridge.normalize_message(message, attachment_loader=lambda attachment_id: encoded_image)

        self.assertEqual(len(normalized["attachments"]), 1)
        attachment = normalized["attachments"][0]
        self.assertEqual(attachment["name"], "screenshot.png")
        self.assertEqual(attachment["mimeType"], "image/png")
        self.assertEqual(attachment["dataUrl"], "data:image/png;base64," + base64.b64encode(image_bytes).decode("ascii"))

    def test_normalize_message_preserves_sanitized_html_body_and_cid_images(self):
        image_bytes = b"\x89PNG\r\n\x1a\n"
        encoded_image = base64.urlsafe_b64encode(image_bytes).decode("ascii").rstrip("=")
        html_body = """
            <html>
              <head><style>.hidden { display: none; }</style></head>
              <body onclick="steal()">
                <table bgcolor="#303030"><tr><td>
                  <h1>Day 1 Is GTC Keynote Day</h1>
                  <img src="cid:hero-image" width="600" onclick="bad()" />
                  <script>alert("nope")</script>
                </td></tr></table>
              </body>
            </html>
        """
        message = {
            "id": "msg-html",
            "labelIds": ["INBOX"],
            "snippet": "Day 1 Is GTC Keynote Day",
            "payload": {
                "mimeType": "multipart/related",
                "headers": [
                    {"name": "From", "value": "NVIDIA <news@nvidia.com>"},
                    {"name": "Subject", "value": "GTC Keynote"},
                ],
                "parts": [
                    {
                        "mimeType": "text/html",
                        "body": {
                            "data": base64.urlsafe_b64encode(html_body.encode("utf-8")).decode("ascii").rstrip("=")
                        },
                    },
                    {
                        "filename": "hero.png",
                        "mimeType": "image/png",
                        "headers": [{"name": "Content-ID", "value": "<hero-image>"}],
                        "body": {"attachmentId": "att-hero", "size": len(image_bytes)},
                    },
                ],
            },
        }

        normalized = gmail_bridge.normalize_message(message, attachment_loader=lambda attachment_id: encoded_image)

        self.assertIn("Day 1 Is GTC Keynote Day", normalized["htmlBody"])
        self.assertIn("data:image/png;base64," + base64.b64encode(image_bytes).decode("ascii"), normalized["htmlBody"])
        self.assertNotIn("<script", normalized["htmlBody"])
        self.assertNotIn("onclick", normalized["htmlBody"])
        self.assertNotIn("<style", normalized["htmlBody"])

    def test_sanitize_html_keeps_body_when_head_styles_are_malformed(self):
        raw_html = """
            <html>
              <head><style>@media screen { .x { color: red } }
              <body>
                <table><tr><td><h1>Day 1 Is GTC Keynote Day</h1><img src="https://example.com/hero.png"></td></tr></table>
              </body>
            </html>
        """

        sanitized = gmail_bridge.sanitize_html_email(raw_html, [])

        self.assertIn("Day 1 Is GTC Keynote Day", sanitized)
        self.assertIn("<table", sanitized)
        self.assertNotIn("https://example.com/hero.png", sanitized)
        self.assertNotIn("<style", sanitized)

    def test_sanitize_html_blocks_remote_images_without_loader(self):
        raw_html = """
            <body>
              <h1>Newsletter</h1>
              <img src="https://pixel.monitor1.returnpath.net/open.png" width="1" height="1">
              <img src="https://images.example.com/hero.png" width="640">
            </body>
        """

        sanitized = gmail_bridge.sanitize_html_email(raw_html, [])

        self.assertIn("Newsletter", sanitized)
        self.assertNotIn("pixel.monitor1.returnpath.net", sanitized)
        self.assertNotIn("images.example.com", sanitized)
        self.assertNotIn("<img", sanitized)

    def test_sanitize_html_inlines_and_centers_remote_images_with_loader(self):
        raw_html = '<body><img src="https://images.example.com/hero.png" width="900"></body>'

        sanitized = gmail_bridge.sanitize_html_email(
            raw_html,
            [],
            remote_image_loader=lambda url: "data:image/png;base64,abcd" if url.startswith("https://images.example.com") else "",
        )

        self.assertIn('<p align="center">', sanitized)
        self.assertIn('src="data:image/png;base64,abcd"', sanitized)
        self.assertIn('width="640"', sanitized)

    def test_sanitize_html_centers_renderable_email_layouts(self):
        raw_html = """
            <body>
                <table width="600"><tr><td><h1>Privacy Update</h1></td></tr></table>
            </body>
        """

        details = gmail_bridge.sanitize_html_email_details(raw_html, [])

        self.assertEqual(details["htmlRenderMode"], "html")
        self.assertFalse(details["htmlSuppressed"])
        self.assertTrue(details["html"].startswith('<div align="center">'))
        self.assertIn('<table width="600">', details["html"])

    def test_sanitize_html_uses_reader_mode_for_large_email_layouts(self):
        raw_html = "<body>" + ("<table><tr><td>Job match</td></tr></table>" * 70) + "</body>"

        details = gmail_bridge.sanitize_html_email_details(raw_html, [])

        self.assertEqual(details["htmlRenderMode"], "reader")
        self.assertTrue(details["htmlSuppressed"])
        self.assertIn("Job match", details["html"])
        self.assertGreaterEqual(details["htmlTableCount"], 70)

    def test_reader_mode_removes_tracking_urls_and_invisible_padding(self):
        tracking_url = "https://discount.grammarly.com/api/discounts/live?hash=84059faf3e9e6188596fac271da61fb5ddedf068&discount=eydhbGlhcyc6ICdoVGhPQm8nLCAnY2FtcGFpZ25JZCc6ICcyMDI2XzUwb2ZmYW55"
        raw_html = "<body>" + (f"""
            <table><tr><td>
                Grammarly Upgrade today for just $72/year.
                \u200c \u200c \u200c
                <p><a href="http://grammarly.com/">http://grammarly.com/</a></p>
                <p><a href="{tracking_url}">{tracking_url}</a></p>
                <h1>You’ve outgrown the basics</h1>
                <p>Your grammar's under control, but the real magic happens when you move past corrections.</p>
                <p><a href="{tracking_url}">Upgrade now</a></p>
            </td></tr></table>
        """ * 50) + "</body>"

        details = gmail_bridge.sanitize_html_email_details(raw_html, [])

        self.assertEqual(details["htmlRenderMode"], "reader")
        self.assertIn("You’ve outgrown the basics", details["html"])
        self.assertIn("Upgrade now", details["html"])
        self.assertNotIn(tracking_url, details["html"])
        self.assertNotIn("http://grammarly.com/", details["html"])
        self.assertNotIn("\u200c", details["html"])

    def test_reader_html_renders_escaped_lists_as_real_lists(self):
        reader_html = gmail_bridge.reader_text_to_html(
            """
            Novidades:
            <ul>

            <li>As atualizações aumentam a legibilidade.</li>

            <li>Você pode revogar essa permissão a qualquer momento.</li>
            </ul>
            """
        )

        self.assertIn("<ul>", reader_html)
        self.assertIn("<li>As atualizações aumentam a legibilidade.</li>", reader_html)
        self.assertNotIn("<ul></ul>", reader_html)
        self.assertNotIn("&lt;ul&gt;", reader_html)
        self.assertNotIn("&lt;li&gt;", reader_html)

    def test_upgrade_cached_reader_html_preserves_reader_mode_and_cleans_markup(self):
        cached = {
            "messageId": "spotify",
            "body": "Novidades:\n<ul>\n<li>As atualizações aumentam a legibilidade.</li>\n</ul>",
            "htmlBody": '<div align="center"><div align="left"><p>Novidades:</p><p>&lt;ul&gt;</p><p>&lt;li&gt;As atualizações aumentam a legibilidade.&lt;/li&gt;</p><p>&lt;/ul&gt;</p></div></div>',
            "htmlRenderMode": "reader",
            "htmlSuppressed": True,
        }

        upgraded, changed = gmail_bridge.upgrade_cached_message(cached)

        self.assertTrue(changed)
        self.assertEqual(upgraded["htmlRenderMode"], "reader")
        self.assertIn("<ul>", upgraded["htmlBody"])
        self.assertIn("<li>As atualizações aumentam a legibilidade.</li>", upgraded["htmlBody"])
        self.assertNotIn("<ul></ul>", upgraded["htmlBody"])
        self.assertNotIn("&lt;li&gt;", upgraded["htmlBody"])

    def test_normalize_message_counts_blocked_remote_images(self):
        html_body = """
            <body>
                <img src="https://pixel.monitor1.returnpath.net/open.png" width="1" height="1">
                <img src="https://jobs.example.com/company-logo.png" width="320">
            </body>
        """
        message = {
            "id": "msg-remote",
            "labelIds": ["INBOX"],
            "snippet": "Job match",
            "payload": {
                "mimeType": "text/html",
                "headers": [
                    {"name": "From", "value": "Jobs <jobs@example.com>"},
                    {"name": "Subject", "value": "New jobs"},
                ],
                "body": {
                    "data": base64.urlsafe_b64encode(html_body.encode("utf-8")).decode("ascii").rstrip("=")
                },
            },
        }

        normalized = gmail_bridge.normalize_message(message)

        self.assertEqual(normalized["remoteImageCount"], 1)
        self.assertFalse(normalized["remoteImagesLoaded"])
        self.assertNotIn("jobs.example.com", normalized["htmlBody"])
        self.assertNotIn("pixel.monitor1.returnpath.net", normalized["htmlBody"])

    def test_normalize_message_exposes_reader_mode_for_heavy_html(self):
        plain_body = "Readable job fallback"
        html_body = "<body>" + ("<table><tr><td>Heavy layout</td></tr></table>" * 70) + "</body>"
        message = {
            "id": "msg-heavy-html",
            "labelIds": ["INBOX"],
            "snippet": "Heavy job match",
            "payload": {
                "mimeType": "multipart/alternative",
                "headers": [
                    {"name": "From", "value": "Jobs <jobs@example.com>"},
                    {"name": "Subject", "value": "New jobs"},
                ],
                "parts": [
                    {
                        "mimeType": "text/plain",
                        "body": {
                            "data": base64.urlsafe_b64encode(plain_body.encode("utf-8")).decode("ascii").rstrip("=")
                        },
                    },
                    {
                        "mimeType": "text/html",
                        "body": {
                            "data": base64.urlsafe_b64encode(html_body.encode("utf-8")).decode("ascii").rstrip("=")
                        },
                    },
                ],
            },
        }

        normalized = gmail_bridge.normalize_message(message)

        self.assertEqual(normalized["body"], plain_body)
        self.assertIn("Heavy layout", normalized["htmlBody"])
        self.assertEqual(normalized["htmlRenderMode"], "reader")
        self.assertTrue(normalized["htmlSuppressed"])

    def test_normalize_message_loads_large_html_body_parts(self):
        html_body = "<table><tr><td><h1>Day 1 Is GTC Keynote Day</h1></td></tr></table>"
        encoded_html = base64.urlsafe_b64encode(html_body.encode("utf-8")).decode("ascii").rstrip("=")
        message = {
            "id": "msg-large-html",
            "labelIds": ["INBOX"],
            "snippet": "Day 1 Is GTC Keynote Day",
            "payload": {
                "mimeType": "multipart/alternative",
                "headers": [
                    {"name": "From", "value": "NVIDIA <news@nvidia.com>"},
                    {"name": "Subject", "value": "GTC Keynote"},
                ],
                "parts": [
                    {
                        "mimeType": "text/plain",
                        "body": {
                            "data": base64.urlsafe_b64encode(b"Plain fallback").decode("ascii").rstrip("=")
                        },
                    },
                    {
                        "mimeType": "text/html",
                        "body": {"attachmentId": "html-body", "size": len(html_body)},
                    },
                ],
            },
        }

        normalized = gmail_bridge.normalize_message(message, attachment_loader=lambda attachment_id: encoded_html)

        self.assertIn("Day 1 Is GTC Keynote Day", normalized["htmlBody"])
        self.assertEqual(normalized["body"], "Plain fallback")
        self.assertEqual(normalized["attachments"], [])

    def test_list_messages_follows_gmail_pages_until_limit(self):
        gmail_module = gmail_bridge.list_messages.__globals__
        original_ensure_token = gmail_module["ensure_token"]
        original_api_request = gmail_module["api_request"]
        original_cache_dir = gmail_module["CACHE_DIR"]
        try:
            gmail_module["ensure_token"] = lambda: {"access_token": "token"}
            with tempfile.TemporaryDirectory() as temp_dir:
                gmail_module["CACHE_DIR"] = pathlib.Path(temp_dir)

                def minimal_message(message_id):
                    return {
                        "id": message_id,
                        "labelIds": ["INBOX"],
                        "snippet": message_id,
                        "payload": {
                            "headers": [
                                {"name": "From", "value": "Astrea <team@example.com>"},
                                {"name": "Subject", "value": message_id},
                            ],
                            "body": {
                                "data": base64.urlsafe_b64encode(message_id.encode("utf-8")).decode("ascii").rstrip("=")
                            },
                        },
                    }

                list_queries = []

                def fake_api_request(method, path, token, query=None, body=None):
                    if path == "/messages":
                        list_queries.append(dict(query or {}))
                        if query and query.get("pageToken") == "page-2":
                            return {"messages": [{"id": "m3"}], "resultSizeEstimate": 3}
                        return {
                            "messages": [{"id": "m1"}, {"id": "m2"}],
                            "nextPageToken": "page-2",
                            "resultSizeEstimate": 3,
                        }
                    if path.startswith("/messages/"):
                        return minimal_message(path.rsplit("/", 1)[-1])
                    self.fail(f"Unexpected Gmail API request: {method} {path}")

                gmail_module["api_request"] = fake_api_request

                payload = gmail_bridge.list_messages("Inbox", "all", "", 3, force_refresh=True)

                self.assertEqual([message["messageId"] for message in payload["messages"]], ["m1", "m2", "m3"])
                self.assertEqual(len(list_queries), 2)
                self.assertEqual(list_queries[1]["pageToken"], "page-2")
                self.assertEqual(payload["resultSizeEstimate"], 3)
                self.assertEqual(payload["nextPageToken"], "")
        finally:
            gmail_module["ensure_token"] = original_ensure_token
            gmail_module["api_request"] = original_api_request
            gmail_module["CACHE_DIR"] = original_cache_dir

    def test_list_messages_saves_and_reuses_cached_page(self):
        gmail_module = gmail_bridge.list_messages.__globals__
        original_ensure_token = gmail_module["ensure_token"]
        original_api_request = gmail_module["api_request"]
        original_cache_dir = gmail_module["CACHE_DIR"]
        try:
            gmail_module["ensure_token"] = lambda: {"access_token": "token", "account": "cache@example.com"}
            with tempfile.TemporaryDirectory() as temp_dir:
                gmail_module["CACHE_DIR"] = pathlib.Path(temp_dir)
                api_calls = []

                def fake_api_request(method, path, token, query=None, body=None):
                    api_calls.append((method, path))
                    if path == "/messages":
                        return {"messages": [{"id": "cached-message"}], "resultSizeEstimate": 1}
                    if path == "/messages/cached-message":
                        return {
                            "id": "cached-message",
                            "labelIds": ["INBOX"],
                            "snippet": "Cached body",
                            "payload": {
                                "headers": [
                                    {"name": "From", "value": "Astrea <team@example.com>"},
                                    {"name": "Subject", "value": "Cached"},
                                ],
                                "body": {
                                    "data": base64.urlsafe_b64encode(b"Cached body").decode("ascii").rstrip("=")
                                },
                            },
                        }
                    self.fail(f"Unexpected Gmail API request: {method} {path}")

                gmail_module["api_request"] = fake_api_request

                live_payload = gmail_bridge.list_messages("Inbox", "all", "", 10, force_refresh=True)
                self.assertFalse(live_payload["cached"])
                self.assertEqual([message["messageId"] for message in live_payload["messages"]], ["cached-message"])
                self.assertEqual(len(api_calls), 2)

                def fail_api_request(method, path, token, query=None, body=None):
                    self.fail(f"Cache was bypassed by unexpected Gmail API request: {method} {path}")

                gmail_module["api_request"] = fail_api_request
                cached_payload = gmail_bridge.list_messages("Inbox", "all", "", 10)

                self.assertTrue(cached_payload["cached"])
                self.assertEqual([message["messageId"] for message in cached_payload["messages"]], ["cached-message"])
        finally:
            gmail_module["ensure_token"] = original_ensure_token
            gmail_module["api_request"] = original_api_request
            gmail_module["CACHE_DIR"] = original_cache_dir

    def test_cached_pages_are_reused_across_different_limits(self):
        gmail_module = gmail_bridge.list_messages.__globals__
        original_ensure_token = gmail_module["ensure_token"]
        original_api_request = gmail_module["api_request"]
        original_cache_dir = gmail_module["CACHE_DIR"]
        try:
            gmail_module["ensure_token"] = lambda: {"access_token": "token", "account": "cache@example.com"}
            with tempfile.TemporaryDirectory() as temp_dir:
                gmail_module["CACHE_DIR"] = pathlib.Path(temp_dir)

                def fake_api_request(method, path, token, query=None, body=None):
                    if path == "/messages":
                        return {"messages": [{"id": "cached-message"}], "resultSizeEstimate": 1}
                    if path == "/messages/cached-message":
                        return {
                            "id": "cached-message",
                            "labelIds": ["INBOX"],
                            "snippet": "Cached body",
                            "payload": {
                                "headers": [
                                    {"name": "From", "value": "Astrea <team@example.com>"},
                                    {"name": "Subject", "value": "Cached"},
                                ],
                                "body": {
                                    "data": base64.urlsafe_b64encode(b"Cached body").decode("ascii").rstrip("=")
                                },
                            },
                        }
                    self.fail(f"Unexpected Gmail API request: {method} {path}")

                gmail_module["api_request"] = fake_api_request
                gmail_bridge.list_messages("Inbox", "all", "", 2, force_refresh=True)

                def fail_api_request(method, path, token, query=None, body=None):
                    self.fail(f"Limit-only cache miss made a Gmail API request: {method} {path}")

                gmail_module["api_request"] = fail_api_request
                cached_payload = gmail_bridge.list_messages("Inbox", "all", "", 100)

                self.assertTrue(cached_payload["cached"])
                self.assertEqual([message["messageId"] for message in cached_payload["messages"]], ["cached-message"])
        finally:
            gmail_module["ensure_token"] = original_ensure_token
            gmail_module["api_request"] = original_api_request
            gmail_module["CACHE_DIR"] = original_cache_dir

    def test_force_refresh_reuses_cached_message_bodies(self):
        gmail_module = gmail_bridge.list_messages.__globals__
        original_ensure_token = gmail_module["ensure_token"]
        original_api_request = gmail_module["api_request"]
        original_cache_dir = gmail_module["CACHE_DIR"]
        try:
            token = {"access_token": "token", "account": "cache@example.com"}
            gmail_module["ensure_token"] = lambda: token
            with tempfile.TemporaryDirectory() as temp_dir:
                gmail_module["CACHE_DIR"] = pathlib.Path(temp_dir)
                cached_message = {
                    "messageId": "cached-message",
                    "folder": "Inbox",
                    "fromName": "Astrea",
                    "fromAddress": "team@example.com",
                    "subject": "Cached body",
                    "preview": "Cached preview",
                    "body": "Cached body that should not be downloaded again",
                    "htmlBody": "",
                    "timestamp": "",
                    "tag": "Gmail",
                    "starred": False,
                    "isRead": True,
                    "importance": "normal",
                    "attachments": [],
                    "remoteImageCount": 0,
                    "remoteImagesLoadedCount": 0,
                    "remoteImagesLoaded": False,
                }
                gmail_bridge.write_cache(
                    token,
                    "Inbox",
                    "all",
                    "",
                    10,
                    "",
                    {
                        "ok": True,
                        "provider": "gmail",
                        "folder": "Inbox",
                        "filter": "all",
                        "query": "",
                        "pageToken": "",
                        "messages": [cached_message],
                        "resultSizeEstimate": 1,
                        "nextPageToken": "",
                    },
                )

                def fake_api_request(method, path, token, query=None, body=None):
                    if path == "/messages":
                        return {
                            "messages": [{"id": "cached-message"}, {"id": "new-message"}],
                            "resultSizeEstimate": 2,
                        }
                    if path == "/messages/cached-message":
                        self.fail("Force refresh downloaded a cached message body again")
                    if path == "/messages/new-message":
                        return {
                            "id": "new-message",
                            "labelIds": ["INBOX"],
                            "snippet": "New body",
                            "payload": {
                                "headers": [
                                    {"name": "From", "value": "Astrea <team@example.com>"},
                                    {"name": "Subject", "value": "New body"},
                                ],
                                "body": {
                                    "data": base64.urlsafe_b64encode(b"New body").decode("ascii").rstrip("=")
                                },
                            },
                        }
                    self.fail(f"Unexpected Gmail API request: {method} {path}")

                gmail_module["api_request"] = fake_api_request

                payload = gmail_bridge.list_messages("Inbox", "all", "", 10, force_refresh=True)

                self.assertEqual([message["messageId"] for message in payload["messages"]], ["cached-message", "new-message"])
                self.assertEqual(payload["messages"][0]["body"], cached_message["body"])
                self.assertEqual(payload["messages"][1]["body"], "New body")
        finally:
            gmail_module["ensure_token"] = original_ensure_token
            gmail_module["api_request"] = original_api_request
            gmail_module["CACHE_DIR"] = original_cache_dir

    def test_cache_only_returns_empty_payload_without_network_on_miss(self):
        gmail_module = gmail_bridge.list_messages.__globals__
        original_ensure_token = gmail_module["ensure_token"]
        original_api_request = gmail_module["api_request"]
        original_cache_dir = gmail_module["CACHE_DIR"]
        try:
            gmail_module["ensure_token"] = lambda: {"access_token": "token", "account": "cache@example.com"}
            with tempfile.TemporaryDirectory() as temp_dir:
                gmail_module["CACHE_DIR"] = pathlib.Path(temp_dir)

                def fail_api_request(method, path, token, query=None, body=None):
                    self.fail(f"Cache-only mode made a Gmail API request: {method} {path}")

                gmail_module["api_request"] = fail_api_request
                payload = gmail_bridge.list_messages("Inbox", "all", "", 100, cache_only=True)

                self.assertTrue(payload["ok"])
                self.assertTrue(payload["cacheMiss"])
                self.assertEqual(payload["messages"], [])
        finally:
            gmail_module["ensure_token"] = original_ensure_token
            gmail_module["api_request"] = original_api_request
            gmail_module["CACHE_DIR"] = original_cache_dir

    def test_modify_message_keeps_image_attachment_preview(self):
        gmail_module = gmail_bridge.modify_message.__globals__
        original_ensure_token = gmail_module["ensure_token"]
        original_api_request = gmail_module["api_request"]
        image_bytes = b"\x89PNG\r\n\x1a\n"
        encoded_image = base64.urlsafe_b64encode(image_bytes).decode("ascii").rstrip("=")
        try:
            gmail_module["ensure_token"] = lambda: {"access_token": "token"}
            calls = []

            def fake_api_request(method, path, token, query=None, body=None):
                calls.append((method, path))
                if method == "POST":
                    return {}
                if path == "/messages/msg-image":
                    return {
                        "id": "msg-image",
                        "labelIds": ["INBOX"],
                        "snippet": "Image attached",
                        "payload": {
                            "headers": [
                                {"name": "From", "value": "Nina Costa <nina@example.com>"},
                                {"name": "Subject", "value": "Screenshot"},
                            ],
                            "parts": [
                                {
                                    "filename": "screenshot.png",
                                    "mimeType": "image/png",
                                    "body": {"attachmentId": "att-1", "size": len(image_bytes)},
                                }
                            ],
                        },
                    }
                if path == "/messages/msg-image/attachments/att-1":
                    return {"data": encoded_image}
                self.fail(f"Unexpected Gmail API request: {method} {path}")

            gmail_module["api_request"] = fake_api_request

            payload = gmail_bridge.modify_message("msg-image", "read")

            self.assertEqual(
                payload["message"]["attachments"][0]["dataUrl"],
                "data:image/png;base64," + base64.b64encode(image_bytes).decode("ascii"),
            )
            self.assertIn(("GET", "/messages/msg-image/attachments/att-1"), calls)
        finally:
            gmail_module["ensure_token"] = original_ensure_token
            gmail_module["api_request"] = original_api_request

    def test_modify_plan_maps_user_actions_to_gmail_labels(self):
        self.assertEqual(
            gmail_bridge.modify_plan("read"),
            {"endpoint": "modify", "body": {"removeLabelIds": ["UNREAD"]}},
        )
        self.assertEqual(
            gmail_bridge.modify_plan("unread"),
            {"endpoint": "modify", "body": {"addLabelIds": ["UNREAD"]}},
        )
        self.assertEqual(
            gmail_bridge.modify_plan("archive"),
            {"endpoint": "modify", "body": {"removeLabelIds": ["INBOX"]}},
        )
        self.assertEqual(gmail_bridge.modify_plan("trash"), {"endpoint": "trash", "body": {}})
        self.assertEqual(gmail_bridge.modify_plan("inbox"), {"endpoint": "untrash", "body": {}})

    def test_create_send_payload_is_base64url_mime(self):
        payload = gmail_bridge.create_send_payload("a@example.com", "Subject", "Body")
        raw = payload["raw"]
        decoded = base64.urlsafe_b64decode(raw + "=" * (-len(raw) % 4)).decode("utf-8")

        self.assertNotIn("+", raw)
        self.assertNotIn("/", raw)
        self.assertIn("To: a@example.com", decoded)
        self.assertIn("Subject: Subject", decoded)
        self.assertIn("Body", decoded)


if __name__ == "__main__":
    unittest.main()
