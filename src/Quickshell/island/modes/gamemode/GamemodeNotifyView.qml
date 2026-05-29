import QtQuick

Item {
    id: root

    property bool active: false
    property string fontFamily: ""

    visible: opacity > 0
    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    Text {
        anchors.centerIn: parent
        text: "󰊴"
        font.family: root.fontFamily
        font.pixelSize: 48
        antialiasing: true
        renderType: Text.NativeRendering

        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 1500
            loops: Animation.Infinite
            running: root.active
        }
    }
}
