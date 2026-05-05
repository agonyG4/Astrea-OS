import QtQuick 2.15

Rectangle {
    id: popup

    default property alias contentData: menuColumn.data
    property bool menuVisible: false
    property real menuX: 0
    property real menuY: 0
    property int menuWidth: 200

    visible: menuVisible
    x: menuX
    y: menuY
    width: menuWidth
    height: menuColumn.implicitHeight + 8
    radius: 10
    color: "#1e1e20"
    border.width: 1
    border.color: "#3a3a3c"

    Column {
        id: menuColumn
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.margins: 4
        spacing: 0
    }
}
