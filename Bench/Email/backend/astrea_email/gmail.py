import base64
import hashlib
import html
import json
import os
import pathlib
import re
import secrets
import socketserver
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from email.message import EmailMessage
from email.utils import parseaddr, parsedate_to_datetime
from html.parser import HTMLParser
from http.server import BaseHTTPRequestHandler


SCOPES = [
    "https://www.googleapis.com/auth/gmail.modify",
    "https://www.googleapis.com/auth/gmail.send",
]

AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_URL = "https://oauth2.googleapis.com/token"
GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me"
GMAIL_PAGE_LIMIT = 100
GMAIL_TOTAL_LIMIT = 500
INLINE_IMAGE_LIMIT_BYTES = 8 * 1024 * 1024
REMOTE_IMAGE_LIMIT = 8
REMOTE_IMAGE_MAX_BYTES = 2 * 1024 * 1024
REMOTE_IMAGE_TOTAL_BYTES = 10 * 1024 * 1024
HTML_IMAGE_MAX_WIDTH = 640
HTML_RENDER_CHAR_LIMIT = 70_000
HTML_RENDER_TABLE_LIMIT = 48
HTML_READER_BODY_MIN_CHARS = 300
HTML_READER_BODY_LIMIT = 24_000
URL_TOKEN_RE = re.compile(r"<?https?://[^>\s]+>?", re.IGNORECASE)
INVISIBLE_TEXT_RE = re.compile(r"[\u200b-\u200f\u202a-\u202e\ufeff\u00ad]")

CONFIG_HOME = pathlib.Path(os.environ.get("XDG_CONFIG_HOME", "~/.config")).expanduser()
STATE_HOME = pathlib.Path(os.environ.get("XDG_STATE_HOME", "~/.local/state")).expanduser()
DEFAULT_CLIENT_SECRET = CONFIG_HOME / "AstreaOS" / "email" / "gmail_client_secret.json"
TOKEN_PATH = STATE_HOME / "Astrea" / "email" / "gmail_token.json"
CACHE_DIR = STATE_HOME / "Astrea" / "email" / "cache"
CACHE_VERSION = 4


class GmailBridgeError(RuntimeError):
    pass


def credentials_path():
    configured = os.environ.get("ASTREA_EMAIL_GMAIL_CLIENT_SECRET", "").strip()
    return pathlib.Path(configured).expanduser() if configured else DEFAULT_CLIENT_SECRET


def load_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = path.with_name(path.name + ".tmp")
    with os.fdopen(os.open(temp_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2, sort_keys=True)
    os.replace(temp_path, path)
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def load_client():
    path = credentials_path()
    if not path.exists():
        raise GmailBridgeError(f"Missing Gmail OAuth client: {path}")

    payload = load_json(path)
    client = payload.get("installed") or payload.get("web") or payload
    client_id = client.get("client_id", "")
    if not client_id:
        raise GmailBridgeError(f"Invalid Gmail OAuth client: {path}")

    return {
        "path": str(path),
        "client_id": client_id,
        "client_secret": client.get("client_secret", ""),
    }


def token_state(token):
    if not token:
        return "missing"
    expires_at = float(token.get("expires_at", 0) or 0)
    if token.get("access_token") and expires_at > time.time() + 60:
        return "valid"
    if token.get("refresh_token"):
        return "refreshable"
    return "expired"


def read_token():
    try:
        return load_json(TOKEN_PATH)
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return {}


def save_token(token):
    token.setdefault("scopes", SCOPES)
    write_json(TOKEN_PATH, token)


def post_form(url, payload):
    data = urllib.parse.urlencode(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded", "Accept": "application/json"},
        method="POST",
    )
    return open_json(request)


def open_json(request):
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise GmailBridgeError(body or str(exc)) from exc
    except urllib.error.URLError as exc:
        raise GmailBridgeError(str(exc.reason)) from exc

    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise GmailBridgeError(raw) from exc


def api_request(method, path, token, query=None, body=None):
    url = GMAIL_API + path
    if query:
        url += "?" + urllib.parse.urlencode(query)

    data = None
    headers = {
        "Accept": "application/json",
        "Authorization": "Bearer " + token["access_token"],
    }
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    return open_json(request)


def with_expiry(payload):
    token = dict(payload)
    token["expires_at"] = time.time() + int(token.get("expires_in", 3600))
    return token


def refresh_token(client, token):
    if not token.get("refresh_token"):
        raise GmailBridgeError("Gmail account is not authenticated")

    payload = {
        "client_id": client["client_id"],
        "grant_type": "refresh_token",
        "refresh_token": token["refresh_token"],
    }
    if client.get("client_secret"):
        payload["client_secret"] = client["client_secret"]

    refreshed = with_expiry(post_form(TOKEN_URL, payload))
    refreshed["refresh_token"] = token["refresh_token"]
    refreshed["account"] = token.get("account", "")
    save_token(refreshed)
    return refreshed


def ensure_token():
    client = load_client()
    token = read_token()
    state = token_state(token)
    if state == "valid":
        return token
    if state == "refreshable":
        return refresh_token(client, token)
    raise GmailBridgeError("Gmail account is not authenticated")


def code_challenge(verifier):
    digest = hashlib.sha256(verifier.encode("ascii")).digest()
    return base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")


class OAuthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)
        self.server.oauth_params = {key: values[0] for key, values in params.items()}

        message = "Gmail connected. You can return to Astrea Email."
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(message.encode("utf-8"))))
        self.end_headers()
        self.wfile.write(message.encode("utf-8"))

    def log_message(self, fmt, *args):
        return


