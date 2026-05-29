pragma Singleton
import QtQuick 2.15
import "AstreaComponents" as Components

Item {
    id: theme
    visible: false
    width: 0
    height: 0

    readonly property string configPath: Components.Theme.configPath
    readonly property int themeMode: Components.Theme.themeMode
    readonly property int shellStyle: Components.Theme.shellStyle
    readonly property bool isLight: themeMode === 1
    readonly property bool isDefault: shellStyle === 1

    readonly property color bg: isLight ? Qt.rgba(0.965, 0.968, 0.98, 1) : "#1c1c1e"
    readonly property color sidebar: isLight ? Qt.rgba(0.985, 0.987, 0.994, 0.96) : "#202225"
    readonly property color sidebarAlt: isLight ? Qt.rgba(1, 1, 1, 0.82) : "#2a2c31"
    readonly property color sidebarGlow: isLight ? Qt.rgba(0.90, 0.94, 1.0, 0.70) : "#343843"
    readonly property color panel: isLight ? Qt.rgba(1, 1, 1, 0.78) : "#2c2c2e"
    readonly property color toolbar: isLight ? Qt.rgba(0.975, 0.978, 0.986, 1) : "#232325"
    readonly property color border: isLight ? Qt.rgba(0, 0, 0, 0.10) : "#3a3a3c"
    readonly property color accent: Components.Theme.accent
    readonly property color accentLight: isLight ? Qt.rgba(0.0, 0.48, 1.0, 0.13) : "#1a3a5c"
    readonly property color accentSoft: isLight ? Qt.rgba(0.0, 0.38, 0.85, 0.70) : "#2f6fb6"
    readonly property color text: Components.Theme.textPrimary
    readonly property color textSec: isLight ? Qt.rgba(0.13, 0.15, 0.18, 0.68) : "#8e8e93"
    readonly property color textTer: isLight ? Qt.rgba(0.13, 0.15, 0.18, 0.48) : "#636366"
    readonly property color hover: isLight ? Qt.rgba(0, 0, 0, 0.055) : "#3a3a3c"
    readonly property color selected: isLight ? Qt.rgba(0.0, 0.48, 1.0, 0.14) : "#1a3a5c"
    readonly property color selectedBdr: Components.Theme.accent
    readonly property color statusBar: isLight ? Qt.rgba(0.955, 0.958, 0.97, 1) : "#1a1a1c"
}
