import QtQuick
import "../AstreaComponents" as Astrea

Rectangle {
    id: chip

    property string label: ""
    property int count: -1
    property bool selected: false
    property color selectedBg: Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.16)
    property color selectedBorder: Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.34)
    property color softSurface: Astrea.Theme.cardBg
    property color hoverSurface: Qt.rgba(1, 1, 1, 0.060)
    signal clicked()

    implicitWidth: chipText.implicitWidth + (count >= 0 ? countText.implicitWidth + 24 : 18)
    implicitHeight: 30
    radius: Astrea.Theme.controlRadius
    color: selected ? selectedBg : (chipHover.hovered ? hoverSurface : softSurface)
    border.width: 1
    border.color: selected ? selectedBorder : Astrea.Theme.cardBorder
    scale: chipPress.pressed ? 0.98 : 1

    Behavior on color { ColorAnimation { duration: Astrea.Theme.animationQuick; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: Astrea.Theme.animationQuick; easing.type: Easing.OutCubic } }

    HoverHandler { id: chipHover }

    Row {
        anchors.centerIn: parent
        spacing: 6

        Astrea.TextLabel {
            id: chipText
            text: chip.label
            textColor: chip.selected ? Astrea.Theme.textPrimary : Astrea.Theme.textSecondary
            font.pixelSize: Astrea.Theme.fontSizeSmall
            font.weight: chip.selected ? Astrea.Theme.fontWeightDemiBold : Astrea.Theme.fontWeightMedium
        }

        Astrea.TextLabel {
            id: countText
            visible: chip.count >= 0
            text: chip.count
            textColor: chip.selected ? Astrea.Theme.accent : Astrea.Theme.textTertiary
            font.pixelSize: Astrea.Theme.fontSizeTiny
            font.weight: Astrea.Theme.fontWeightDemiBold
        }
    }

    MouseArea {
        id: chipPress
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
