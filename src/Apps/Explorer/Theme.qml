pragma Singleton
import QtQuick 2.15
import Quickshell
import Quickshell.Io

Item {
    id: theme
    visible: false
    width: 0
    height: 0

    readonly property string configPath: (Quickshell.env("HOME") || "") + "/.config/AstreaOS/ui/theme.json"
    property int themeMode: 0
    property int shellStyle: 0
    readonly property bool isLight: themeMode === 1
    readonly property bool isDefault: shellStyle === 1

    function applyThemeConfig(text) {
        try {
            var cfg = JSON.parse(text || "{}")
            theme.themeMode = (cfg.theme === "light" || cfg.theme_mode === 1) ? 1 : 0
            var nextShellStyle = typeof cfg.shell_style === "number" ? cfg.shell_style : 0
            theme.shellStyle = nextShellStyle >= 0 && nextShellStyle <= 2 ? nextShellStyle : 0
        } catch (e) {
            theme.themeMode = 0
            theme.shellStyle = 0
        }
    }

    FileView {
        id: themeFile
        path: theme.configPath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: theme.applyThemeConfig(text())
    }

    readonly property color bg:          isLight ? Qt.rgba(0.965, 0.968, 0.98, 1) : "#1c1c1e"
    readonly property color sidebar:     isLight ? Qt.rgba(0.985, 0.987, 0.994, 0.96) : "#202225"
    readonly property color sidebarAlt:  isLight ? Qt.rgba(1, 1, 1, 0.82) : "#2a2c31"
    readonly property color sidebarGlow: isLight ? Qt.rgba(0.90, 0.94, 1.0, 0.70) : "#343843"
    readonly property color panel:       isLight ? Qt.rgba(1, 1, 1, 0.78) : "#2c2c2e"
    readonly property color toolbar:     isLight ? Qt.rgba(0.975, 0.978, 0.986, 1) : "#232325"
    readonly property color border:      isLight ? Qt.rgba(0, 0, 0, 0.10) : "#3a3a3c"
    readonly property color accent:      "#0a84ff"
    readonly property color accentLight: isLight ? Qt.rgba(0.0, 0.48, 1.0, 0.13) : "#1a3a5c"
    readonly property color accentSoft:  isLight ? Qt.rgba(0.0, 0.38, 0.85, 0.70) : "#2f6fb6"
    readonly property color text:        isLight ? Qt.rgba(0.05, 0.06, 0.07, 0.94) : "#f2f2f7"
    readonly property color textSec:     isLight ? Qt.rgba(0.13, 0.15, 0.18, 0.68) : "#8e8e93"
    readonly property color textTer:     isLight ? Qt.rgba(0.13, 0.15, 0.18, 0.48) : "#636366"
    readonly property color hover:       isLight ? Qt.rgba(0, 0, 0, 0.055) : "#3a3a3c"
    readonly property color selected:    isLight ? Qt.rgba(0.0, 0.48, 1.0, 0.14) : "#1a3a5c"
    readonly property color selectedBdr: "#0a84ff"
    readonly property color statusBar:   isLight ? Qt.rgba(0.955, 0.958, 0.97, 1) : "#1a1a1c"
}
