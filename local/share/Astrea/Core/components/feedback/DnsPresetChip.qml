import QtQuick
import ".." as Components

Rectangle {
    id: root

    property string label: ""
    property string value: ""
    property color chipColor: Components.Theme.accent
    property bool selected: false

    signal clicked()

    implicitWidth: chipRow.implicitWidth + 22
    implicitHeight: 34
    radius: 17
    color: root.selected
           ? Qt.rgba(root.chipColor.r, root.chipColor.g, root.chipColor.b, 0.18)
           : (chipArea.containsMouse ? Qt.rgba(root.chipColor.r, root.chipColor.g, root.chipColor.b, 0.10) : Qt.rgba(1, 1, 1, 0.04))
    border.width: 1
    border.color: root.selected || chipArea.containsMouse ? root.chipColor : Components.Theme.cardBorder

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            width: 8
            height: 8
            radius: 4
            color: root.chipColor
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.label
            color: root.selected ? "#ffffff" : Components.Theme.textSecondary
            font.family: Components.Theme.fontFamily
            font.pixelSize: Components.Theme.fontSizeSmall
            font.weight: root.selected ? Components.Theme.fontWeightDemiBold : Components.Theme.fontWeightMedium
        }
    }

    MouseArea {
        id: chipArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
