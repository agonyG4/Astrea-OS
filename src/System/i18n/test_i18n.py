#!/usr/bin/env python3

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import i18n


class I18nTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.catalog_dir = self.base / "catalogs"
        self.catalog_dir.mkdir()
        (self.catalog_dir / "en_US.json").write_text(
            json.dumps(
                {
                    "app.title": "Astrea Settings",
                    "shared.only_en": "Only English",
                }
            ),
            encoding="utf-8",
        )
        (self.catalog_dir / "pt_BR.json").write_text(
            json.dumps(
                {
                    "app.title": "Configuracoes Astrea",
                }
            ),
            encoding="utf-8",
        )
        self.config_dir = self.base / ".config" / "AstreaOS" / "system"
        self.config_dir.mkdir(parents=True)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def write_config(self, name: str, payload: dict[str, str]) -> None:
        (self.config_dir / name).write_text(json.dumps(payload), encoding="utf-8")

    def test_uses_language_from_settings_json(self) -> None:
        self.write_config("settings.json", {"language": "pt_BR"})

        bundle = i18n.load_bundle(self.catalog_dir, self.config_dir)

        self.assertEqual(bundle.language, "pt_BR")
        self.assertEqual(bundle.translate("app.title"), "Configuracoes Astrea")

    def test_system_json_is_supported_when_settings_json_is_missing(self) -> None:
        self.write_config("system.json", {"locale": "pt_BR"})

        bundle = i18n.load_bundle(self.catalog_dir, self.config_dir)

        self.assertEqual(bundle.language, "pt_BR")

    def test_falls_back_to_en_us_when_config_or_language_is_missing(self) -> None:
        self.write_config("settings.json", {"language": "fr_FR"})

        bundle = i18n.load_bundle(self.catalog_dir, self.config_dir)

        self.assertEqual(bundle.language, "en_US")
        self.assertEqual(bundle.translate("app.title"), "Astrea Settings")

    def test_missing_key_falls_back_to_en_us_then_key(self) -> None:
        self.write_config("settings.json", {"language": "pt_BR"})

        bundle = i18n.load_bundle(self.catalog_dir, self.config_dir)

        self.assertEqual(bundle.translate("shared.only_en"), "Only English")
        self.assertEqual(bundle.translate("missing.key"), "missing.key")


if __name__ == "__main__":
    unittest.main()
