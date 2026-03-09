import Quickshell.Hyprland
import QtQuick

Row {
    spacing: 6

    Repeater {
        model: Hyprland.workspaces
        delegate: Rectangle {
            required property HyprlandWorkspace modelData
            property bool isActive: Hyprland.focusedMonitor.activeWorkspace.id === modelData.id
            width: isActive ? 32 : 10
            height: 10
            radius: 5
            color: isActive ? "white" : Qt.rgba(1,1,1,0.22)
            anchors.verticalCenter: parent.verticalCenter
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }
            Behavior on color { ColorAnimation  { duration: 180 } }

            MouseArea {
                anchors.fill: parent
                onClicked: Hyprland.dispatch("workspace " + modelData.id)
            }
        }
    }
}
