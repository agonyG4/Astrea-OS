import QtQuick
import "../../bar"
import "../../components" as ShellComponents

Item {
    id: tile

    property var entry: null
    property var desktopState: null
    property var hostWindow: null
    property var hostItem: null

    readonly property var appData: entry
    readonly property bool ready: desktopState !== null && hostWindow !== null && hostItem !== null && tile.appData !== null
    readonly property int effectiveSlot: tile.ready && tile.appData && desktopState.gridPositions[tile.appData.desktop] !== undefined
        ? desktopState.gridPositions[tile.appData.desktop]
        : tile.ready ? desktopState.indexForDesktop(tile.appData ? tile.appData.desktop : "") : 0
    readonly property point targetPosition: hostWindow ? hostWindow.defaultPosition(effectiveSlot) : Qt.point(0, 0)
    readonly property bool selected: tile.ready && desktopState.selectedDesktop === tile.appData.desktop
    readonly property bool hovered: tileHover.hovered

    width: desktopState ? desktopState.cellWidth : 96
    height: desktopState ? desktopState.cellHeight : 104
    z: tile.dragging ? 20 : tile.selected ? 10 : 1

    property bool dragging: false
    property bool suppressClick: false
    property real pressTileX: 0
    property real pressTileY: 0
    property real pressMouseX: 0
    property real pressMouseY: 0

    Binding {
        target: tile
        property: "x"
        value: tile.targetPosition.x
        when: !tile.dragging
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: tile
        property: "y"
        value: tile.targetPosition.y
        when: !tile.dragging
        restoreMode: Binding.RestoreNone
    }

    Behavior on x {
        enabled: !tile.dragging
        NumberAnimation { duration: Theme.animationQuick; easing.type: Easing.OutCubic }
    }

    Behavior on y {
        enabled: !tile.dragging
        NumberAnimation { duration: Theme.animationQuick; easing.type: Easing.OutCubic }
    }

    Connections {
        target: tile.hostItem
        function onWidthChanged() { if (tile.ready && !tile.dragging) tile.hostWindow.clampTile(tile) }
        function onHeightChanged() { if (tile.ready && !tile.dragging) tile.hostWindow.clampTile(tile) }
    }

    Rectangle {
        id: hl
        width: desktopState ? desktopState.highlightWidth : 86
        height: desktopState ? desktopState.highlightHeight : 92
        x: Math.round((parent.width - width) / 2)
        y: 3
        radius: Theme.cornerRadius
        color: tile.selected ? "#3a3a3c" : tile.hovered ? "#2e2e30" : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animationInstant }
        }
    }

    ShellComponents.AppIcon {
        id: appIcon
        anchors.horizontalCenter: parent.horizontalCenter
        y: hl.y + 8
        width: desktopState ? desktopState.iconSize : 52
        height: desktopState ? desktopState.iconSize : 52
        entry: tile.appData
        iconRadius: Math.max(8, Math.round(width * 0.18))
        fallbackRadius: iconRadius
        fallbackColor: "transparent"
        fallbackIconName: "application-x-executable"
        showFallbackText: false
        sourcePixelSize: Math.max(128, Math.round(width * 3))
    }

    Text {
        id: appLabel
        anchors.top: appIcon.bottom
        anchors.topMargin: Theme.spacingSmall
        width: desktopState ? desktopState.labelWidth : 92
        height: desktopState ? desktopState.labelHeight : 34
        anchors.horizontalCenter: parent.horizontalCenter
        text: tile.appData ? tile.appData.name : ""
        color: "#f8f8f8"
        font.family: Theme.fontFamily
        font.pixelSize: desktopState && desktopState.iconPreset === "large" ? 13 : desktopState && desktopState.iconPreset === "small" ? 11 : 12
        font.weight: Font.Normal
        font.hintingPreference: Font.PreferVerticalHinting
        antialiasing: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignTop
        wrapMode: Text.Wrap
        maximumLineCount: 2
        lineHeight: 1.0
        lineHeightMode: Text.ProportionalHeight
        elide: Text.ElideRight
        textFormat: Text.PlainText
        style: Text.Raised
        styleColor: "#99000000"
    }

    HoverHandler {
        id: tileHover
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        z: 1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        propagateComposedEvents: false
        preventStealing: true
        enabled: tile.ready

        function beginDrag() {
            if (tile.dragging || !tile.ready)
                return

            tile.dragging = true
            tile.suppressClick = true
            tile.hostWindow.closeContext()
        }

        function updateTileFromMouse(mouse) {
            if (!tile.ready)
                return

            const pt = pointer.mapToItem(tile.hostItem, mouse.x, mouse.y)
            tile.x = tile.pressTileX + pt.x - tile.pressMouseX
            tile.y = tile.pressTileY + pt.y - tile.pressMouseY
            tile.hostWindow.clampTile(tile)
        }

        function finishDrag(mouse) {
            if (!tile.ready) {
                tile.dragging = false
                tile.suppressClick = false
                return
            }

            if (tile.dragging) {
                if (mouse)
                    updateTileFromMouse(mouse)
                const center = appIcon.mapToItem(tile.hostItem, appIcon.width / 2, appIcon.height / 2)
                const target = tile.hostWindow.dropTargetForPoint(center.x, center.y, tile.appData.desktop)
                tile.desktopState.setDesktopSlot(tile.appData.desktop, target.slot, target.swap)
            }

            tile.dragging = false
            tile.hostWindow.clampTile(tile)
        }

        onPressed: function(mouse) {
            if (!tile.ready)
                return

            tile.desktopState.selectedDesktop = tile.appData.desktop
            if (mouse.button === Qt.LeftButton) {
                const pt = pointer.mapToItem(tile.hostItem, mouse.x, mouse.y)
                tile.pressTileX = tile.x
                tile.pressTileY = tile.y
                tile.pressMouseX = pt.x
                tile.pressMouseY = pt.y
                tile.suppressClick = false
            }
        }

        onPositionChanged: function(mouse) {
            if (!tile.ready)
                return

            if (!(pointer.pressedButtons & Qt.LeftButton))
                return

            const pt = pointer.mapToItem(tile.hostItem, mouse.x, mouse.y)
            const dx = pt.x - tile.pressMouseX
            const dy = pt.y - tile.pressMouseY
            const threshold = 8

            if (!tile.dragging && Math.sqrt(dx * dx + dy * dy) >= threshold)
                beginDrag()

            if (tile.dragging)
                updateTileFromMouse(mouse)
        }

        onClicked: function(mouse) {
            mouse.accepted = true
            if (tile.suppressClick) {
                tile.suppressClick = false
                return
            }
            if (!tile.ready)
                return
            tile.desktopState.selectedDesktop = tile.appData.desktop
            if (mouse.button === Qt.RightButton) {
                const pt = pointer.mapToItem(tile.hostItem, mouse.x, mouse.y)
                tile.hostWindow.openContextAt(pt.x, pt.y, tile.appData, false)
            } else {
                tile.hostWindow.closeContext()
            }
        }

        onDoubleClicked: function(mouse) {
            mouse.accepted = true
            if (!tile.ready)
                return
            tile.desktopState.selectedDesktop = tile.appData.desktop
            tile.hostWindow.closeContext()
            tile.desktopState.openDesktopItem(tile.appData)
        }

        onReleased: function(mouse) {
            finishDrag(mouse)
        }

        onCanceled: {
            finishDrag(null)
            tile.suppressClick = false
        }
    }
}
