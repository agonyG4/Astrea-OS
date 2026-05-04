import QtQuick
import ".." as Components

Rectangle {
    id: toggle
    width: 36
    height: 20
    radius: 10
    property bool checked: false
    signal toggled()
    color: checked ? Components.Theme.accent : Qt.rgba(1, 1, 1, 0.18)
    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        width: 14
        height: 14
        radius: 7
        color: "#ffffff"
        anchors.verticalCenter: parent.verticalCenter
        x: toggle.checked ? parent.width - width - 3 : 3
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled()
    }
}
