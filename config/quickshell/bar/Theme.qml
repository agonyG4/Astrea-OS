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
    readonly property real radiusLarge:  14
    readonly property real radiusMedium: 8
    readonly property real radiusSmall:  6
    
    // --- Typography ---
    readonly property string fontFamily: "SF Pro Display"
    readonly property string fontFamilyDisplay: "SF Pro Display"
    readonly property string fontFamilyText: "SF Pro Text"
    readonly property int fontSizeLarge: 18
    readonly property int fontSizeTitle: 14
    readonly property int fontSizeBody: 13
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
