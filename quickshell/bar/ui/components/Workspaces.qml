import Quickshell.Hyprland
import QtQuick

Row {
    spacing: 6

    Repeater {
        // Filtra workspaces especiais (ex: scratchpad 'special:magic' que tem id < 0)
        model: Hyprland.workspaces.values.filter(ws => ws.id > 0)
        delegate: Rectangle {
            required property HyprlandWorkspace modelData
            property bool isActive: modelData.active
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
