#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys

def load_gtk():
    import gi
    gi.require_version("Gtk", "4.0")
    gi.require_version("Gdk", "4.0")
    gi.require_version("GLib", "2.0")
    from gi.repository import Gdk, GLib, Gtk
    return Gdk, GLib, Gtk


class PromptWindow:
    def __init__(self, args: argparse.Namespace, loop, exit_code: list[int], Gtk) -> None:
        self.args = args
        self.loop = loop
        self.exit_code = exit_code
        self.window = Gtk.Window()
        self.window.connect("close-request", self.cancel)
        self.window.set_title("Astrea Authentication")
        self.window.set_default_size(430, -1)
        self.window.set_resizable(False)
        self.window.set_modal(True)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        root.set_margin_top(18)
        root.set_margin_bottom(18)
        root.set_margin_start(18)
        root.set_margin_end(18)
        self.window.set_child(root)

        title = Gtk.Label(label="Authentication Required", xalign=0)
        title.add_css_class("title")
        root.append(title)

        message = Gtk.Label(label=args.message or "Authentication is required.", xalign=0)
        message.set_wrap(True)
        message.add_css_class("muted")
        root.append(message)

        meta = Gtk.Label(label=f"{args.user} · {args.action_id}", xalign=0)
        meta.set_wrap(True)
        meta.add_css_class("meta")
        root.append(meta)

        if args.info:
            info = Gtk.Label(label=args.info, xalign=0)
            info.set_wrap(True)
            info.add_css_class("muted")
            root.append(info)

        if args.error:
            error = Gtk.Label(label=args.error, xalign=0)
            error.set_wrap(True)
            error.add_css_class("error")
            root.append(error)

        field_frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        field_frame.add_css_class("field-frame")
        field_frame.set_margin_top(2)
        field_frame.set_margin_bottom(2)
        field_frame.set_margin_start(0)
        field_frame.set_margin_end(0)

        prompt = Gtk.Label(label=args.request or "Password:", xalign=0)
        prompt.add_css_class("muted")
        field_frame.append(prompt)

        self.input = Gtk.Entry()
        self.input.set_visibility(bool(args.echo_on))
        self.input.set_activates_default(True)
        self.input.connect("activate", lambda _entry: self.accept())
        field_frame.append(self.input)
        root.append(field_frame)

        buttons = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        buttons.set_halign(Gtk.Align.END)
        cancel = Gtk.Button(label="Cancel")
        cancel.connect("clicked", lambda _button: self.cancel())
        buttons.append(cancel)
        auth = Gtk.Button(label="Authenticate")
        auth.add_css_class("suggested-action")
        auth.connect("clicked", lambda _button: self.accept())
        buttons.append(auth)
        root.append(buttons)

        self.input.grab_focus()

    def accept(self) -> None:
        print(self.input.get_text(), flush=True)
        self.exit_code[0] = 0
        self.loop.quit()

    def cancel(self, *_args) -> bool:
        self.exit_code[0] = 1
        self.loop.quit()
        return True


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Astrea polkit password prompt")
    parser.add_argument("--message", default="")
    parser.add_argument("--action-id", default="")
    parser.add_argument("--user", default="")
    parser.add_argument("--request", default="Password:")
    parser.add_argument("--echo-on", action="store_true")
    parser.add_argument("--error", default="")
    parser.add_argument("--info", default="")
    parser.add_argument("--self-test", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.self_test:
        print("astrea-polkit-prompt-ok")
        return 0
    Gdk, GLib, Gtk = load_gtk()

    css = Gtk.CssProvider()
    css.load_from_data(
        b"""
        window {
            background: #14171c;
            color: #f2f5f8;
            font-family: Inter, sans-serif;
            font-size: 13px;
        }
        .title {
            font-size: 18px;
            font-weight: 600;
            color: #f2f5f8;
        }
        .muted, .meta {
            color: #aeb7c2;
        }
        .meta {
            font-size: 11px;
        }
        .error {
            color: #ff7b72;
        }
        .field-frame {
            background: #1d222a;
            border: 1px solid #303844;
            border-radius: 8px;
            padding: 10px;
        }
        entry {
            min-height: 30px;
            background: #0f1217;
            color: #f2f5f8;
            border: 1px solid #3a4452;
            border-radius: 6px;
            padding: 4px 8px;
        }
        button {
            min-height: 30px;
            padding: 0 14px;
            border-radius: 6px;
            background: #242b35;
            border: 1px solid #3a4452;
            color: #f2f5f8;
        }
        button.suggested-action {
            background: #4f7cff;
            border-color: #6c91ff;
        }
        """
    )
    Gtk.init()
    display = Gdk.Display.get_default()
    if display is None:
        print("No graphical display available for Astrea polkit prompt.", file=sys.stderr)
        return 2
    Gtk.StyleContext.add_provider_for_display(
        display,
        css,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )
    loop = GLib.MainLoop()
    exit_code = [1]
    window = PromptWindow(args, loop, exit_code, Gtk)
    window.window.present()
    loop.run()
    window.window.destroy()
    return int(exit_code[0])


if __name__ == "__main__":
    raise SystemExit(main())
