import Quickshell.Hyprland
import QtQuick
import "../../../.."
Item {
    id: root

    readonly property var visibleWorkspaces: Hyprland.workspaces.values
        .filter(ws => ws.id > 0)
        .sort((a, b) => a.id - b.id)
    readonly property int workspaceCount: visibleWorkspaces.length
    readonly property int stableWidth: workspaceCount <= 0 ? 0
        : Theme.workspaceActiveWidth
          + Math.max(0, workspaceCount - 1) * (Theme.workspaceDotSize + Theme.spacingSmall)
    readonly property int reservedWorkspaceSlots: 10
    readonly property int reservedWidth: Theme.workspaceActiveWidth
        + Math.max(0, reservedWorkspaceSlots - 1) * (Theme.workspaceDotSize + Theme.spacingSmall)

    function switchToWorkspace(workspaceId) {
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspaceId + " })")
    }

    implicitWidth: stableWidth
    implicitHeight: Theme.workspaceDotSize
    clip: true

    Row {
        id: workspaceRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingSmall

        Repeater {
            // Filtra workspaces especiais (ex: scratchpad 'special:magic' que tem id < 0)
            model: root.visibleWorkspaces
            delegate: Rectangle {
                required property HyprlandWorkspace modelData
                property bool isActive: modelData.active
                width: isActive ? Theme.workspaceActiveWidth : Theme.workspaceDotSize
                height: Theme.workspaceDotSize
                radius: Theme.workspaceDotSize / 2
                color: isActive ? Theme.workspaceActive : Theme.workspaceInactive
                anchors.verticalCenter: parent.verticalCenter
                Behavior on width { NumberAnimation { duration: Theme.animationNormal; easing.type: Easing.OutExpo } }
                Behavior on color { ColorAnimation  { duration: Theme.animationNormal - 20 } }
                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin:    -10
                    anchors.bottomMargin: -10
                    anchors.leftMargin:   -6
                    anchors.rightMargin:  -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchToWorkspace(modelData.id)
                }
            }
        }
    }
}