def authenticate():
    client = load_client()
    verifier = secrets.token_urlsafe(64)
    state = secrets.token_urlsafe(24)

    with socketserver.TCPServer(("127.0.0.1", 0), OAuthHandler) as server:
        server.timeout = 180
        server.oauth_params = {}
        redirect_uri = f"http://127.0.0.1:{server.server_address[1]}/"
        params = {
            "access_type": "offline",
            "client_id": client["client_id"],
            "code_challenge": code_challenge(verifier),
            "code_challenge_method": "S256",
            "prompt": "consent",
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "scope": " ".join(SCOPES),
            "state": state,
        }
        url = AUTH_URL + "?" + urllib.parse.urlencode(params)
        webbrowser.open(url)
        server.handle_request()
        result = server.oauth_params

    if result.get("state") != state:
        raise GmailBridgeError("OAuth state mismatch")
    if result.get("error"):
        raise GmailBridgeError(result["error"])
    if not result.get("code"):
        raise GmailBridgeError("OAuth flow timed out")

    token_payload = {
        "client_id": client["client_id"],
        "code": result["code"],
        "code_verifier": verifier,
        "grant_type": "authorization_code",
        "redirect_uri": redirect_uri,
    }
    if client.get("client_secret"):
        token_payload["client_secret"] = client["client_secret"]

    token = with_expiry(post_form(TOKEN_URL, token_payload))
    profile = {}
    try:
        profile = api_request("GET", "/profile", token)
    except GmailBridgeError:
        profile = {}

    token["account"] = profile.get("emailAddress", "")
    save_token(token)
    return token


def build_query(folder, message_filter, text):
    folder_terms = {
        "Inbox": "in:inbox",
        "Starred": "is:starred",
        "Sent": "in:sent",
        "Drafts": "in:drafts",
        "Archive": "-in:inbox -in:trash -in:sent -in:drafts",
        "All": "-in:trash",
        "Trash": "in:trash",
    }
    filter_terms = {
        "unread": "is:unread",
        "starred": "is:starred",
    }

    terms = [folder_terms.get(folder, "in:inbox")]
    if message_filter in filter_terms and filter_terms[message_filter] not in terms[0]:
        terms.append(filter_terms[message_filter])
    if text and text.strip():
        terms.append(text.strip())
    return " ".join(term for term in terms if term).strip()


def headers_to_dict(headers):
    mapped = {}
    for header in headers or []:
        name = header.get("name", "")
        value = header.get("value", "")
        if name:
            mapped[name] = value
    return mapped


def format_timestamp(value):
    if not value:
        return ""
    try:
        parsed = parsedate_to_datetime(value)
        if parsed is None:
            return value
        local = parsed.astimezone()
        now = parsed.astimezone().now().astimezone()
        if local.date() == now.date():
            return local.strftime("%H:%M")
        if local.year == now.year:
            return local.strftime("%b %-d")
        return local.strftime("%b %-d, %Y")
    except (TypeError, ValueError, OSError):
        return value


def parse_headers(headers):
    raw_from = headers.get("From", "")
    from_name, from_address = parseaddr(raw_from)
    if not from_name and from_address:
        from_name = from_address.split("@")[0]
    if not from_name:
        from_name = "Unknown Sender"

    return {
        "fromName": from_name,
        "fromAddress": from_address,
        "subject": headers.get("Subject") or "(No subject)",
        "timestamp": format_timestamp(headers.get("Date", "")),
    }


def decode_base64url(data):
    if not data:
        return b""
    padded = data + "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(padded)


def decode_body(data):
    return decode_base64url(data).decode("utf-8", errors="replace")


def data_url(mime, data):
    if not mime or not data:
        return ""
    raw = decode_base64url(data)
    encoded = base64.b64encode(raw).decode("ascii")
    return f"data:{mime};base64,{encoded}"


def extract_plain_text(payload):
    if not payload:
        return ""
    mime = payload.get("mimeType", "")
    body = payload.get("body", {})
    if mime.startswith("text/plain") and body.get("data"):
        return decode_body(body["data"])

    for part in payload.get("parts", []) or []:
        extracted = extract_plain_text(part)
        if extracted:
            return extracted

    if body.get("data") and not mime.startswith("text/html"):
        return decode_body(body["data"])
    return ""


def extract_html_body(payload, attachment_loader=None):
    if not payload:
        return ""
    mime = payload.get("mimeType", "")
    body = payload.get("body", {})
    if mime.startswith("text/html") and body.get("data"):
        return decode_body(body["data"])
    if mime.startswith("text/html") and body.get("attachmentId") and attachment_loader is not None:
        data = attachment_loader(body["attachmentId"])
        if data:
            return decode_body(data)

    for part in payload.get("parts", []) or []:
        extracted = extract_html_body(part, attachment_loader)
        if extracted:
            return extracted

    return ""


