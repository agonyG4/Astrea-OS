import QtQuick

pragma Singleton

QtObject {
    // --- Colors ---
    readonly property color background: Qt.rgba(0, 0, 0, 0.06)
    readonly property color surface:    Qt.rgba(1, 1, 1, 0.06)
    readonly property color border:     Qt.rgba(1, 1, 1, 0.14)
    readonly property color barBorderHover: Qt.rgba(1, 1, 1, 0.28)
    readonly property color separator:  Qt.rgba(1, 1, 1, 0.08)
    readonly property color islandBackground: "#000000"
    
    // Text Colors
    readonly property color textMain:      "#f5f5f7"
    readonly property color textSecondary: Qt.rgba(1, 1, 1, 0.60)
    readonly property color textLight:     "#e0e0e5"
    readonly property color textDim:       Qt.rgba(1, 1, 1, 0.65)
    readonly property color textActive:    "#ffffff"

    // Icon Colors
    readonly property color iconMain:      Qt.rgba(1, 1, 1, 0.65)
    readonly property color iconActive:    "#ffffff"
    readonly property color iconMuted:     Qt.rgba(1, 1, 1, 0.25)
    readonly property color iconWarning:   "#ff375f"
    readonly property color iconAccent:    "#60aaff"

    // Accent Colors 
    readonly property color accent: "#34b7f1" 

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
    readonly property color workspaceActive:   "#ffffff"
    readonly property color workspaceInactive: Qt.rgba(1, 1, 1, 0.22)
    readonly property int   workspaceDotSize:  10
    readonly property int   workspaceActiveWidth: 32
}
