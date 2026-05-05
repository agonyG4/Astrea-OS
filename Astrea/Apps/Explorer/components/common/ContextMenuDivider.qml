import QtQuick 2.15

Rectangle {
    width: parent ? parent.width - 8 : 184
    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    height: visible ? 5 : 0
    color: "transparent"

    Rectangle {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 1
        color: "#3a3a3c"
    }
}
