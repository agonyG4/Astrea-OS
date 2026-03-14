import QtQuick
import Quickshell.Io
import "../.."

Item {
    id: root

    property bool   btOn:           false
    property var    btPopupRef:     null
    property bool   isActive:       root.btPopupRef ? root.btPopupRef.shown : false
    property bool   isScanning:     root.btPopupRef ? root.btPopupRef.scanning : false
    property int    connectedCount: root.btPopupRef ? root.btPopupRef.parsedDevices.filter(d => d.connected).length : 0

    width:  btRow.implicitWidth + 16
    height: 34

    // ── background ────────────────────────────────────────────────
    Rectangle {
        anchors.fill:    parent
        anchors.margins: 3
        radius:          Theme.radiusMedium - 2
        color: root.isActive
            ? Qt.rgba(1, 1, 1, 0.15)
            : (btArea.pressed
                ? Qt.rgba(1, 1, 1, 0.12)
                : (btHover.hovered ? Theme.separator : "transparent"))
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    HoverHandler { id: btHover }

    Row {
        id: btRow
        anchors.centerIn: parent
        spacing: 5

        // ── ícone BT ──────────────────────────────────────────────
        Item {
            width:  18
            height: 18
            anchors.verticalCenter: parent.verticalCenter

            // pulso animado ao redor do ícone quando scanning
            Rectangle {
                anchors.centerIn: parent
                width: 18; height: 18; radius: 9
                color: "transparent"
                border.width: 1.5
                border.color: Qt.rgba(0.35, 0.65, 1, 0.7)
                visible: root.isScanning

                SequentialAnimation on opacity {
                    running: root.isScanning
                    loops:   Animation.Infinite
                    NumberAnimation { to: 0;   duration: 900 }
                    NumberAnimation { to: 0.9; duration: 0   }
                }
                SequentialAnimation on scale {
                    running: root.isScanning
                    loops:   Animation.Infinite
                    NumberAnimation { to: 1.8; duration: 900; easing.type: Easing.OutCubic }
                    NumberAnimation { to: 1.0; duration: 0   }
                }
            }

            Text {
                id: btIcon
                anchors.centerIn: parent
                text: root.btOn ? "󰂯" : "󰂲"
                font.pixelSize: 16
                color: !root.btOn
                    ? Theme.iconMuted
                    : (root.connectedCount > 0
                        ? Theme.iconAccent
                        : Theme.iconMain)
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        // ── nome do primeiro device conectado ─────────────────────
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.btOn && root.connectedCount > 0
            text: (root.btPopupRef && root.btPopupRef.parsedDevices.filter(d => d.connected).length > 0)
                ? root.btPopupRef.parsedDevices.filter(d => d.connected)[0].name.split(" ")[0]
                : ""
            color: Theme.textDim
            font { pixelSize: 11; weight: Font.Medium }
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 80)
        }
    }

    // ── click ─────────────────────────────────────────────────────
    MouseArea {
        id: btArea
        anchors.fill:    parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: {
            if (root.btPopupRef)
                root.btPopupRef.shown = !root.btPopupRef.shown
        }
    }
}
