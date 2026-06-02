#!/usr/bin/env python3
import importlib.util
from importlib.machinery import SourceFileLoader
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("astrea-gaming-settings")


def load_module():
    loader = SourceFileLoader("astrea_gaming_settings_under_test", str(SCRIPT))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


class AstreaGamingSettingsTests(unittest.TestCase):
    def test_default_proton_profile_does_not_force_gpu_compat_flags(self):
        gaming = load_module()
        cfg = gaming.normalize_proton({})

        self.assertFalse(cfg["enable_nvapi"])
        self.assertFalse(cfg["vkd3d_dxr"])
        self.assertEqual(cfg["sync_mode"], "default")

    def test_proton_preset_recommended_keeps_proton_defaults(self):
        gaming = load_module()
        cfg = gaming.proton_preset("recommended")
        env, prefix = gaming.proton_env_and_prefix(cfg)

        self.assertNotIn("PROTON_ENABLE_NVAPI", env)
        self.assertNotIn("PROTON_FORCE_NVAPI", env)
        self.assertNotIn("VKD3D_CONFIG", env)
        self.assertNotIn("PROTON_NO_ESYNC", env)
        self.assertNotIn("PROTON_NO_FSYNC", env)
        self.assertIsInstance(prefix, list)

    def test_compatibility_defaults_follow_proton_profile(self):
        gaming = load_module()
        cfg = gaming.normalize_compatibility({})

        self.assertEqual(cfg["runner"], "proton")
        self.assertTrue(cfg["use_proton_profile"])
        self.assertNotIn("windows_user", cfg)
        self.assertNotIn("use_gamescope_profile", cfg)

    def test_proton_gamescope_uses_mangoapp_not_mangohud_prefix(self):
        gaming = load_module()
        cfg = gaming.normalize_proton({
            "gamemode": False,
            "mangohud": True,
            "gamescope": True,
        })
        gamescope = gaming.normalize_gamescope({
            "follow_monitor": False,
            "width": 1280,
            "height": 720,
            "refresh": 60,
            "fullscreen": True,
        })
        env, prefix = gaming.proton_env_and_prefix(cfg, gamescope)

        self.assertEqual(prefix[0], "gamescope")
        self.assertIn("--mangoapp", prefix)
        self.assertIn("-W", prefix)
        self.assertIn("1280", prefix)
        self.assertIn("--", prefix)
        self.assertNotIn("mangohud", prefix)

    def test_proton_gamescope_can_use_inline_game_settings(self):
        gaming = load_module()
        cfg = gaming.normalize_proton({
            "gamemode": False,
            "mangohud": False,
            "gamescope": True,
            "use_gamescope_profile": False,
            "gamescope_width": 1600,
            "gamescope_height": 900,
            "gamescope_refresh": 75,
            "gamescope_fullscreen": True,
            "gamescope_force_grab_cursor": True,
            "gamescope_adaptive_sync": True,
        })
        env, prefix = gaming.proton_env_and_prefix(cfg, gaming.normalize_gamescope({}))

        self.assertEqual(prefix[0], "gamescope")
        self.assertIn("-W", prefix)
        self.assertIn("1600", prefix)
        self.assertIn("-H", prefix)
        self.assertIn("900", prefix)
        self.assertIn("-r", prefix)
        self.assertIn("75", prefix)
        self.assertIn("--force-grab-cursor", prefix)
        self.assertIn("--adaptive-sync", prefix)
        self.assertFalse(env)


if __name__ == "__main__":
    unittest.main()
