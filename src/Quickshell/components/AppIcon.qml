import QtQuick
import "../AstreaComponents" as Components

Item {
    id: root

    property var entry: null
    property color fallbackColor: "#22FFFFFF"
    property color fallbackTextColor: "#E8FFFFFF"
    property int fallbackRadius: 6
    property int fallbackFontSize: Math.max(11, Math.round(Math.min(width, height) * 0.36))
    property bool showFallbackText: true
    property int iconRadius: Math.max(5, Math.round(Math.min(width || implicitWidth, height || implicitHeight) * 0.14))
    property int sourcePixelSize: 192
    property string fallbackIconName: ""

    implicitWidth: 30
    implicitHeight: 30

    Components.AppIcon {
        anchors.fill: parent
        appData: root.entry
        iconSize: Math.round(Math.max(root.width, root.height))
        iconRadius: root.iconRadius
        fallbackRadius: root.fallbackRadius
        fallbackFontSize: root.fallbackFontSize
        iconPadding: 0
        sourcePixelSize: root.sourcePixelSize
        fallbackIconName: root.fallbackIconName
        showFallbackText: root.showFallbackText
        fallbackColor: root.fallbackColor
        fallbackBorderColor: "transparent"
        fallbackTextColor: root.fallbackTextColor
        fallbackFontFamily: ""
    }
}
