import QtQuick
import Quickshell.Io
import "../../.."

Item {
    id: root

    property bool btOn:          false
    property var  btPopupRef:    null

    // ── propriedades derivadas ────────────────────────────────────
    readonly property bool btPopupValid:    root.btPopupRef !== null
    readonly property bool isActive:        btPopupValid && root.btPopupRef.shown
    readonly property bool isScanning:      btPopupValid && root.btPopupRef.scanning
    readonly property var  connectedDevices: btPopupValid
        ? root.btPopupRef.parsedDevices.filter(d => d.connected)
        : []
    readonly property int  connectedCount:  connectedDevices.length
    readonly property string firstDeviceName: connectedCount > 0
        ? connectedDevices[0].name.split(" ")[0]
        : ""

    width:  btRow.implicitWidth + 16
    height: 34

    function updatePopupAnchor() {
        if (!root.btPopupRef) return
        const point = root.mapToItem(null, root.width / 2, root.height / 2)
        root.btPopupRef.anchorX = point.x
    }

    onXChanged: updatePopupAnchor()
    onWidthChanged: updatePopupAnchor()
    onBtPopupRefChanged: updatePopupAnchor()
    Component.onCompleted: updatePopupAnchor()

    // ── background ────────────────────────────────────────────────
    Rectangle {
        anchors { fill: parent; margins: 3 }
        radius: Theme.radiusMedium - 2
        color: root.isActive       ? Qt.rgba(1, 1, 1, 0.15) :
               btArea.pressed      ? Qt.rgba(1, 1, 1, 0.12) :
               btHover.hovered     ? Theme.separator        : "transparent"
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

            Rectangle {
                id: scanPulse
                anchors.centerIn: parent
                width: 18; height: 18; radius: 9
                color:        "transparent"
                border.width: 1.5
                border.color: Qt.rgba(0.35, 0.65, 1, 0.7)
                visible:      root.isScanning

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
                anchors.centerIn: parent
                text:  root.btOn ? "󰂯" : "󰂲"
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeIcon }
                color: !root.btOn          ? Theme.iconMuted  :
                       root.connectedCount > 0 ? Theme.iconAccent : Theme.iconMain
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        // ── nome do primeiro device conectado ─────────────────────
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.btOn && root.connectedCount > 0
            text:    root.firstDeviceName
            color:   Theme.textDim
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeCaption; weight: Font.Medium }
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
            if (!root.btPopupRef) return
            const point = root.mapToItem(null, root.width / 2, root.height / 2)
            root.btPopupRef.toggleAt(point.x)
        }
    }
}
