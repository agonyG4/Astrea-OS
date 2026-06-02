#!/usr/bin/env python3

from __future__ import annotations

import argparse
import configparser
import json
import os
import pwd
import re
import subprocess
import sys
from pathlib import Path


ACCOUNTS_USERS_DIR = Path("/var/lib/AccountsService/users")
SDDM_CONF = Path("/etc/sddm.conf")
SDDM_CONF_DIR = Path("/etc/sddm.conf.d")
ASTREA_SDDM_AUTOLOGIN = SDDM_CONF_DIR / "zzzz-astrea-autologin.conf"
PROFILE_HELPER = Path("/usr/local/libexec/astrea-user-profile-helper")
USER_RE = re.compile(r"^[A-Za-z0-9_.-]{1,64}$")
SESSION_RE = re.compile(r"^[A-Za-z0-9_.@+-]+\.desktop$")


def emit(payload: dict[str, object]) -> None:
    print(json.dumps(payload, ensure_ascii=True), flush=True)


def current_user() -> str:
    user = os.environ.get("USER") or os.environ.get("LOGNAME") or ""
    if user:
        return user
    return pwd.getpwuid(os.getuid()).pw_name


def validate_user(user: str) -> str:
    user = (user or "").strip()
    if not USER_RE.fullmatch(user):
        raise ValueError("usuario invalido")
    try:
        pwd.getpwnam(user)
    except KeyError as exc:
        raise ValueError(f"usuario desconhecido: {user}") from exc
    return user


def validate_session_name(session: str) -> str:
    session = (session or "").strip()
    if not SESSION_RE.fullmatch(session):
        raise ValueError("sessao invalida")
    session_dirs = [Path("/usr/share/wayland-sessions"), Path("/usr/share/xsessions")]
    if not any((directory / session).is_file() for directory in session_dirs):
        raise ValueError(f"sessao nao encontrada: {session}")
    return session


def validate_display_name(name: str) -> str:
    trimmed = " ".join(str(name or "").split()).strip()
    if not trimmed:
        raise ValueError("display name vazio")
    if len(trimmed) > 128:
        raise ValueError("display name muito longo")
    if any(ord(ch) < 32 or ord(ch) == 127 for ch in trimmed):
        raise ValueError("display name contem caracteres de controle")
    return trimmed


def read_ini(path: Path) -> configparser.ConfigParser:
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    if path.exists():
        parser.read(path, encoding="utf-8")
    return parser


def accounts_file(user: str) -> Path:
    return ACCOUNTS_USERS_DIR / validate_user(user)


def display_name(user: str) -> str:
    parser = read_ini(accounts_file(user))
    try:
        value = parser.get("User", "RealName").strip()
    except (configparser.Error, AttributeError):
        value = ""
    return value or user


def sddm_config_paths() -> list[Path]:
    paths = [SDDM_CONF]
    if SDDM_CONF_DIR.is_dir():
        paths.extend(sorted(SDDM_CONF_DIR.glob("*.conf")))
    return paths


def effective_sddm_autologin() -> dict[str, str]:
    values: dict[str, str] = {}
    for path in sddm_config_paths():
        parser = read_ini(path)
        if not parser.has_section("Autologin"):
            continue
        for key in ("User", "Session", "Relogin"):
            if parser.has_option("Autologin", key):
                values[key.lower()] = parser.get("Autologin", key).strip()
    return values


def preferred_session() -> str:
    sessions = Path("/usr/share/wayland-sessions")
    for name in ("hyprland-uwsm.desktop", "hyprland.desktop"):
        if (sessions / name).exists():
            return name
    current = effective_sddm_autologin().get("session", "")
    return current or "hyprland.desktop"


def state(user: str) -> dict[str, object]:
    user = validate_user(user)
    autologin = effective_sddm_autologin()
    autologin_user = autologin.get("user", "")
    return {
        "ok": True,
        "user": user,
        "displayName": display_name(user),
        "autologinEnabled": autologin_user == user,
        "autologinUser": autologin_user,
        "autologinSession": autologin.get("session", ""),
        "astreaAutologinPath": str(ASTREA_SDDM_AUTOLOGIN),
    }


def pkexec_helper(args: list[str]) -> None:
    if not PROFILE_HELPER.exists():
        raise RuntimeError(
            f"profile helper nao instalado: execute {Path(__file__).resolve().parents[3] / 'System/services/install-user-profile-helper.sh'}"
        )
    command = ["pkexec", str(PROFILE_HELPER), *args]
    subprocess.run(command, check=True, timeout=60)


def set_display_name(user: str, name: str) -> None:
    user = validate_user(user)
    trimmed = validate_display_name(name)
    pkexec_helper(["write-display-name", "--user", user, "--name", trimmed])
    emit(state(user))


def write_display_name(user: str, name: str) -> None:
    user = validate_user(user)
    name = validate_display_name(name)
    path = accounts_file(user)
    path.parent.mkdir(parents=True, exist_ok=True)
    parser = read_ini(path)
    if not parser.has_section("User"):
        parser.add_section("User")
    parser.set("User", "RealName", name)
    with path.open("w", encoding="utf-8") as handle:
        parser.write(handle, space_around_delimiters=False)


def set_sddm_autologin(user: str, enabled: bool) -> None:
    user = validate_user(user)
    session = validate_session_name(preferred_session())
    pkexec_helper([
        "write-sddm-autologin",
        "--user",
        user,
        "--enabled",
        "1" if enabled else "0",
        "--session",
        session,
    ])
    emit(state(user))


def write_sddm_autologin(user: str, enabled: bool, session: str) -> None:
    user = validate_user(user)
    session = validate_session_name(session)
    ASTREA_SDDM_AUTOLOGIN.parent.mkdir(parents=True, exist_ok=True)
    if enabled:
        body = (
            "[Autologin]\n"
            f"User={user}\n"
            f"Session={session}\n"
            "Relogin=true\n"
        )
    else:
        body = (
            "[Autologin]\n"
            "User=\n"
            f"Session={session}\n"
            "Relogin=false\n"
        )
    ASTREA_SDDM_AUTOLOGIN.write_text(body, encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Astrea user profile bridge")
    sub = parser.add_subparsers(dest="command", required=True)

    state_cmd = sub.add_parser("state")
    state_cmd.add_argument("--user", default=current_user())

    set_name = sub.add_parser("set-display-name")
    set_name.add_argument("--user", default=current_user())
    set_name.add_argument("--name", required=True)

    write_name = sub.add_parser("write-display-name")
    write_name.add_argument("--user", required=True)
    write_name.add_argument("--name", required=True)

    set_auto = sub.add_parser("set-sddm-autologin")
    set_auto.add_argument("--user", default=current_user())
    set_auto.add_argument("--enabled", choices=("0", "1"), required=True)

    write_auto = sub.add_parser("write-sddm-autologin")
    write_auto.add_argument("--user", required=True)
    write_auto.add_argument("--enabled", choices=("0", "1"), required=True)
    write_auto.add_argument("--session", required=True)

    return parser.parse_args()


def main() -> None:
    args = parse_args()
    try:
        if args.command == "state":
            emit(state(args.user))
        elif args.command == "set-display-name":
            set_display_name(args.user, args.name)
        elif args.command == "write-display-name":
            write_display_name(args.user, args.name)
        elif args.command == "set-sddm-autologin":
            set_sddm_autologin(args.user, args.enabled == "1")
        elif args.command == "write-sddm-autologin":
            write_sddm_autologin(args.user, args.enabled == "1", args.session)
    except Exception as exc:
        print(str(exc), file=sys.stderr, flush=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
