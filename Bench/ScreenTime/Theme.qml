pragma Singleton
import QtQuick 2.15

QtObject {
    readonly property color bg: "#151517"
    readonly property color cardBg: "#2F2F34"
    readonly property color cardBorder: "#45454C"
    readonly property color textPrimary: "#F5F5F7"
    readonly property color textSecondary: "#D7D7DD"
    readonly property color textTertiary: "#B9B9C2"
    readonly property color accent: "#007AFF"
    readonly property color green: "#30D158"
    readonly property color amber: "#FFD60A"
    readonly property color red: "#FF453A"
    readonly property color track: "#44444B"

    readonly property int fontTiny: 9
    readonly property int fontSmall: 11
    readonly property int fontRegular: 13
    readonly property int fontMedium: 15
    readonly property int fontLarge: 22
    readonly property int fontXLarge: 34
    readonly property int cardRadius: 18
}
