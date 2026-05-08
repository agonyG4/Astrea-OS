import QtQuick

Item {
    id: actionRoot

    property string label: ""
    property bool destructive: false
    property bool actionEnabled: true
    readonly property bool hovered: hoverArea.containsMouse
    property bool hasSubmenu: false
    property color hoverColor: destructive ? "#3a1a1a" : "#2c2c2e"
    property color textColor: destructive ? "#ff6b6b" : "#f2f2f7"
    property color disabledTextColor: "#636366"
    signal triggered()

    width: parent ? parent.width : 192
    height: visible ? 32 : 0

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: hoverArea.containsMouse && actionRoot.actionEnabled
            ? actionRoot.hoverColor
            : "transparent"
        Behavior on color { ColorAnimation { duration: 60 } }
    }

    Text {
        anchors {
            left: parent.left
            leftMargin: 12
            verticalCenter: parent.verticalCenter
        }
        width: parent.width - (actionRoot.hasSubmenu ? 36 : 24)
        text: actionRoot.label
        color: actionRoot.actionEnabled
            ? actionRoot.textColor
            : actionRoot.disabledTextColor
        font.pixelSize: 13
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    Text {
        anchors {
            right: parent.right
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
        visible: actionRoot.hasSubmenu
        text: ">"
        color: actionRoot.actionEnabled
            ? actionRoot.textColor
            : actionRoot.disabledTextColor
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
