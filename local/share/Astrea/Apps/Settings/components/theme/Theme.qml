pragma Singleton
import QtQuick

QtObject {
    // ── Icon style ─────────────────────────────────────────────────────────
    // 0 = clear (tinted), 1 = colored (native SVG color)
    property int iconStyle: 0
    // ── Icon theme ─────────────────────────────────────────────────────────
    // "" = default, "dark" = dark theme icons, "light" = light theme icons
    property string iconTheme: "dark"
    // ── Typography ─────────────────────────────────────────────────────────
    readonly property string fontFamily:   "Inter"
    
    readonly property int fontSizeHero:    20
    readonly property int fontSizeHeader:  24
    readonly property int fontSizeIconLarge: 22
    readonly property int fontSizeAvatar:  20
    readonly property int fontSizeSubtitle:16
    readonly property int fontSizeTitle:   15
    readonly property int fontSizeLarge:   12
    readonly property int fontSizeNormal:  12
    readonly property int fontSizeSmall:   11
    readonly property int fontSizeTiny:    11
    readonly property int fontSizeMicro:   11

    readonly property int fontWeightLight:    Font.Light
    readonly property int fontWeightNormal:   Font.Normal
    readonly property int fontWeightMedium:   Font.Medium
    readonly property int fontWeightDemiBold: Font.DemiBold
    readonly property int fontWeightBold:     Font.Bold

    readonly property real trackingHeader:    1.0

    // ── Theme ─────────────────────────────────────────────────────────────
    readonly property color accent:        "#0a84ff"
    readonly property color textPrimary:   "#ffffff"
    readonly property color textSecondary: "#98989f"
    readonly property color cardBg:        Qt.rgba(1, 1, 1, 0.05)
    readonly property color cardBorder:    Qt.rgba(1, 1, 1, 0.08)
    readonly property color popupBg:       Qt.rgba(0.11, 0.11, 0.12, 1)
    readonly property color errorColor:    "#ff453a"
    readonly property color warningColor:  "#ff9f0a"
    readonly property color successColor:  "#30d158"
}
