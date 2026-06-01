pragma Singleton
import QtQuick

QtObject {
    readonly property string fontFamily: "Inter"
    readonly property string monoFontFamily: "JetBrains Mono"

    readonly property int fontSizeHero: 20
    readonly property int fontSizeHeader: 24
    readonly property int fontSizeIconLarge: 22
    readonly property int fontSizeAvatar: 20
    readonly property int fontSizeSubtitle: 16
    readonly property int fontSizeTitle: 15
    readonly property int fontSizeLarge: 13
    readonly property int fontSizeNormal: 12
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeTiny: 10
    readonly property int fontSizeMicro: 9

    readonly property int fontWeightLight: Font.Light
    readonly property int fontWeightNormal: Font.Normal
    readonly property int fontWeightMedium: Font.Medium
    readonly property int fontWeightDemiBold: Font.Medium
    readonly property int fontWeightBold: Font.Bold

    readonly property real trackingHeader: 0

    readonly property real radiusSmall: 8
    readonly property real radiusMedium: 10
    readonly property real radiusLarge: 12
    readonly property real cornerRadiusSmall: radiusSmall
    readonly property real cornerRadius: radiusMedium
    readonly property real cornerRadiusLarge: radiusLarge
    readonly property real cardRadius: radiusLarge
    readonly property real controlRadius: radiusMedium

    readonly property real spacingTiny: 2
    readonly property real spacingMicro: 4
    readonly property real spacingSmall: 6
    readonly property real spacing: 8
    readonly property real spacingMedium: 12
    readonly property real spacingLarge: 16
    readonly property real spacingXLarge: 18
    readonly property real pageMargin: 28

    readonly property int animationMicro: 100
    readonly property int animationQuick: 120
    readonly property int animationFast: 150
    readonly property int animationNormal: 200
    readonly property int animationSlow: 250
    readonly property int animationPopover: 300

    readonly property real opacityDisabled: 0.3
    readonly property real opacitySecondary: 0.5
    readonly property real opacityMuted: 0.6
}
