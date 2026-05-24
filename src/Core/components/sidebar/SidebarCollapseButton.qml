import QtQuick
import ".." as Components

Item {
    id: root

    property bool collapsed: false
    property bool enabled: true
    property int controlSize: 30
    property color iconColor: Components.Theme.textSecondary
    property color hoverIconColor: Components.Theme.textPrimary

    signal clicked()

    implicitWidth: controlSize
    implicitHeight: controlSize
    opacity: enabled ? 1 : Components.Theme.opacityDisabled

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 8
        color: pressArea.pressed
            ? (Components.Theme.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.075) : Qt.rgba(1, 1, 1, 0.10))
            : hover.hovered
                ? (Components.Theme.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.07))
                : "transparent"

        Behavior on color { ColorAnimation { duration: Components.Theme.animationQuick; easing.type: Easing.OutCubic } }
    }

    Item {
        id: glyph
        width: 15
        height: 13
        anchors.centerIn: parent
        scale: pressArea.pressed ? 0.94 : 1

        Behavior on scale { NumberAnimation { duration: Components.Theme.animationQuick; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: 4.5
            color: "transparent"
            border.width: 1.1
            border.color: hover.hovered ? root.hoverIconColor : root.iconColor

            Behavior on border.color { ColorAnimation { duration: Components.Theme.animationQuick; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            width: 1.1
            height: parent.height - 3.5
            radius: 1
            x: 5
            anchors.verticalCenter: parent.verticalCenter
            color: hover.hovered ? root.hoverIconColor : root.iconColor

            Behavior on color { ColorAnimation { duration: Components.Theme.animationQuick; easing.type: Easing.OutCubic } }
        }
    }

    HoverHandler {
        id: hover
        enabled: root.enabled
    }

    MouseArea {
        id: pressArea
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