class EmailHtmlSanitizer(HTMLParser):
    block_tags = {"script", "style", "head", "meta", "link", "iframe", "object", "embed", "form", "input", "button", "textarea", "select", "option", "canvas", "svg"}
    drop_tags = {"html", "body"}
    safe_attrs = {
        "abbr", "align", "alt", "bgcolor", "border", "cellpadding", "cellspacing",
        "colspan", "dir", "height", "href", "hspace", "lang", "rowspan", "src",
        "style", "target", "title", "valign", "vspace", "width",
    }
    void_tags = {"area", "br", "hr", "img", "input", "meta", "link"}

    def __init__(self, cid_sources=None, remote_image_loader=None):
        super().__init__(convert_charrefs=False)
        self.parts = []
        self.cid_sources = cid_sources or {}
        self.remote_image_loader = remote_image_loader
        self.remote_image_count = 0
        self.remote_images_loaded = 0
        self.skip_stack = []

    def should_skip(self):
        return len(self.skip_stack) > 0

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        if tag in self.block_tags:
            self.skip_stack.append(tag)
            return
        if self.should_skip():
            return
        if tag in self.drop_tags:
            return

        if tag == "img" and self.is_tracking_image(attrs):
            return

        attrs_text = self.clean_attrs(tag, attrs)
        if tag == "img" and 'src="' not in attrs_text:
            return
        if tag == "img":
            self.parts.append(f'<p align="center"><img{attrs_text} /></p>')
            return

        suffix = " /" if tag in self.void_tags else ""
        self.parts.append(f"<{tag}{attrs_text}{suffix}>")

    def handle_startendtag(self, tag, attrs):
        tag = tag.lower()
        if tag in self.block_tags or self.should_skip() or tag in self.drop_tags:
            return
        attrs_text = self.clean_attrs(tag, attrs)
        if tag == "img":
            if self.is_tracking_image(attrs) or 'src="' not in attrs_text:
                return
            self.parts.append(f'<p align="center"><img{attrs_text} /></p>')
            return
        self.parts.append(f"<{tag}{attrs_text} />")

    def handle_endtag(self, tag):
        tag = tag.lower()
        if self.skip_stack:
            if tag == self.skip_stack[-1]:
                self.skip_stack.pop()
            return
        if tag in self.drop_tags or tag in self.block_tags or tag in self.void_tags:
            return
        self.parts.append(f"</{tag}>")

    def handle_data(self, data):
        if not self.should_skip():
            self.parts.append(html.escape(data, quote=False))

    def handle_entityref(self, name):
        if not self.should_skip():
            self.parts.append(f"&{name};")

    def handle_charref(self, name):
        if not self.should_skip():
            self.parts.append(f"&#{name};")

    def clean_attrs(self, tag, attrs):
        cleaned = []
        for name, value in attrs:
            attr = (name or "").lower()
            if attr.startswith("on") or attr not in self.safe_attrs:
                continue
            if value is None:
                value = ""
            value = self.clean_attr_value(attr, value)
            if value == "":
                continue
            if tag == "img" and attr in ("width", "height"):
                value = self.clamped_image_dimension(attr, value)
                if value == "":
                    continue
            if attr == "style":
                value = self.clean_style_value(value)
                if value == "":
                    continue
            cleaned.append(f'{attr}="{html.escape(value, quote=True)}"')
        return (" " + " ".join(cleaned)) if cleaned else ""

    def clean_attr_value(self, attr, value):
        stripped = (value or "").strip()
        lowered = stripped.lower()
        if attr in ("href", "src"):
            if lowered.startswith("javascript:") or lowered.startswith("data:text/html"):
                return ""
            if lowered.startswith("cid:"):
                cid = urllib.parse.unquote(stripped[4:]).strip("<>")
                return self.cid_sources.get(cid, "")
            if attr == "src" and lowered.startswith("data:"):
                return stripped if lowered.startswith("data:image/") else ""
            if attr == "src" and lowered.startswith(("http://", "https://")):
                self.remote_image_count += 1
                if self.remote_image_loader is None:
                    return ""
                loaded = self.remote_image_loader(stripped) or ""
                if loaded:
                    self.remote_images_loaded += 1
                return loaded
            if stripped.startswith("//"):
                if attr == "src":
                    self.remote_image_count += 1
                    if self.remote_image_loader is None:
                        return ""
                    loaded = self.remote_image_loader("https:" + stripped) or ""
                    if loaded:
                        self.remote_images_loaded += 1
                    return loaded
                return "https:" + stripped
        return stripped

    def clean_style_value(self, value):
        cleaned = re.sub(r"(?is)url\s*\([^)]*\)", "", value or "")
        cleaned = re.sub(r"(?is)expression\s*\([^)]*\)", "", cleaned)
        return cleaned.strip()

    def clamped_image_dimension(self, attr, value):
        try:
            number = int(float(str(value).strip().rstrip("px")))
        except (TypeError, ValueError):
            return ""
        if number <= 0:
            return ""
        if attr == "width":
            number = min(number, HTML_IMAGE_MAX_WIDTH)
        return str(number)

    def is_tracking_image(self, attrs):
        mapped = {str(name or "").lower(): str(value or "").strip() for name, value in attrs or []}
        src = mapped.get("src", "").lower()
        try:
            width = int(float(mapped.get("width", "0").rstrip("px") or 0))
            height = int(float(mapped.get("height", "0").rstrip("px") or 0))
        except ValueError:
            width = 0
            height = 0
        if width and height and width <= 2 and height <= 2:
            return True
        return "pixel." in src or "tracking" in src or "/open" in src

    def html(self):
        return "".join(self.parts).strip()


class EmailTextExtractor(HTMLParser):
    block_tags = {
        "address", "article", "aside", "blockquote", "br", "caption", "div",
        "footer", "h1", "h2", "h3", "h4", "h5", "h6", "header", "hr", "li",
        "main", "p", "section", "table", "tbody", "td", "tfoot", "th", "thead",
        "tr", "ul", "ol",
    }

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []
        self.skip_stack = []

    def should_skip(self):
        return len(self.skip_stack) > 0

    def push_break(self):
        if self.parts and self.parts[-1] != "\n":
            self.parts.append("\n")

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        if tag in EmailHtmlSanitizer.block_tags:
            self.skip_stack.append(tag)
            return
        if self.should_skip():
            return
        if tag in self.block_tags:
            self.push_break()

    def handle_startendtag(self, tag, attrs):
        tag = tag.lower()
        if not self.should_skip() and tag in self.block_tags:
            self.push_break()

    def handle_endtag(self, tag):
        tag = tag.lower()
        if self.skip_stack:
            if tag == self.skip_stack[-1]:
                self.skip_stack.pop()
            return
        if tag in self.block_tags:
            self.push_break()

    def handle_data(self, data):
        if not self.should_skip() and data:
            self.parts.append(data)

    def text(self):
        return clean_reader_text("".join(self.parts))


