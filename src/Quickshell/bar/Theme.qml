import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Item {
    id: theme
    visible: false
    width: 0
    height: 0

    readonly property string configPath: (Quickshell.env("HOME") || "") + "/.config/AstreaOS/ui/theme.json"
    property int themeMode: 0
    property int shellStyle: 0

    readonly property bool isLight: themeMode === 1
    readonly property bool isTransparent: shellStyle === 0
    readonly property bool isDefault: shellStyle === 1
    readonly property bool isFrosted: shellStyle === 2

    function applyThemeConfig(text) {
        try {
            var cfg = JSON.parse(text || "{}")
            var nextThemeMode = cfg.theme_mode === 1 ? 1 : 0
            if (typeof cfg.theme === "string")
                nextThemeMode = cfg.theme.toLowerCase() === "light" ? 1 : 0
            var nextShellStyle = typeof cfg.shell_style === "number" ? cfg.shell_style : 0
            if (nextShellStyle < 0 || nextShellStyle > 2)
                nextShellStyle = 0
            theme.themeMode = nextThemeMode
            theme.shellStyle = nextShellStyle
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

    // --- Colors ---
    readonly property color background: isLight
        ? (isDefault ? Qt.rgba(0.985, 0.987, 0.994, 0.92)
            : isFrosted ? Qt.rgba(0.96, 0.985, 1, 0.30)
            : Qt.rgba(1, 1, 1, 0.16))
        : (isDefault ? Qt.rgba(0.10, 0.10, 0.11, 0.96) : Qt.rgba(0, 0, 0, 0.06))
    readonly property color surface: isLight
        ? (isDefault ? Qt.rgba(1, 1, 1, 0.86)
            : isFrosted ? Qt.rgba(0.98, 0.99, 1, 0.38)
            : Qt.rgba(1, 1, 1, 0.22))
        : (isDefault ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.06))
    readonly property color border: isLight
        ? (isDefault ? Qt.rgba(0, 0, 0, 0.12)
            : isFrosted ? Qt.rgba(0, 0, 0, 0.10)
            : Qt.rgba(0, 0, 0, 0.08))
        : (isDefault ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(1, 1, 1, 0.14))
    readonly property color barBorderHover: isLight ? Qt.rgba(0, 0, 0, 0.20) : Qt.rgba(1, 1, 1, 0.28)
    readonly property color separator:  Qt.rgba(1, 1, 1, 0.08)
    readonly property color shellBackground: background
    readonly property color shellSurface: surface
    readonly property color shellBorder: border
    readonly property color shellSeparator: isLight
        ? (isDefault ? Qt.rgba(0, 0, 0, 0.055) : Qt.rgba(0, 0, 0, 0.065))
        : separator
    readonly property color shellHover: isLight ? Qt.rgba(0, 0, 0, 0.055) : Qt.rgba(1, 1, 1, 0.08)
    readonly property color shellPressed: isLight ? Qt.rgba(0, 0, 0, 0.085) : Qt.rgba(1, 1, 1, 0.12)
    readonly property color shellActive: isLight ? Qt.rgba(0, 122, 255, 0.14) : Qt.rgba(1, 1, 1, 0.15)
    readonly property color islandBackground: "#000000"
    
    // Text Colors
    readonly property color textMain:      "#f5f5f7"
    readonly property color textSecondary: Qt.rgba(1, 1, 1, 0.60)
    readonly property color textLight:     "#e0e0e5"
    readonly property color textDim:       Qt.rgba(1, 1, 1, 0.65)
    readonly property color textActive:    "#ffffff"
    readonly property color shellTextMain:      isLight ? Qt.rgba(0.05, 0.06, 0.07, 0.94) : textMain
    readonly property color shellTextSecondary: isLight ? Qt.rgba(0.13, 0.15, 0.18, 0.68) : textSecondary
    readonly property color shellTextLight:     isLight ? Qt.rgba(0.08, 0.09, 0.11, 0.86) : textLight
    readonly property color shellTextDim:       isLight ? Qt.rgba(0.13, 0.15, 0.18, 0.54) : textDim
    readonly property color shellTextActive:    isLight ? Qt.rgba(0.04, 0.05, 0.06, 0.96) : textActive

    // Icon Colors
    readonly property color iconMain:      Qt.rgba(1, 1, 1, 0.65)
    readonly property color iconActive:    "#ffffff"
    readonly property color iconMuted:     Qt.rgba(1, 1, 1, 0.25)
    readonly property color iconWarning:   "#ff375f"
    readonly property color iconAccent:    "#60aaff"
    readonly property color shellIconMain:   isLight ? Qt.rgba(0.10, 0.11, 0.13, 0.68) : iconMain
    readonly property color shellIconActive: isLight ? Qt.rgba(0.03, 0.04, 0.05, 0.96) : iconActive
    readonly property color shellIconMuted:  isLight ? Qt.rgba(0.13, 0.15, 0.18, 0.32) : iconMuted
    readonly property color shellIconAccent: iconAccent

    // Accent Colors 
    readonly property color accent: "#0a84ff"
    readonly property color accentForeground: "#ffffff"
    readonly property color errorColor: "#ff453a"
    readonly property color warningColor: "#ff9f0a"
    readonly property color successColor: "#30d158"

    // --- Layout & Spacing ---
    // Authority note: this Theme is currently scoped to Quickshell shell surfaces
    // (bar, popups, desktop overlays). Core/components/theme/Theme.qml remains
    // authoritative for app-window and Settings UI until a shared token module exists.
    readonly property real radiusLarge:  14
    readonly property real radiusMedium: 8
    readonly property real radiusSmall:  6
    readonly property real cornerRadiusSmall: radiusSmall
    readonly property real cornerRadius: radiusMedium
    readonly property real cornerRadiusLarge: radiusLarge
    readonly property real controlRadius: 10
    readonly property real tileRadius: 12
    readonly property real pillRadius: 999

    readonly property real spacingTiny: 3
    readonly property real spacingMicro: 4
    readonly property real spacingSmall: 6
    readonly property real spacingInset: 7
    readonly property real spacing: 8
    readonly property real spacingMedium: 10
    readonly property real spacingControlGap: 9
    readonly property real spacingLarge: 12
    readonly property real spacingXLarge: 14
    readonly property real spacingXXLarge: 20
    readonly property real spacingContainer: 16

    // --- Motion ---
    readonly property int animationSlider: 60
    readonly property int animationInstant: 90
    readonly property int animationMicro: 100
    readonly property int animationQuick: 120
    readonly property int animationSubtle: 130
    readonly property int animationHover: 140
    readonly property int animationFast: 150
    readonly property int animationStandard: 160
    readonly property int animationNormal: 200
    readonly property int animationSlow: 400
    readonly property int animationPulse: 900
    readonly property int animationSpin: 1200

    // --- Opacity ---
    readonly property real opacityMuted: 0.80
    readonly property real opacitySecondary: 0.85
    readonly property real opacitySubtle: 0.86
    readonly property real opacityEmphasis: 0.90
    readonly property real opacityDragging: 0.94
    
    // --- Typography ---
    readonly property string fontFamily: "Inter Variable"
    readonly property string fontFamilyDisplay: "Inter Display"
    readonly property string fontFamilyText: "Inter Regular"
    readonly property int fontSizeLarge: 18
    readonly property int fontSizeTitle: 13
    readonly property int fontSizeBody: 12
    readonly property int fontSizeSmall: 12
    readonly property int fontSizeCaption: 11
    readonly property int fontSizeExtraSmall: 10
    readonly property int fontSizeMicro: 9
    readonly property int fontSizeIcon: 16
    readonly property int fontSizeIconLarge: 18
    
    // --- Workspace Dots ---
    readonly property color workspaceActive:   isLight ? Qt.rgba(0.05, 0.06, 0.07, 0.88) : "#ffffff"
    readonly property color workspaceInactive: isLight ? Qt.rgba(0.05, 0.06, 0.07, 0.22) : Qt.rgba(1, 1, 1, 0.22)
    readonly property int   workspaceDotSize:  10
    readonly property int   workspaceActiveWidth: 32
}
