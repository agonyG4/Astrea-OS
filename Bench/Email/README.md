# Email Bench

Astrea-styled Quickshell email app prototype for `/home/agony/GitHub/Bench`.

Run it with:

```bash
qs -p /home/agony/GitHub/Bench/Email
```

The app uses `AstreaComponents` as a symlink to the live Astrea component set.

## Structure

- `Main.qml`: window composition and Gmail action wiring.
- `components/`: reusable Astrea UI pieces for the sidebar, message list, detail pane and composer.
- `state/MailStore.qml`: mailbox models, filters and selection. It starts empty until a backend returns messages.
- `services/EmailCliClient.qml`: thin Quickshell client that only calls the CLI.
- `backend/astrea_email/`: reusable Python backend package.
- `bin/astrea-email`: public JSON CLI for any app to call.
- `scripts/gmail_bridge.py`: compatibility wrapper for the CLI.
- `scripts/test_*.py`: backend and CLI tests.

## Gmail

Create a Google OAuth client for a Desktop app and put the downloaded JSON at:

```bash
~/.config/AstreaOS/email/gmail_client_secret.json
```

You can also point to another file with `ASTREA_EMAIL_GMAIL_CLIENT_SECRET`.
The app stores the token at `~/.local/state/Astrea/email/gmail_token.json`.

Any Astrea app can use the backend directly:

```bash
/home/agony/GitHub/Bench/Email/bin/astrea-email status
/home/agony/GitHub/Bench/Email/bin/astrea-email list --folder Inbox --filter unread
/home/agony/GitHub/Bench/Email/bin/astrea-email send --to user@example.com --subject "Hello" --body "Body"
```
