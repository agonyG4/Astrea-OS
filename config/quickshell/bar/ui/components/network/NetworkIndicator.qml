import QtQuick
import Quickshell.Io
import "../../.."

Item {
    id: root

    property bool   netConnected: false
    property string netType:      "none"
    property var    netPopupRef:  null

    property bool isActive: root.netPopupRef ? root.netPopupRef.shown : false

    width:  netRow.implicitWidth + 16
    height: 34

    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: Theme.radiusMedium - 2
        color: root.isActive ? Qt.rgba(1, 1, 1, 0.15) : (netArea.pressed ? Qt.rgba(1, 1, 1, 0.12) : (netHover.hovered ? Theme.separator : "transparent"))
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    HoverHandler {
        id: netHover
    }

    Row {
        id: netRow
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: !root.netConnected ? "󰖪"
                : root.netType === "wifi" ? "󰖩"
                : "󰈀"
            color: !root.netConnected
                ? Theme.iconWarning
                : Theme.iconMain
            font.pixelSize: 16
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    MouseArea {
        id: netArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: {
            if (root.netPopupRef) {
                if (root.netPopupRef.shown) {
                    root.netPopupRef.shown = false;
                } else {
                    root.netPopupRef.shown = true;
                }
            }
        }
    }
}
