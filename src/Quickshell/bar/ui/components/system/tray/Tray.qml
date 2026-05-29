import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../../.."

Row {
    id: root
    spacing: Theme.spacing
    height:  36
    property real anchorOffset: 0

    function trayIconSource(icon) {
        if (!icon)
            return ""

        const marker = "?path="
        const markerIndex = icon.indexOf(marker)
        if (markerIndex < 0)
            return icon

        const name = icon.slice(0, markerIndex).replace(/^image:\/\/icon\//, "")
        const path = icon.slice(markerIndex + marker.length)
        if (!name || !path)
            return icon

        const fileName = name.match(/\.(png|svg|ico|xpm)$/i) ? name : name + ".png"
        return "file://" + path.replace(/\/$/, "") + "/" + fileName
    }

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
            color:  isHovered || isPressed ? (isPressed ? Qt.rgba(1, 1, 1, 0.2) : Theme.shellSeparator) : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.animationFast } }

            Image {
                anchors.centerIn: parent
                width: 16; height: 16
                sourceSize: Qt.size(width, height)
                source:   root.trayIconSource(modelData.icon || "")
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Rectangle {
                id: trayTooltip
                readonly property string label: modelData.tooltipTitle || modelData.title || ""
                z: 100
                visible: trayHover.hovered && label !== ""
                opacity: visible ? 1 : 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height + 6
                width: Math.min(260, tooltipText.implicitWidth + 18)
                height: 28
                radius: Theme.radiusSmall
                color: Theme.background
                border.width: 1
                border.color: Theme.border

                Behavior on opacity { NumberAnimation { duration: Theme.animationFast } }

                Text {
                    id: tooltipText
                    anchors.centerIn: parent
                    width: parent.width - 12
                    text: trayTooltip.label
                    color: Theme.shellTextActive
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeCaption
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    renderType: Text.NativeRendering
                }
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
                        contextMenu.openFor(modelData, point.x + root.anchorOffset)
                    }
                }
            }
        }
    }
}
