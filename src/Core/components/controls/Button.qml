import QtQuick
import ".." as Components

Rectangle {
    id: root

    property string label: ""
    property string text: label
    property string iconSource: ""
    property string iconText: ""
    property string iconFontFamily: Components.Theme.fontFamily
    property bool primary: false
    property bool danger: false
    property bool flat: false
    property bool enabled: true
    property int fontPixelSize: Components.Theme.fontSizeNormal
    property int iconSize: Math.round(fontPixelSize + 4)
    property int controlWidth: 0
    property int controlHeight: 34
    property int minWidth: 36
    property int horizontalPadding: Components.Theme.spacingMedium
    property int contentSpacing: Components.Theme.spacingSmall
    property color accentColor: danger ? Components.Theme.errorColor : Components.Theme.accent
    property color foregroundColor: primary ? Components.Theme.accentForeground : Components.Theme.textPrimary
    property color mutedForegroundColor: Components.Theme.textSecondary

    readonly property bool hovered: hoverArea.hovered
    readonly property bool pressed: pressArea.pressed
    readonly property bool isLight: Components.Theme.themeMode === 1
    readonly property color subtleBg: isLight ? Qt.rgba(0, 0, 0, 0.035) : Qt.rgba(1, 1, 1, 0.035)
    readonly property color flatHoverBg: isLight ? Qt.rgba(0, 0, 0, 0.055) : Qt.rgba(1, 1, 1, 0.07)
    readonly property color flatPressedBg: isLight ? Qt.rgba(0, 0, 0, 0.075) : Qt.rgba(1, 1, 1, 0.10)
    readonly property color hoverBg: isLight ? Qt.rgba(0, 0, 0, 0.055) : Qt.rgba(1, 1, 1, 0.09)
    readonly property color pressedBg: isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.12)

    signal clicked()

    implicitWidth: controlWidth > 0 ? controlWidth : Math.max(minWidth, labelRow.implicitWidth + horizontalPadding * 2)
    implicitHeight: controlHeight
    radius: Components.Theme.controlRadius
    opacity: enabled ? 1 : Components.Theme.opacityDisabled
    color: {
        if (!enabled)
            return subtleBg
        if (primary)
            return pressed ? Qt.darker(accentColor, 1.12) : accentColor
        if (flat)
            return pressed ? flatPressedBg : (hovered ? flatHoverBg : "transparent")
        return pressed ? pressedBg : (hovered ? hoverBg : Components.Theme.cardBg)
    }
    border.width: flat ? 0 : 1
    border.color: primary ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.55) : Components.Theme.cardBorder
    scale: enabled && pressed ? 0.97 : 1.0

    Behavior on color { ColorAnimation { duration: Components.Theme.animationQuick; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: Components.Theme.animationQuick; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: Components.Theme.animationQuick; easing.type: Easing.OutCubic } }

    HoverHandler { id: hoverArea; enabled: root.enabled }

    Row {
        id: labelRow
        anchors.centerIn: parent
        spacing: (root.text !== "" && (root.iconText !== "" || root.iconSource !== "")) ? root.contentSpacing : 0

        Image {
            visible: root.iconSource !== ""
            source: root.iconSource
            width: root.iconSize
            height: root.iconSize
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            opacity: root.enabled ? 1 : Components.Theme.opacityMuted
        }

        Text {
            visible: root.iconText !== "" && root.iconSource === ""
            text: root.iconText
            color: root.enabled ? (root.primary ? root.foregroundColor : root.mutedForegroundColor) : Components.Theme.textTertiary
            font.family: root.iconFontFamily
            font.pixelSize: root.iconSize
            font.weight: Components.Theme.fontWeightMedium
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            visible: root.text !== ""
            text: root.text
            color: root.enabled ? root.foregroundColor : Components.Theme.textTertiary
            font.family: Components.Theme.fontFamily
            font.pixelSize: root.fontPixelSize
            font.weight: Components.Theme.fontWeightMedium
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    MouseArea {
        id: pressArea
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
