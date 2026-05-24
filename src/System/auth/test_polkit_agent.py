#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
import unittest
from pathlib import Path


AUTH_DIR = Path(__file__).resolve().parent
SYSTEM_DIR = AUTH_DIR.parent
AGENT = AUTH_DIR / "astrea-polkit-agent.py"
PROMPT = AUTH_DIR / "astrea-polkit-prompt.py"
QML_AGENT = AUTH_DIR / "astrea-polkit-agent.qml"
SERVICE = SYSTEM_DIR / "services/astrea-polkit-agent.service"
I18N_DIR = SYSTEM_DIR / "i18n"
HYPR_WINDOW_RULES = Path.home() / ".config/hypr/system/rules/windowrules.conf"


def load_agent_module():
    spec = importlib.util.spec_from_file_location("astrea_polkit_agent", AGENT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class AstreaPolkitAgentTests(unittest.TestCase):
    def test_agent_uses_libpolkit_agent_session(self):
        source = AGENT.read_text()
        self.assertIn("class AstreaPolkitListener(PolkitAgent.Listener)", source)
        self.assertIn("PolkitAgent.Session.new", source)
        self.assertIn("Gio.Task.new", source)
        self.assertIn(".register(", source)

    def test_prompt_command_never_contains_password(self):
        agent = load_agent_module()
        request = agent.PromptRequest(
            action_id="org.example.admin",
            message="Authentication is required",
            user="agony",
            request="Password:",
            echo_on=False,
            error="",
            info="",
        )
        command = agent.build_prompt_command(request)
        joined = "\n".join(command)
        self.assertIn(str(PROMPT), command)
        self.assertIn("--message", command)
        self.assertNotIn("secret-password", joined)
        self.assertNotIn("--password", joined)

    def test_prompt_has_noninteractive_self_test(self):
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen")
        result = subprocess.run(
            [sys.executable, str(PROMPT), "--self-test"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
            timeout=10,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("astrea-polkit-prompt-ok", result.stdout)

    def test_prompt_uses_gtk_api_names(self):
        source = PROMPT.read_text()
        self.assertIn("set_title(", source)
        self.assertIn("set_resizable(False)", source)
        self.assertNotIn("setWindowTitle", source)
        self.assertIn("GLib.MainLoop()", source)
        self.assertNotIn("Gtk.Application(", source)

    def test_agent_cancellable_callback_accepts_gi_signal_args(self):
        source = AGENT.read_text()
        self.assertIn("lambda *_args: proc.terminate()", source)

    def test_user_service_replaces_hyprpolkitagent(self):
        source = SERVICE.read_text()
        self.assertIn("Conflicts=hyprpolkitagent.service", source)
        self.assertIn("ExecStart=", source)
        self.assertIn("/usr/bin/quickshell -p", source)
        self.assertIn("astrea-polkit-agent.qml", source)

    def test_quickshell_agent_is_floating_window(self):
        source = QML_AGENT.read_text()
        self.assertIn("import Quickshell.Services.Polkit", source)
        self.assertIn("PolkitAgent", source)
        self.assertIn("FloatingWindow", source)
        self.assertIn('title: "Astrea Authentication"', source)
        self.assertIn("implicitWidth: 360", source)
        self.assertIn("implicitHeight: 372", source)
        self.assertIn("minimumSize: Qt.size(360, 372)", source)
        self.assertIn("maximumSize: Qt.size(360, 372)", source)
        self.assertNotIn("PanelWindow", source)
        self.assertNotIn("WlrLayershell.layer", source)
        self.assertIn("activeFlow().submit(passwordField.text)", source)

    def test_quickshell_agent_uses_macos_style_profile_avatar(self):
        source = QML_AGENT.read_text()
        self.assertIn('readonly property string avatarPath: "/var/lib/AccountsService/icons/" + userName', source)
        self.assertIn("import Qt5Compat.GraphicalEffects", source)
        self.assertIn("source: root.avatarPath", source)
        self.assertIn("OpacityMask", source)
        self.assertIn("MacAuthTextField", source)
        self.assertIn("id: usernameField", source)
        self.assertIn("usernameField.text.trim() !== userName", source)
        self.assertIn("usernameField.text = \"\"", source)
        self.assertIn("root.authLocked", source)
        self.assertIn("function polishedMessage()", source)
        self.assertIn("features.polkit.auth.permission_message", source)
        self.assertIn("message.length > 88", source)
        self.assertIn("shakeAnim", source)
        self.assertIn('property: "shakeOffset"', source)
        self.assertIn('root.t("features.polkit.auth.username", "Username")', source)
        self.assertIn('root.t("features.polkit.auth.password", "Password")', source)
        self.assertIn("MacAuthButton", source)

    def test_quickshell_agent_uses_astrea_theme_and_i18n(self):
        source = QML_AGENT.read_text()
        self.assertIn("import Quickshell.Io", source)
        self.assertIn("/.config/AstreaOS/ui/theme.json", source)
        self.assertIn("/System/i18n/i18n.py", source)
        self.assertIn("property int themeMode", source)
        self.assertIn("property int shellStyle", source)
        self.assertIn("readonly property color popupBg", source)
        self.assertIn("readonly property color windowWash", source)
        self.assertIn("readonly property color cardBorder", source)
        self.assertIn("readonly property color textPrimary", source)
        self.assertIn("readonly property color textSecondary", source)
        self.assertIn("readonly property color accent", source)
        self.assertIn("function t(key, fallback)", source)

    def test_polkit_strings_exist_in_supported_languages(self):
        required_keys = {
            "features.polkit.auth.cancel",
            "features.polkit.auth.default_message",
            "features.polkit.auth.empty_password",
            "features.polkit.auth.failed",
            "features.polkit.auth.instruction",
            "features.polkit.auth.invalid_user",
            "features.polkit.auth.ok",
            "features.polkit.auth.password",
            "features.polkit.auth.permission_message",
            "features.polkit.auth.title",
            "features.polkit.auth.username",
        }
        for locale in ("en_US", "pt_BR"):
            with self.subTest(locale=locale):
                payload = json.loads((I18N_DIR / f"{locale}.json").read_text())
                self.assertTrue(required_keys.issubset(payload))
                for key in required_keys:
                    self.assertIsInstance(payload[key], str)
                    self.assertNotEqual(payload[key].strip(), "")

    def test_hyprland_window_rule_keeps_auth_prompt_float_without_forced_focus(self):
        source = HYPR_WINDOW_RULES.read_text()
        self.assertIn("name        = astrea-polkit-auth", source)
        self.assertIn("match:class = org.quickshell", source)
        self.assertIn("match:title = ^(Astrea Authentication)$", source)
        self.assertIn("float       = yes", source)
        self.assertIn("center      = yes", source)
        self.assertNotIn("stay_focused = yes", source)
        self.assertNotIn("dim_around  = yes", source)
        self.assertIn("no_blur     = true", source)



if __name__ == "__main__":
    unittest.main()
