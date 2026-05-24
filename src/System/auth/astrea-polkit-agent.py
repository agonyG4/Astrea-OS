#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import pwd
import subprocess
import sys
import warnings
from pathlib import Path
from typing import NamedTuple

import gi

from gi import PyGIDeprecationWarning

warnings.filterwarnings("ignore", category=PyGIDeprecationWarning)
gi.require_version("Gio", "2.0")
gi.require_version("GLib", "2.0")
gi.require_version("Polkit", "1.0")
gi.require_version("PolkitAgent", "1.0")
from gi.repository import Gio, GLib, GObject, Polkit, PolkitAgent


AUTH_DIR = Path(__file__).resolve().parent
PROMPT_PATH = AUTH_DIR / "astrea-polkit-prompt.py"
AGENT_OBJECT_PATH = "/org/astrea/PolicyKit1/AuthenticationAgent"


class PromptRequest(NamedTuple):
    action_id: str
    message: str
    user: str
    request: str
    echo_on: bool
    error: str = ""
    info: str = ""


class PromptCancelled(Exception):
    pass


def identity_user_name(identity) -> str:
    if hasattr(identity, "get_name"):
        name = identity.get_name()
        if name:
            return str(name)
    if hasattr(identity, "get_uid"):
        try:
            return pwd.getpwuid(identity.get_uid()).pw_name
        except KeyError:
            return str(identity.get_uid())
    return os.environ.get("USER") or "user"


def build_prompt_command(request: PromptRequest) -> list[str]:
    command = [
        sys.executable,
        str(PROMPT_PATH),
        "--message",
        request.message,
        "--action-id",
        request.action_id,
        "--user",
        request.user,
        "--request",
        request.request,
    ]
    if request.echo_on:
        command.append("--echo-on")
    if request.error:
        command.extend(["--error", request.error])
    if request.info:
        command.extend(["--info", request.info])
    return command


def run_prompt(request: PromptRequest, cancellable: Gio.Cancellable | None) -> str:
    proc = subprocess.Popen(
        build_prompt_command(request),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    cancel_id = None
    if cancellable is not None:
        cancel_id = cancellable.connect(lambda *_args: proc.terminate())
    try:
        stdout, stderr = proc.communicate()
    finally:
        if cancellable is not None and cancel_id is not None:
            cancellable.disconnect(cancel_id)
    if cancellable is not None and cancellable.is_cancelled():
        raise PromptCancelled("authentication cancelled")
    if proc.returncode != 0:
        raise PromptCancelled((stderr or "").strip() or "authentication cancelled")
    return stdout.rstrip("\n")


def subject_for_current_session() -> Polkit.Subject:
    subject = Polkit.UnixSession.new_for_process_sync(os.getpid(), None)
    if subject is not None:
        return subject
    return Polkit.UnixProcess.new(os.getpid())


class AuthenticationFlow:
    def __init__(
        self,
        listener: "AstreaPolkitListener",
        task: Gio.Task,
        action_id: str,
        message: str,
        cookie: str,
        identities: list,
        cancellable: Gio.Cancellable | None,
    ) -> None:
        self.listener = listener
        self.task = task
        self.action_id = action_id
        self.message = message
        self.cookie = cookie
        self.identities = list(identities or [])
        self.cancellable = cancellable
        self.index = 0
        self.session = None
        self.last_error = ""
        self.last_info = ""
        self.done = False

    def start(self) -> None:
        if not self.identities:
            self.finish(False)
            return
        self.try_next_identity()

    def try_next_identity(self) -> None:
        if self.done:
            return
        if self.cancellable is not None and self.cancellable.is_cancelled():
            self.finish(False)
            return
        if self.index >= len(self.identities):
            self.finish(False)
            return

        identity = self.identities[self.index]
        self.index += 1
        self.session = PolkitAgent.Session.new(identity, self.cookie)
        self.session.connect("request", self.on_request, identity)
        self.session.connect("show-error", self.on_show_error)
        self.session.connect("show-info", self.on_show_info)
        self.session.connect("completed", self.on_completed)
        self.session.initiate()

    def on_request(self, session, request: str, echo_on: bool, identity) -> None:
        prompt_request = PromptRequest(
            action_id=self.action_id,
            message=self.message,
            user=identity_user_name(identity),
            request=request,
            echo_on=bool(echo_on),
            error=self.last_error,
            info=self.last_info,
        )
        self.last_error = ""
        self.last_info = ""
        try:
            response = run_prompt(prompt_request, self.cancellable)
        except PromptCancelled:
            session.cancel()
            return
        session.response(response)

    def on_show_error(self, _session, text: str) -> None:
        self.last_error = text or ""

    def on_show_info(self, _session, text: str) -> None:
        self.last_info = text or ""

    def on_completed(self, _session, gained_authorization: bool) -> None:
        self.session = None
        if gained_authorization:
            self.finish(True)
        else:
            self.try_next_identity()

    def finish(self, authorized: bool) -> None:
        if self.done:
            return
        self.done = True
        self.listener.forget_flow(self)
        self.task.return_boolean(bool(authorized))


class AstreaPolkitListener(PolkitAgent.Listener):
    def __init__(self) -> None:
        super().__init__()
        self._flows: set[AuthenticationFlow] = set()

    def remember_flow(self, flow: AuthenticationFlow) -> None:
        self._flows.add(flow)

    def forget_flow(self, flow: AuthenticationFlow) -> None:
        self._flows.discard(flow)

    def do_initiate_authentication(
        self,
        action_id,
        message,
        _icon_name,
        _details,
        cookie,
        identities,
        cancellable,
        callback,
        user_data,
    ) -> None:
        task = Gio.Task.new(self, cancellable, callback, user_data)
        flow = AuthenticationFlow(
            self,
            task,
            str(action_id or ""),
            str(message or "Authentication is required"),
            str(cookie or ""),
            list(identities or []),
            cancellable,
        )
        self.remember_flow(flow)
        GLib.idle_add(flow.start)

    def do_initiate_authentication_finish(self, result) -> bool:
        return result.propagate_boolean()


def run_agent() -> int:
    listener = AstreaPolkitListener()
    subject = subject_for_current_session()
    listener.register(
        PolkitAgent.RegisterFlags.RUN_IN_THREAD,
        subject,
        AGENT_OBJECT_PATH,
        None,
    )
    print("astrea-polkit-agent registered", flush=True)
    GLib.MainLoop().run()
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Astrea polkit authentication agent")
    parser.add_argument("--self-test", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.self_test:
        print("astrea-polkit-agent-ok")
        return 0
    return run_agent()


if __name__ == "__main__":
    raise SystemExit(main())
