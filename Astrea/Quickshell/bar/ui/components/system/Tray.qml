import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import "../../.."

Row {
    id: root
    spacing: 8
    height:  36

    TrayContextMenu {
        id: contextMenu
    }

    Repeater {
        model: SystemTray.items
        delegate: Rectangle {
            id: trayItem

            readonly property bool isHovered: trayHover.hovered
            readonly property bool isPressed:  trayArea.pressed

            anchors.verticalCenter: parent.verticalCenter
            width:  28; height: 28
            radius: Theme.radiusMedium
            color:  isHovered || isPressed ? (isPressed ? Qt.rgba(1, 1, 1, 0.2) : Theme.separator) : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            ToolTip.visible: isHovered && (modelData.tooltipTitle !== "" || modelData.title !== "")
            ToolTip.text:    modelData.tooltipTitle || modelData.title || ""
            ToolTip.delay:   500

            Image {
                anchors.centerIn: parent
                width: 16; height: 16
                source:   modelData.icon || ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }

            HoverHandler { id: trayHover }

            MouseArea {
                id: trayArea
                anchors.fill:    parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape:     Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        modelData.activate()
                    } else if (mouse.button === Qt.MiddleButton) {
                        modelData.secondaryActivate()
                    } else {
                        const point = trayItem.mapToItem(null, trayItem.width / 2, trayItem.height / 2)
                        contextMenu.openFor(modelData, point.x)
                    }
                }
            }
        }
    }
}
