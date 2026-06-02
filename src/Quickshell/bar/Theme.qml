pragma Singleton
import QtQuick
import "../AstreaComponents" as Components

Item {
    id: theme
    visible: false
    width: 0
    height: 0

    readonly property string configPath: Components.Theme.configPath
    readonly property int themeMode: Components.Theme.themeMode
    readonly property int shellStyle: Components.Theme.shellStyle

    readonly property bool isLight: Components.Theme.isLight
    readonly property bool isTransparent: Components.Theme.isTransparent
    readonly property bool isDefault: Components.Theme.isDefault
    readonly property bool isFrosted: Components.Theme.isFrosted

    readonly property color background: Components.Theme.shellBackground
    readonly property color surface: Components.Theme.shellSurface
    readonly property color border: Components.Theme.shellBorder
    readonly property color barBorderHover: Components.Theme.shellBarBorderHover
    readonly property color separator: Components.Theme.shellSeparatorToken
    readonly property color shellBackground: background
    readonly property color shellSurface: surface
    readonly property color shellBorder: border
    readonly property color shellSeparator: isLight
        ? (isDefault ? Qt.rgba(0, 0, 0, 0.055) : Qt.rgba(0, 0, 0, 0.065))
        : separator
    readonly property color shellHover: Components.Theme.shellHover
    readonly property color shellPressed: Components.Theme.shellPressed
    readonly property color shellActive: Components.Theme.shellActive
    readonly property color islandBackground: Components.Theme.islandBackground

    readonly property color textMain: "#f5f5f7"
    readonly property color textSecondary: Qt.rgba(1, 1, 1, 0.60)
    readonly property color textLight: "#e0e0e5"
    readonly property color textDim: Qt.rgba(1, 1, 1, 0.65)
    readonly property color textActive: "#ffffff"
    readonly property color shellTextMain: Components.Theme.shellTextMain
    readonly property color shellTextSecondary: Components.Theme.shellTextSecondary
    readonly property color shellTextLight: Components.Theme.shellTextLight
    readonly property color shellTextDim: Components.Theme.shellTextDim
    readonly property color shellTextActive: Components.Theme.shellTextActive

    readonly property color iconMain: Qt.rgba(1, 1, 1, 0.65)
    readonly property color iconActive: "#ffffff"
    readonly property color iconMuted: Qt.rgba(1, 1, 1, 0.25)
    readonly property color iconWarning: Components.Theme.shellIconWarning
    readonly property color iconAccent: Components.Theme.shellIconAccent
    readonly property color shellIconMain: Components.Theme.shellIconMain
    readonly property color shellIconActive: Components.Theme.shellIconActive
    readonly property color shellIconMuted: Components.Theme.shellIconMuted
    readonly property color shellIconAccent: Components.Theme.shellIconAccent

    readonly property color accent: Components.Theme.accent
    readonly property color accentForeground: Components.Theme.accentForeground
    readonly property color errorColor: Components.Theme.errorColor
    readonly property color warningColor: Components.Theme.warningColor
    readonly property color successColor: Components.Theme.successColor

    readonly property real radiusLarge: Components.Theme.shellRadiusLarge
    readonly property real radiusMedium: Components.Theme.shellRadiusMedium
    readonly property real radiusSmall: Components.Theme.shellRadiusSmall
    readonly property real cornerRadiusSmall: radiusSmall
    readonly property real cornerRadius: radiusMedium
    readonly property real cornerRadiusLarge: radiusLarge
    readonly property real controlRadius: Components.Theme.shellControlRadius
    readonly property real tileRadius: Components.Theme.shellTileRadius
    readonly property real pillRadius: Components.Theme.shellPillRadius

    readonly property real spacingTiny: 3
    readonly property real spacingMicro: Components.Theme.spacingMicro
    readonly property real spacingSmall: Components.Theme.spacingSmall
    readonly property real spacingInset: 7
    readonly property real spacing: Components.Theme.spacing
    readonly property real spacingMedium: 10
    readonly property real spacingControlGap: 9
    readonly property real spacingLarge: 12
    readonly property real spacingXLarge: 14
    readonly property real spacingXXLarge: 20
    readonly property real spacingContainer: 16

    readonly property int animationSlider: 60
    readonly property int animationInstant: 90
    readonly property int animationMicro: Components.Theme.animationMicro
    readonly property int animationQuick: Components.Theme.animationQuick
    readonly property int animationSubtle: 130
    readonly property int animationHover: 140
    readonly property int animationFast: Components.Theme.animationFast
    readonly property int animationStandard: 160
    readonly property int animationNormal: Components.Theme.animationNormal
    readonly property int animationSlow: 400
    readonly property int animationPulse: 900
    readonly property int animationSpin: 1200

    readonly property real opacityMuted: 0.80
    readonly property real opacitySecondary: 0.85
    readonly property real opacitySubtle: 0.86
    readonly property real opacityEmphasis: 0.90
    readonly property real opacityDragging: 0.94

    readonly property string fontFamily: "Inter Variable"
    readonly property string fontFamilyDisplay: "Inter Display"
    readonly property string fontFamilyText: "Inter Regular"
    readonly property string iconFontFamily: "JetBrainsMonoNL Nerd Font"
    readonly property int fontSizeLarge: 18
    readonly property int fontSizeTitle: 13
    readonly property int fontSizeBody: 12
    readonly property int fontSizeSmall: 12
    readonly property int fontSizeCaption: 11
    readonly property int fontSizeExtraSmall: 10
    readonly property int fontSizeMicro: 9
    readonly property int fontSizeIcon: 16
    readonly property int fontSizeIconLarge: 18

    readonly property color workspaceActive: isLight ? Qt.rgba(0.05, 0.06, 0.07, 0.88) : "#ffffff"
    readonly property color workspaceInactive: isLight ? Qt.rgba(0.05, 0.06, 0.07, 0.22) : Qt.rgba(1, 1, 1, 0.22)
    readonly property int workspaceDotSize: Components.Theme.shellWorkspaceDotSize
    readonly property int workspaceActiveWidth: Components.Theme.shellWorkspaceActiveWidth
}
