import QtQuick
import ".." as Components

Rectangle {
    id: toggle
    width: 36
    height: 20
    radius: Components.Theme.controlRadius
    property bool checked: false
    property bool visualChecked: checked
    signal toggled(bool targetChecked)

    onCheckedChanged: visualChecked = checked
    onEnabledChanged: if (enabled) visualChecked = checked

    color: visualChecked ? Components.Theme.accent : Qt.rgba(1, 1, 1, 0.18)
    opacity: enabled ? 1.0 : 0.55
    Behavior on color { ColorAnimation { duration: 80 } }
    Behavior on opacity { NumberAnimation { duration: Components.Theme.animationMicro } }

    Rectangle {
        width: 14
        height: 14
        radius: height / 2
        color: "#ffffff"
        anchors.verticalCenter: parent.verticalCenter
        x: toggle.visualChecked ? parent.width - width - 3 : 3
        Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: toggle.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const target = !toggle.visualChecked
            toggle.visualChecked = target
            toggle.toggled(target)
        }
    }
}