def sanitize_html_email(raw_html, attachments, remote_image_loader=None):
    return sanitize_html_email_details(raw_html, attachments, remote_image_loader)["html"]


def sanitize_html_email_details(raw_html, attachments, remote_image_loader=None):
    if not raw_html:
        return html_details_payload("", 0, 0, 0, "", "plain", False, 0)
    prepared_html = html_body_fragment(strip_block_html(raw_html))
    table_count = count_html_tables(prepared_html)
    if should_use_reader_mode(prepared_html, table_count):
        reader_body = html_to_reader_text(prepared_html)
        return html_details_payload(
            reader_text_to_html(reader_body),
            0,
            0,
            len(prepared_html),
            reader_body,
            "reader",
            True,
            table_count,
        )

    cid_sources = {}
    for attachment in attachments or []:
        content_id = attachment.get("contentId", "")
        data_url_value = attachment.get("dataUrl", "")
        if content_id and data_url_value:
            cid_sources[content_id] = data_url_value

    parser = EmailHtmlSanitizer(cid_sources, remote_image_loader)
    parser.feed(prepared_html)
    parser.close()
    html_value = centered_html(parser.html())
    return html_details_payload(
        html_value,
        parser.remote_image_count,
        parser.remote_images_loaded,
        len(html_value),
        "",
        "html" if html_value else "plain",
        False,
        count_html_tables(html_value),
    )


def html_details_payload(html_value, remote_image_count, remote_images_loaded, html_length, reader_body, render_mode, suppressed, table_count):
    return {
        "html": html_value,
        "readerBody": reader_body,
        "htmlRenderMode": render_mode,
        "htmlSuppressed": suppressed,
        "htmlLength": html_length,
        "htmlTableCount": table_count,
        "remoteImageCount": remote_image_count,
        "remoteImagesLoadedCount": remote_images_loaded,
    }


def count_html_tables(value):
    return len(re.findall(r"(?is)<table\b", value or ""))


def should_use_reader_mode(value, table_count=None):
    html_value = value or ""
    tables = count_html_tables(html_value) if table_count is None else table_count
    return len(html_value) > HTML_RENDER_CHAR_LIMIT or tables > HTML_RENDER_TABLE_LIMIT


def has_escaped_reader_markup(value):
    return bool(re.search(r"(?is)&lt;\s*/?\s*(?:ul|ol|li)\b", value or ""))


def centered_html(value):
    html_value = (value or "").strip()
    if not html_value:
        return ""
    if re.match(r'(?is)^<div\s+align=["\']center["\']', html_value):
        return html_value
    return f'<div align="center">{html_value}</div>'


def html_to_reader_text(raw_html):
    if not raw_html:
        return ""
    parser = EmailTextExtractor()
    parser.feed(raw_html)
    parser.close()
    text = parser.text()
    if len(text) > HTML_READER_BODY_LIMIT:
        return text[: HTML_READER_BODY_LIMIT - 1].rstrip() + "..."
    return text


def clean_reader_text(value):
    text = html.unescape(value or "")
    text = INVISIBLE_TEXT_RE.sub("", text)
    raw_lines = text.replace("\r", "\n").splitlines()
    lines = []
    seen = set()
    previous_blank = False
    for raw_line in raw_lines:
        line = " ".join(raw_line.split()).strip()
        line = URL_TOKEN_RE.sub("", line)
        line = re.sub(r"\s+([,.;:!?])", r"\1", line)
        line = re.sub(r"\s{2,}", " ", line).strip(" \t|")
        if not line or re.fullmatch(r"[-–—_.,;:|/\\ ]+", line):
            if lines and not previous_blank:
                lines.append("")
            previous_blank = True
            continue
        lowered = line.lower()
        if lowered in seen:
            continue
        seen.add(lowered)
        lines.append(line)
        previous_blank = False
    return "\n".join(lines).strip()


def reader_text_to_html(value):
    text = clean_reader_text(value)
    if not text:
        return ""
    parts = ['<div align="left">']
    in_list = False
    for line in text.splitlines():
        raw_line = html.unescape(line).strip()
        lowered = raw_line.lower()
        if re.fullmatch(r"<(?:ul|ol)\b[^>]*>", lowered):
            if not in_list:
                parts.append("<ul>")
                in_list = True
            continue
        if re.fullmatch(r"</(?:ul|ol)\s*>", lowered):
            if in_list:
                parts.append("</ul>")
                in_list = False
            continue
        item_match = re.fullmatch(r"(?is)<li\b[^>]*>(.*?)</li\s*>", raw_line)
        if item_match:
            if not in_list:
                parts.append("<ul>")
                in_list = True
            item = clean_reader_text(item_match.group(1))
            if item:
                parts.append(f"<li>{html.escape(item, quote=False)}</li>")
            continue

        if not raw_line:
            if in_list:
                continue
            parts.append("<br />")
            continue
        if in_list:
            parts.append("</ul>")
            in_list = False
        parts.append(f"<p>{html.escape(raw_line, quote=False)}</p>")
    if in_list:
        parts.append("</ul>")
    parts.append("</div>")
    return "".join(parts)


