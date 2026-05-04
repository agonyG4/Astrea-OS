import QtQuick 2.15

Item {
    id: actionRoot

    property string label: ""
    property bool destructive: false
    property bool actionEnabled: true
    signal triggered()

    width: parent ? parent.width : 192
    height: visible ? 32 : 0

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: hoverArea.containsMouse && actionRoot.actionEnabled
            ? (actionRoot.destructive ? "#3a1a1a" : "#2c2c2e")
            : "transparent"
        Behavior on color { ColorAnimation { duration: 60 } }
    }

    Text {
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        text: actionRoot.label
        color: actionRoot.actionEnabled
            ? (actionRoot.destructive ? "#ff6b6b" : "#f2f2f7")
            : "#636366"
        font.pixelSize: 13
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        enabled: actionRoot.actionEnabled
        hoverEnabled: true
        cursorShape: actionRoot.actionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: actionRoot.triggered()
    }
}
