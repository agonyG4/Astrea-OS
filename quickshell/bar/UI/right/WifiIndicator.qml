import QtQuick

Item {
    property bool wifiConnected: false

    width: 32; height: 34

    Text {
        anchors.centerIn: parent
        text: wifiConnected ? "" : "󰖪"
        color: wifiConnected ? Qt.rgba(1,1,1,0.62) : "#ff375f"
        font.pixelSize: 16
        Behavior on color { ColorAnimation { duration: 150 } }
    }
}