def html_body_fragment(raw_html):
    match = re.search(r"(?is)<body\b[^>]*>", raw_html or "")
    if not match:
        return raw_html or ""
    fragment = raw_html[match.end():]
    end = re.search(r"(?is)</body\s*>", fragment)
    if end:
        fragment = fragment[: end.start()]
    return fragment


def strip_block_html(raw_html):
    value = raw_html or ""
    for tag in ("script", "style", "head", "iframe", "object", "embed", "form", "svg"):
        value = re.sub(rf"(?is)<{tag}\b[^>]*>.*?</{tag}\s*>", "", value)
    value = re.sub(r"(?is)<!--.*?-->", "", value)
    return value


def clean_text(value, limit=0):
    text = html.unescape(value or "")
    text = " ".join(text.replace("\r", "\n").split())
    if limit and len(text) > limit:
        return text[: limit - 1].rstrip() + "..."
    return text


def account_cache_id(token):
    account = (token.get("account") or "default").strip().lower()
    digest = hashlib.sha256(account.encode("utf-8")).hexdigest()
    return digest[:24]


def cache_key(folder, message_filter, query, limit, page_token):
    payload = {
        "folder": folder,
        "filter": message_filter,
        "query": query or "",
        "pageToken": page_token or "",
    }
    raw = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def cache_path(token, folder, message_filter, query, limit, page_token):
    return CACHE_DIR / account_cache_id(token) / f"{cache_key(folder, message_filter, query, limit, page_token)}.json"


def read_cache(token, folder, message_filter, query, limit, page_token):
    candidates = [cache_path(token, folder, message_filter, query, limit, page_token)]
    cache_root = CACHE_DIR / account_cache_id(token)
    if cache_root.exists():
        candidates.extend(sorted(cache_root.glob("*.json"), key=lambda path: path.stat().st_mtime, reverse=True))

    seen = set()
    for path in candidates:
        if path in seen:
            continue
        seen.add(path)
        try:
            payload = load_json(path)
        except (FileNotFoundError, json.JSONDecodeError, OSError):
            continue

        if payload.get("provider") != "gmail" or not isinstance(payload.get("messages"), list):
            continue
        if payload.get("folder") != folder or payload.get("filter") != message_filter:
            continue
        if (payload.get("query") or "") != (query or ""):
            continue
        if (payload.get("pageToken") or "") != (page_token or ""):
            continue
        try:
            cache_version = int(payload.get("cacheVersion", 0) or 0)
        except (TypeError, ValueError):
            cache_version = 0
        if cache_version != CACHE_VERSION:
            continue

        if upgrade_cached_payload(payload):
            payload["cachedAt"] = time.time()
            try:
                write_json(path, payload)
            except OSError:
                pass

        payload["cached"] = True
        payload["cachePath"] = str(path)
        payload["cacheStale"] = False
        return payload

    return None


def write_cache(token, folder, message_filter, query, limit, page_token, payload):
    path = cache_path(token, folder, message_filter, query, limit, page_token)
    cached_payload = dict(payload)
    cached_payload["cacheVersion"] = CACHE_VERSION
    cached_payload["cachedAt"] = time.time()
    cached_payload["cached"] = False
    cached_payload["cacheStale"] = False
    cached_payload["cachePath"] = str(path)
    write_json(path, cached_payload)


def update_cached_message(token, message):
    cache_root = CACHE_DIR / account_cache_id(token)
    if not cache_root.exists():
        return

    message_id = message.get("messageId", "")
    if not message_id:
        return

    for path in cache_root.glob("*.json"):
        try:
            payload = load_json(path)
        except (json.JSONDecodeError, OSError):
            continue

        messages = payload.get("messages", [])
        changed = False
        for index, cached_message in enumerate(messages):
            if cached_message.get("messageId") == message_id:
                messages[index] = message
                changed = True

        if changed:
            payload["messages"] = messages
            payload["cachedAt"] = time.time()
            write_json(path, payload)


def upgrade_cached_payload(payload):
    changed = False
    messages = payload.get("messages", [])
    for index, cached_message in enumerate(messages):
        upgraded, message_changed = upgrade_cached_message(cached_message)
        if message_changed:
            messages[index] = upgraded
            changed = True
    if changed:
        payload["messages"] = messages
    return changed


