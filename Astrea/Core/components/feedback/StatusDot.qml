import QtQuick

Item {
    id: root

    property bool active: false
    property bool pulse: false

    implicitWidth: 8
    implicitHeight: 8

    Rectangle {
        id: dot
        anchors.centerIn: parent
        width: 8
        height: 8
        radius: 4
        color: root.active ? "#3ddc97" : "#ff5f57"
        opacity: 0.95
        scale: 1.0

        SequentialAnimation on scale {
            running: root.pulse
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 1.22; duration: 700; easing.type: Easing.OutCubic }
            NumberAnimation { from: 1.22; to: 1.0; duration: 700; easing.type: Easing.InOutCubic }
        }

        SequentialAnimation on opacity {
            running: root.pulse
            loops: Animation.Infinite
            NumberAnimation { from: 0.95; to: 0.55; duration: 700; easing.type: Easing.OutCubic }
            NumberAnimation { from: 0.55; to: 0.95; duration: 700; easing.type: Easing.InOutCubic }
        }
    }
}
