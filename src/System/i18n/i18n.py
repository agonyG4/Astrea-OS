#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEFAULT_LANGUAGE = "en_US"
CONFIG_FILES = ("settings.json", "system.json")
LANGUAGE_KEYS = ("language", "locale", "ui_language", "lang")


@dataclass(frozen=True)
class I18nBundle:
    language: str
    strings: dict[str, str]
    fallback_strings: dict[str, str]

    def translate(self, key: str, fallback: str | None = None, params: dict[str, Any] | None = None) -> str:
        value = self.strings.get(key) or self.fallback_strings.get(key) or fallback or key
        if params:
            for name, raw in params.items():
                value = value.replace("{" + str(name) + "}", str(raw))
        return value

    def as_payload(self) -> dict[str, Any]:
        return {
            "language": self.language,
            "strings": self.strings,
            "fallback": self.fallback_strings,
        }


def astrea_root() -> Path:
    env_root = os.environ.get("ASTREA_ROOT")
    if env_root:
        return Path(env_root).expanduser()
    return Path.home() / ".local" / "share" / "Astrea"


def default_catalog_dir() -> Path:
    return astrea_root() / "System" / "i18n"


def default_config_dir() -> Path:
    return Path.home() / ".config" / "AstreaOS" / "system"


def read_json_object(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8") or "{}")
    except (OSError, json.JSONDecodeError):
        return {}
    return payload if isinstance(payload, dict) else {}


def read_catalog(catalog_dir: Path, language: str) -> dict[str, str]:
    payload = read_json_object(catalog_dir / f"{language}.json")
    return {str(key): str(value) for key, value in payload.items()}


def available_languages(catalog_dir: Path) -> list[str]:
    try:
        return sorted({path.stem for path in catalog_dir.glob("*.json") if path.is_file()})
    except OSError:
        return []


def normalize_language(language: str, supported: list[str]) -> str:
    candidate = (language or "").strip().replace("-", "_")
    if not candidate:
        return DEFAULT_LANGUAGE
    if candidate in supported:
        return candidate
    lowered = candidate.lower()
    for item in supported:
        if item.lower() == lowered:
            return item
    return DEFAULT_LANGUAGE


def language_from_config(config_dir: Path) -> str:
    for file_name in CONFIG_FILES:
        payload = read_json_object(config_dir / file_name)
        for key in LANGUAGE_KEYS:
            value = payload.get(key)
            if isinstance(value, str) and value.strip():
                return value
    return DEFAULT_LANGUAGE


def load_bundle(
    catalog_dir: Path | None = None,
    config_dir: Path | None = None,
) -> I18nBundle:
    catalog_dir = catalog_dir or default_catalog_dir()
    config_dir = config_dir or default_config_dir()
    fallback = read_catalog(catalog_dir, DEFAULT_LANGUAGE)
    language = normalize_language(language_from_config(config_dir), available_languages(catalog_dir))
    strings = read_catalog(catalog_dir, language)
    if language != DEFAULT_LANGUAGE and not strings:
        language = DEFAULT_LANGUAGE
        strings = fallback
    return I18nBundle(language=language, strings=strings, fallback_strings=fallback)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="AstreaOS translation helper")
    parser.add_argument("--catalog-dir", type=Path, default=None)
    parser.add_argument("--config-dir", type=Path, default=None)

    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("dump", help="print the active language bundle as JSON")
    tr_parser = sub.add_parser("tr", help="print a single translated key")
    tr_parser.add_argument("key")
    tr_parser.add_argument("fallback", nargs="?", default=None)
    tr_parser.add_argument("--params", default="{}")
    sub.add_parser("list-languages", help="list available language catalogs")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    bundle = load_bundle(args.catalog_dir, args.config_dir)
    if args.command == "dump":
        print(json.dumps(bundle.as_payload(), ensure_ascii=False, sort_keys=True))
        return
    if args.command == "tr":
        params = json.loads(args.params or "{}")
        print(bundle.translate(args.key, args.fallback, params if isinstance(params, dict) else None))
        return
    if args.command == "list-languages":
        print(json.dumps(available_languages(args.catalog_dir or default_catalog_dir()), ensure_ascii=False))


if __name__ == "__main__":
    main()
