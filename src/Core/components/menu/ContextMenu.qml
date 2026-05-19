import QtQuick
import QtQuick.Controls

Item {
    id: menuRoot

    anchors.fill: parent
    visible: menuOpen
    z: 999
    focus: visible

    default property alias contentData: menuColumn.data

    property real menuX: 0
    property real menuY: 0
    property real requestedX: 0
    property real requestedY: 0
    property int menuWidth: 200
    property bool menuOpen: false
    property bool menuPositioned: false
    property bool closeOnEscape: true
    property bool closeOnBackdropPress: true
    property real edgePadding: 10
    property real cardRadius: 10
    property color panelColor: "#1e1e20"
    property color borderColor: "#3a3a3c"

    function positionAt(x, y) {
        const cardWidth = menuWidth
        const cardHeight = Math.max(0, menuColumn.implicitHeight + 8)
        const maxX = Math.max(edgePadding, width - cardWidth - edgePadding)
        const maxY = Math.max(edgePadding, height - cardHeight - edgePadding)
        let nextX = x
        let nextY = y

        if (nextX + cardWidth > width - edgePadding)
            nextX = x - cardWidth
        if (nextY + cardHeight > height - edgePadding)
            nextY = y - cardHeight

        menuX = Math.max(edgePadding, Math.min(nextX, maxX))
        menuY = Math.max(edgePadding, Math.min(nextY, maxY))
        menuPositioned = true
    }

    function openAt(x, y) {
        requestedX = x
        requestedY = y
        menuPositioned = false
        menuOpen = true
        Qt.callLater(() => positionAt(requestedX, requestedY))
    }

    function closeMenu() {
        menuOpen = false
        menuPositioned = false
    }

    Shortcut {
        sequence: "Esc"
        enabled: menuRoot.visible && menuRoot.closeOnEscape
        onActivated: menuRoot.closeMenu()
    }

    MouseArea {
        anchors.fill: parent
        enabled: menuRoot.menuOpen && menuRoot.closeOnBackdropPress
        acceptedButtons: Qt.AllButtons
        onPressed: function(mouse) {
            mouse.accepted = true
            menuRoot.closeMenu()
        }
    }

    Rectangle {
        id: menuCard

        visible: menuRoot.menuOpen
        x: menuRoot.menuX
        y: menuRoot.menuY
        opacity: menuRoot.menuPositioned ? 1 : 0
        width: menuRoot.menuWidth
        height: menuColumn.implicitHeight + 8
        radius: menuRoot.cardRadius
        color: menuRoot.panelColor
        border.width: 1
        border.color: menuRoot.borderColor

        onHeightChanged: {
            if (menuRoot.menuOpen)
                Qt.callLater(() => menuRoot.positionAt(menuRoot.requestedX, menuRoot.requestedY))
        }

        Column {
            id: menuColumn

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 4
            }
            spacing: 0
        }
    }
}