def upgrade_cached_message(message):
    if not isinstance(message, dict):
        return message, False

    upgraded = dict(message)
    changed = False
    html_value = upgraded.get("htmlBody") or ""
    table_count = int(upgraded.get("htmlTableCount") or count_html_tables(html_value) or 0)

    if upgraded.get("htmlRenderMode") == "reader" or has_escaped_reader_markup(html_value):
        reader_source = upgraded.get("body") or upgraded.get("preview") or ""
        if html_value:
            extracted = html_to_reader_text(html_value)
            if len(extracted) > len(clean_reader_text(reader_source)):
                reader_source = extracted
        reader_body = clean_reader_text(reader_source)
        reader_html = reader_text_to_html(reader_body)
        if upgraded.get("body") != reader_body and reader_body:
            upgraded["body"] = reader_body
            changed = True
        if upgraded.get("htmlBody") != reader_html:
            upgraded["htmlBody"] = reader_html
            changed = True
        if upgraded.get("htmlRenderMode") != "reader":
            upgraded["htmlRenderMode"] = "reader"
            changed = True
        if upgraded.get("htmlSuppressed") is not True:
            upgraded["htmlSuppressed"] = True
            changed = True
        html_length = int(upgraded.get("htmlLength") or len(html_value) or 0)
        if upgraded.get("htmlLength") != html_length:
            upgraded["htmlLength"] = html_length
            changed = True
        if upgraded.get("htmlTableCount") != table_count:
            upgraded["htmlTableCount"] = table_count
            changed = True
        if upgraded.get("remoteImageCount", 0) != 0:
            upgraded["remoteImageCount"] = 0
            changed = True
        if upgraded.get("remoteImagesLoadedCount", 0) != 0:
            upgraded["remoteImagesLoadedCount"] = 0
            changed = True
        if upgraded.get("remoteImagesLoaded") is not False:
            upgraded["remoteImagesLoaded"] = False
            changed = True
    elif html_value and should_use_reader_mode(html_value, table_count):
        reader_body = html_to_reader_text(html_value)
        body_value = upgraded.get("body") or upgraded.get("preview") or ""
        body_length = len(clean_text(body_value))
        if reader_body and body_length < HTML_READER_BODY_MIN_CHARS and len(reader_body) > body_length:
            upgraded["body"] = reader_body
        upgraded["htmlBody"] = reader_text_to_html(reader_body)
        upgraded["htmlRenderMode"] = "reader"
        upgraded["htmlSuppressed"] = True
        upgraded["htmlLength"] = len(html_value)
        upgraded["htmlTableCount"] = table_count
        upgraded["remoteImageCount"] = 0
        upgraded["remoteImagesLoadedCount"] = 0
        upgraded["remoteImagesLoaded"] = False
        changed = True
    elif html_value:
        centered = centered_html(html_value)
        if centered != html_value:
            upgraded["htmlBody"] = centered
            changed = True
        if upgraded.get("htmlRenderMode") != "html":
            upgraded["htmlRenderMode"] = "html"
            changed = True
        if bool(upgraded.get("htmlSuppressed")):
            upgraded["htmlSuppressed"] = False
            changed = True
        html_length = len(centered)
        if upgraded.get("htmlLength") != html_length:
            upgraded["htmlLength"] = html_length
            changed = True
        if upgraded.get("htmlTableCount") != count_html_tables(centered):
            upgraded["htmlTableCount"] = count_html_tables(centered)
            changed = True
    else:
        defaults = {
            "htmlRenderMode": upgraded.get("htmlRenderMode") or "plain",
            "htmlSuppressed": bool(upgraded.get("htmlSuppressed", False)),
            "htmlLength": int(upgraded.get("htmlLength") or 0),
            "htmlTableCount": int(upgraded.get("htmlTableCount") or 0),
        }
        for key, value in defaults.items():
            if upgraded.get(key) != value:
                upgraded[key] = value
                changed = True

    return upgraded, changed


def header_value(headers, name):
    wanted = name.lower()
    for header_name, value in (headers or {}).items():
        if header_name.lower() == wanted:
            return value
    return ""


def attachment_label(filename, mime, content_id):
    if filename:
        return filename
    if content_id:
        return content_id.strip("<>")
    if mime.startswith("image/"):
        return "Inline image"
    return "Attachment"


def extract_attachments(payload, attachment_loader=None):
    attachments = []

    def walk(part):
        if not part:
            return

        mime = part.get("mimeType", "")
        if mime.startswith("multipart/"):
            for child in part.get("parts", []) or []:
                walk(child)
            return

        body = part.get("body", {}) or {}
        headers = headers_to_dict(part.get("headers", []))
        filename = (part.get("filename") or "").strip()
        attachment_id = body.get("attachmentId", "")
        size = int(body.get("size", 0) or 0)
        content_id = header_value(headers, "Content-ID").strip()
        disposition = header_value(headers, "Content-Disposition").strip()
        disposition_lower = disposition.lower()
        is_image = mime.startswith("image/")
        is_text_body = mime.startswith("text/plain") or mime.startswith("text/html")
        is_explicit_attachment = bool(filename or disposition_lower.startswith("attachment"))
        is_attachment = bool(
            is_explicit_attachment
            or (attachment_id and not is_text_body)
            or (is_image and (body.get("data") or content_id))
        )

        if is_attachment:
            data = body.get("data", "")
            if (
                not data
                and attachment_id
                and attachment_loader is not None
                and is_image
                and size <= INLINE_IMAGE_LIMIT_BYTES
            ):
                data = attachment_loader(attachment_id) or ""

            attachments.append({
                "id": attachment_id or content_id.strip("<>") or f"part-{len(attachments) + 1}",
                "name": attachment_label(filename, mime, content_id),
                "mimeType": mime or "application/octet-stream",
                "size": size,
                "inline": disposition_lower.startswith("inline") or bool(content_id and not filename),
                "contentId": content_id.strip("<>"),
                "dataUrl": data_url(mime, data) if is_image and data else "",
            })

        for child in part.get("parts", []) or []:
            walk(child)

    walk(payload)
    return attachments


def folder_from_labels(labels):
    label_set = set(labels or [])
    if "TRASH" in label_set:
        return "Trash"
    if "SENT" in label_set:
        return "Sent"
    if "DRAFT" in label_set:
        return "Drafts"
    if "INBOX" in label_set:
        return "Inbox"
    return "Archive"


