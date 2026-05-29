#!/usr/bin/env python3
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
RUNTIME_DIR = ROOT / "runtime"
SETTINGS_DIR = ROOT.parents[0] / "Apps" / "Settings"


class ComponentSettingsTests(unittest.TestCase):
    def test_runtime_component_settings_watches_config(self):
        source = (RUNTIME_DIR / "ComponentSettings.qml").read_text()
        self.assertIn('"/.config/AstreaOS/ui/components.json"', source)
        self.assertIn("FileView", source)
        self.assertIn("watchChanges: true", source)
        self.assertIn("function isEnabled(key)", source)

        qmldir = (RUNTIME_DIR / "qmldir").read_text()
        self.assertIn("ComponentSettings 1.0 ComponentSettings.qml", qmldir)

    def test_runtime_component_service_manager_controls_dependencies(self):
        source = (RUNTIME_DIR / "ComponentServiceManager.qml").read_text()
        self.assertIn("astrea-status.service", source)
        self.assertIn("topbarEnabled", source)
        self.assertIn("gameModeActive", source)
        self.assertIn("notification_daemon.py", source)
        self.assertIn("--watch-signature", source)
        self.assertIn("pkill", source)

        qmldir = (RUNTIME_DIR / "qmldir").read_text()
        self.assertIn("ComponentServiceManager 1.0 ComponentServiceManager.qml", qmldir)

    def test_shell_runtime_loads_status_processes_only_when_needed(self):
        source = (RUNTIME_DIR / "ShellRuntime.qml").read_text()
        self.assertIn("active: root.topbarEnabled", source)
        self.assertIn("active: root.musicMonitoringEnabled", source)
        self.assertIn("networkLoader.item", source)
        self.assertIn("bluetoothLoader.item", source)
        self.assertIn("audioLoader.item", source)
        self.assertNotIn("property alias networkState: networkStatus", source)

    def test_gamemode_manager_leaves_status_service_to_component_manager(self):
        source = (RUNTIME_DIR / "GameModeManager.qml").read_text()
        self.assertIn("astrea-weatherd.service", source)
        self.assertNotIn('"astrea-status.service"', source)

    def test_shell_gates_heavy_components(self):
        shell = (ROOT / "shell.qml").read_text()
        for component in ("desktop", "topbar", "island", "spotlight", "alttab", "notifications"):
            self.assertIn(f"componentSettings.{component}", shell)
        self.assertIn("Runtime.ComponentSettings", shell)
        self.assertIn("componentSettings: componentSettings", shell)
        self.assertIn("Runtime.ComponentServiceManager", shell)

    def test_settings_exposes_components_page(self):
        main = (SETTINGS_DIR / "main.qml").read_text()
        page = (SETTINGS_DIR / "pages" / "system" / "Components.qml").read_text()
        self.assertIn('"pages/system/Components.qml"', main)
        self.assertIn('label: "Components"', main)
        self.assertIn("ToggleSwitch", page)
        self.assertIn("components.json", page)
        self.assertIn("Desktop Icons", page)
        self.assertIn("Topbar", page)
        self.assertIn("Spotlight", page)

    def test_desktop_icons_stops_processes_on_destroy(self):
        source = (ROOT / "desktop" / "DesktopIcons.qml").read_text()
        self.assertIn("Component.onDestruction", source)
        self.assertIn("stopDesktopIconWork()", source)


if __name__ == "__main__":
    unittest.main()
