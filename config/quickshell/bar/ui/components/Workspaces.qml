import Quickshell.Hyprland
import QtQuick
import "../.."
Row {
    spacing: 6
    Repeater {
        // Filtra workspaces especiais (ex: scratchpad 'special:magic' que tem id < 0)
        model: Hyprland.workspaces.values.filter(ws => ws.id > 0)
        delegate: Rectangle {
            required property HyprlandWorkspace modelData
            property bool isActive: modelData.active
            width: isActive ? Theme.workspaceActiveWidth : Theme.workspaceDotSize
            height: Theme.workspaceDotSize
            radius: Theme.workspaceDotSize / 2
            color: isActive ? Theme.workspaceActive : Theme.workspaceInactive
            anchors.verticalCenter: parent.verticalCenter
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }
            Behavior on color { ColorAnimation  { duration: 180 } }
            MouseArea {
                anchors.fill: parent
                anchors.topMargin:    -10
                anchors.bottomMargin: -10
                anchors.leftMargin:   -6
                anchors.rightMargin:  -6
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + modelData.id)
            }
        }
    }
}