def normalize_message(message, attachment_loader=None, remote_image_loader=None):
    labels = message.get("labelIds", [])
    payload = message.get("payload", {})
    headers = parse_headers(headers_to_dict(payload.get("headers", [])))
    body = extract_plain_text(payload).strip()
    attachments = extract_attachments(payload, attachment_loader)
    html_details = sanitize_html_email_details(extract_html_body(payload, attachment_loader), attachments, remote_image_loader)
    body_for_display = body
    if (
        html_details["htmlSuppressed"]
        and html_details["readerBody"]
        and len(clean_text(body_for_display)) < HTML_READER_BODY_MIN_CHARS
        and len(html_details["readerBody"]) > len(clean_text(body_for_display))
    ):
        body_for_display = html_details["readerBody"]
    snippet = clean_text(message.get("snippet", ""), 140)
    folder = folder_from_labels(labels)

    return {
        "messageId": message.get("id", ""),
        "folder": folder,
        "fromName": headers["fromName"],
        "fromAddress": headers["fromAddress"],
        "subject": headers["subject"],
        "preview": snippet or clean_text(body_for_display, 140) or "No preview available",
        "body": body_for_display or snippet or "No plain text body available.",
        "htmlBody": html_details["html"],
        "htmlRenderMode": html_details["htmlRenderMode"],
        "htmlSuppressed": html_details["htmlSuppressed"],
        "htmlLength": html_details["htmlLength"],
        "htmlTableCount": html_details["htmlTableCount"],
        "timestamp": headers["timestamp"],
        "tag": "Gmail" if folder == "Inbox" else folder,
        "starred": "STARRED" in labels,
        "isRead": "UNREAD" not in labels,
        "importance": "high" if "IMPORTANT" in labels else "normal",
        "attachments": attachments,
        "remoteImageCount": html_details["remoteImageCount"],
        "remoteImagesLoadedCount": html_details["remoteImagesLoadedCount"],
        "remoteImagesLoaded": html_details["remoteImagesLoadedCount"] > 0,
    }


def attachment_loader_for(token, quoted_message_id):
    def load_attachment(attachment_id):
        try:
            payload = api_request(
                "GET",
                f"/messages/{quoted_message_id}/attachments/{urllib.parse.quote(attachment_id)}",
                token,
            )
            return payload.get("data", "")
        except GmailBridgeError:
            return ""

    return load_attachment


def remote_image_loader_for():
    state = {"count": 0, "bytes": 0}

    def load_remote_image(url):
        if state["count"] >= REMOTE_IMAGE_LIMIT or state["bytes"] >= REMOTE_IMAGE_TOTAL_BYTES:
            return ""

        parsed = urllib.parse.urlparse(url)
        if parsed.scheme not in ("http", "https") or not parsed.netloc:
            return ""

        request = urllib.request.Request(
            url,
            headers={
                "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
                "User-Agent": "AstreaEmail/0.1",
            },
            method="GET",
        )
        try:
            with urllib.request.urlopen(request, timeout=3) as response:
                mime = response.headers.get_content_type() or ""
                if not mime.startswith("image/"):
                    return ""
                raw = response.read(REMOTE_IMAGE_MAX_BYTES + 1)
        except (OSError, TimeoutError, urllib.error.URLError, urllib.error.HTTPError):
            return ""

        if len(raw) > REMOTE_IMAGE_MAX_BYTES:
            return ""
        if state["bytes"] + len(raw) > REMOTE_IMAGE_TOTAL_BYTES:
            return ""

        state["count"] += 1
        state["bytes"] += len(raw)
        encoded = base64.b64encode(raw).decode("ascii")
        return f"data:{mime};base64,{encoded}"

    return load_remote_image


def fetch_message(message_id, token=None, load_remote_images=False):
    active_token = token or ensure_token()
    quoted_id = urllib.parse.quote(message_id)
    payload = api_request("GET", f"/messages/{quoted_id}", active_token, query={"format": "full"})
    message = normalize_message(
        payload,
        attachment_loader=attachment_loader_for(active_token, quoted_id),
        remote_image_loader=remote_image_loader_for() if load_remote_images else None,
    )
    if load_remote_images:
        update_cached_message(active_token, message)
    return message


def empty_cached_payload(folder, message_filter, query, page_token):
    return {
        "ok": True,
        "provider": "gmail",
        "folder": folder,
        "filter": message_filter,
        "query": query,
        "pageToken": page_token or "",
        "messages": [],
        "resultSizeEstimate": 0,
        "nextPageToken": "",
        "cached": False,
        "cacheMiss": True,
    }


def payload_matches_cache_request(payload, folder, message_filter, query, page_token):
    if payload.get("provider") != "gmail" or not isinstance(payload.get("messages"), list):
        return False
    if payload.get("folder") != folder or payload.get("filter") != message_filter:
        return False
    if (payload.get("query") or "") != (query or ""):
        return False
    if (payload.get("pageToken") or "") != (page_token or ""):
        return False
    try:
        cache_version = int(payload.get("cacheVersion", 0) or 0)
    except (TypeError, ValueError):
        cache_version = 0
    return cache_version == CACHE_VERSION


def cached_messages_by_id(token, folder, message_filter, query, page_token):
    cache_root = CACHE_DIR / account_cache_id(token)
    if not cache_root.exists():
        return {}

    cached = {}
    for path in sorted(cache_root.glob("*.json"), key=lambda candidate: candidate.stat().st_mtime, reverse=True):
        try:
            payload = load_json(path)
        except (FileNotFoundError, json.JSONDecodeError, OSError):
            continue
        if not payload_matches_cache_request(payload, folder, message_filter, query, page_token):
            continue
        if upgrade_cached_payload(payload):
            payload["cachedAt"] = time.time()
            try:
                write_json(path, payload)
            except OSError:
                pass
        for message in payload.get("messages", []):
            message_id = message.get("messageId", "")
            if message_id and message_id not in cached:
                cached[message_id] = message
    return cached


