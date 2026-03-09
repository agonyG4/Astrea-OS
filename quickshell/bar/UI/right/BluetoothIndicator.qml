import QtQuick

Item {
    property bool btOn: false

    width: 32; height: 34

    Text {
        anchors.centerIn: parent
        text: "󰂯"
        color: btOn ? "#0a84ff" : Qt.rgba(1,1,1,0.22)
        font.pixelSize: 16
        Behavior on color { ColorAnimation { duration: 150 } }
    }
}
