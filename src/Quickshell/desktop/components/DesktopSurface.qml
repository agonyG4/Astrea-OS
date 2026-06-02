import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: desktopWindow

    required property var modelData
    property var desktopRoot: null
    property var clipboardProxy: null
    property bool appLoadRunning: false
    property bool createFolderRunning: false

    screen: modelData
    color: "transparent"
    visible: true

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.namespace: "astrea-desktop-icons"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    function openContextAt(x, y, app, background) {
        desktopRoot.contextApp = app
        desktopRoot.contextIsBackground = background
        contextMenu.openAt(x, y)
    }

    function closeContext() {
        contextMenu.menuVisible = false
    }

    function defaultPosition(index) {
        var left = 8
        var top = 58
        var bottom = 6
        var slot = Math.max(0, Number(index) || 0)
        var usableHeight = Math.max(desktopRoot.cellHeight, contextHost.height - top - bottom)
        var rows = Math.max(1, Math.ceil(usableHeight / desktopRoot.cellHeight))
        var rowStep = rows > 1 ? (usableHeight - desktopRoot.cellHeight) / (rows - 1) : desktopRoot.cellHeight
        var col = Math.floor(slot / rows)
        var row = slot % rows
        return Qt.point(left + col * desktopRoot.cellWidth, top + Math.round(row * rowStep))
    }

    function slotIndexFor(x, y) {
        var left = 8
        var top = 58
        var bottom = 6
        var usableHeight = Math.max(desktopRoot.cellHeight, contextHost.height - top - bottom)
        var rows = Math.max(1, Math.ceil(usableHeight / desktopRoot.cellHeight))
        var rowStep = rows > 1 ? (usableHeight - desktopRoot.cellHeight) / (rows - 1) : desktopRoot.cellHeight
        var col = Math.max(0, Math.floor((x - left) / desktopRoot.cellWidth))
        var row = Math.max(0, Math.floor((y - top) / rowStep))
        row = Math.min(row, rows - 1)
        return col * rows + row
    }

    function pointInsideSlotHitbox(slot, x, y) {
        var pos = defaultPosition(slot)
        var side = desktopRoot.iconSize
        var centerX = pos.x + desktopRoot.cellWidth / 2
        var centerY = pos.y + 3 + 8 + desktopRoot.iconSize / 2

        return Math.abs(x - centerX) <= side / 2
            && Math.abs(y - centerY) <= side / 2
    }

    function occupiedHitboxSlotForPoint(x, y, exceptDesktop) {
        var items = desktopRoot.orderedApps()

        for (var i = 0; i < items.length; i++) {
            var desktop = items[i].desktop
            if (!desktop || desktop === exceptDesktop)
                continue

            var slot = desktopRoot.gridPositions[desktop] !== undefined ? desktopRoot.gridPositions[desktop] : i
            if (pointInsideSlotHitbox(slot, x, y))
                return slot
        }

        return -1
    }

    function dropTargetForPoint(x, y, desktop) {
        var hitSlot = occupiedHitboxSlotForPoint(x, y, desktop)
        if (hitSlot >= 0)
            return { slot: hitSlot, swap: true }

        return { slot: slotIndexFor(x, y), swap: false }
    }

    function clampTile(tile) {
        tile.x = Math.max(0, Math.min(tile.x, contextHost.width - tile.width))
        tile.y = Math.max(48, Math.min(tile.y, contextHost.height - tile.height))
    }

    Rectangle {
        id: contextHost
        anchors.fill: parent
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    if (contextMenu.menuVisible) {
                        desktopWindow.closeContext()
                        return
                    }

                    desktopRoot.selectedDesktop = ""
                    desktopWindow.openContextAt(mouse.x, mouse.y, null, true)
                } else if (mouse.button === Qt.LeftButton) {
                    desktopRoot.selectedDesktop = ""
                    desktopWindow.closeContext()
                }
            }
        }

        Item {
            id: iconLayer
            anchors.fill: parent

            Repeater {
                id: iconRepeater
                model: {
                    desktopRoot.layoutVersion
                    contextHost.width
                    contextHost.height
                    return desktopRoot.visibleApps()
                }

                delegate: DesktopIconTile {
                    entry: modelData
                    desktopState: desktopRoot
                    hostWindow: desktopWindow
                    hostItem: contextHost
                }
            }
        }

        DesktopContextMenu {
            id: contextMenu
            anchors.fill: parent
            z: 1000
            desktopRoot: desktopWindow.desktopRoot
            desktopWindow: desktopWindow
            clipboardProxy: desktopWindow.clipboardProxy
            appLoadRunning: desktopWindow.appLoadRunning
            createFolderRunning: desktopWindow.createFolderRunning
        }
    }
}