def list_messages(folder, message_filter, query, limit, page_token="", force_refresh=False, use_cache=True, cache_only=False):
    token = ensure_token()
    search = build_query(folder, message_filter, query)
    requested_limit = max(1, min(int(limit), GMAIL_TOTAL_LIMIT))
    if use_cache and not force_refresh:
        cached_payload = read_cache(token, folder, message_filter, query, requested_limit, page_token)
        if cached_payload is not None:
            return cached_payload
        if cache_only:
            return empty_cached_payload(folder, message_filter, query, page_token)

    messages = []
    cached_messages = cached_messages_by_id(token, folder, message_filter, query, page_token) if use_cache else {}
    result_size_estimate = 0
    next_page_token = page_token or ""

    while len(messages) < requested_limit:
        page_size = min(GMAIL_PAGE_LIMIT, requested_limit - len(messages))
        request_query = {
            "maxResults": str(page_size),
            "q": search,
            "includeSpamTrash": "true" if folder == "Trash" else "false",
        }
        if next_page_token:
            request_query["pageToken"] = next_page_token

        response = api_request("GET", "/messages", token, query=request_query)
        result_size_estimate = response.get("resultSizeEstimate", result_size_estimate)
        page_items = response.get("messages", [])
        next_page_token = response.get("nextPageToken", "")

        if not page_items:
            break

        for item in page_items:
            message_id = item.get("id", "")
            if not message_id:
                continue

            cached_message = cached_messages.get(message_id)
            if cached_message is not None:
                messages.append(cached_message)
            else:
                messages.append(fetch_message(message_id, token=token, load_remote_images=False))
            if len(messages) >= requested_limit:
                break

        if not next_page_token:
            break

    payload = {
        "ok": True,
        "provider": "gmail",
        "folder": folder,
        "filter": message_filter,
        "query": query,
        "pageToken": page_token or "",
        "messages": messages,
        "resultSizeEstimate": result_size_estimate or len(messages),
        "nextPageToken": next_page_token,
        "cached": False,
        "cacheMiss": False,
    }
    if use_cache:
        write_cache(token, folder, message_filter, query, requested_limit, page_token, payload)
    return payload


def modify_plan(action):
    plans = {
        "read": {"endpoint": "modify", "body": {"removeLabelIds": ["UNREAD"]}},
        "unread": {"endpoint": "modify", "body": {"addLabelIds": ["UNREAD"]}},
        "star": {"endpoint": "modify", "body": {"addLabelIds": ["STARRED"]}},
        "unstar": {"endpoint": "modify", "body": {"removeLabelIds": ["STARRED"]}},
        "archive": {"endpoint": "modify", "body": {"removeLabelIds": ["INBOX"]}},
        "trash": {"endpoint": "trash", "body": {}},
        "inbox": {"endpoint": "untrash", "body": {}},
    }
    if action not in plans:
        raise GmailBridgeError(f"Unsupported Gmail action: {action}")
    return plans[action]


def modify_message(message_id, action):
    token = ensure_token()
    quoted_id = urllib.parse.quote(message_id)
    plan = modify_plan(action)

    if plan["endpoint"] == "modify":
        api_request("POST", f"/messages/{quoted_id}/modify", token, body=plan["body"])
    else:
        api_request("POST", f"/messages/{quoted_id}/{plan['endpoint']}", token, body=plan["body"])
        if action == "inbox":
            api_request(
                "POST",
                f"/messages/{quoted_id}/modify",
                token,
                body={"addLabelIds": ["INBOX"], "removeLabelIds": ["TRASH"]},
            )

    payload = api_request("GET", f"/messages/{quoted_id}", token, query={"format": "full"})
    message = normalize_message(
        payload,
        attachment_loader=attachment_loader_for(token, quoted_id),
    )
    update_cached_message(token, message)
    return {
        "ok": True,
        "provider": "gmail",
        "action": action,
        "messageId": message_id,
        "message": message,
    }


def get_message(message_id, load_remote_images=False):
    message = fetch_message(message_id, load_remote_images=load_remote_images)
    return {"ok": True, "provider": "gmail", "messageId": message_id, "message": message}


def create_send_payload(to, subject, body):
    message = EmailMessage()
    message["To"] = to
    message["Subject"] = subject
    message.set_content(body or "")
    raw = base64.urlsafe_b64encode(message.as_bytes()).decode("ascii").rstrip("=")
    return {"raw": raw}


def send_message(to, subject, body):
    token = ensure_token()
    payload = api_request("POST", "/messages/send", token, body=create_send_payload(to, subject, body))
    return {"ok": True, "provider": "gmail", "messageId": payload.get("id", ""), "threadId": payload.get("threadId", "")}


def status_payload():
    path = credentials_path()
    token = read_token()
    state = token_state(token)
    configured = path.exists()
    authenticated = configured and state in ("valid", "refreshable")

    if not configured:
        message = f"Add Gmail OAuth client at {path}"
    elif authenticated:
        message = "Gmail ready"
    else:
        message = "Connect Gmail"

    return {
        "ok": True,
        "provider": "gmail",
        "configured": configured,
        "authenticated": authenticated,
        "credentialsPath": str(path),
        "tokenPath": str(TOKEN_PATH),
        "tokenState": state,
        "account": token.get("account", ""),
        "scopes": SCOPES,
        "messages": [],
        "message": message,
    }


def auth_payload():
    token = authenticate()
    payload = status_payload()
    payload["account"] = token.get("account", "")
    payload["message"] = "Gmail connected"
    return payload
