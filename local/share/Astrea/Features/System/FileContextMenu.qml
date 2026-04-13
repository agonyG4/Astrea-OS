import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: menuRoot
    anchors.fill: parent
    visible: menuOpen
    z: 999
    focus: visible

    default property alias contentData: menuColumn.data

    property real menuX: 0
    property real menuY: 0
    property int menuWidth: 200
    property bool menuOpen: false
    property bool closeOnEscape: true
    property bool closeOnBackdropPress: true

    function openAt(x, y) {
        menuX = Math.max(10, Math.min(x, width - menuCard.width - 10))
        menuY = Math.max(10, Math.min(y, height - menuCard.height - 10))
        menuOpen = true
    }

    function closeMenu() {
        menuOpen = false
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
        width: menuRoot.menuWidth
        height: menuColumn.implicitHeight + 8
        radius: 10
        color: "#1e1e20"
        border.width: 1
        border.color: "#3a3a3c"

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
