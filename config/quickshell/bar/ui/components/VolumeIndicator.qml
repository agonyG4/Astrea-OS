import QtQuick
import Quickshell.Io
import "../.."

Item {
    id: root

    property int  volLevel:    50
    property bool volMuted:    false
    property var  volPopupRef: null

    signal volChanged(int v)

    property bool isActive: root.volPopupRef ? root.volPopupRef.shown : false

    width:  volRow.implicitWidth + 16
    height: 34

    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: Theme.radiusMedium - 2 // proportional adjustment
        color: root.isActive ? Qt.rgba(1, 1, 1, 0.15) : (volArea.pressed ? Qt.rgba(1, 1, 1, 0.12) : (volHover.hovered ? Theme.separator : "transparent"))
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    HoverHandler {
        id: volHover
    }

    Row {
        id: volRow
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: root.volMuted      ? "󰝟"
                : root.volLevel < 34 ? "󰕿"
                : root.volLevel < 67 ? "󰖀"
                :                      "󰕾"
            color: root.volMuted
                ? Theme.iconMuted
                : Theme.iconMain
            font.pixelSize: 16
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    MouseArea {
        id: volArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: {
            if (root.volPopupRef) {
                if (root.volPopupRef.shown) {
                    root.volPopupRef.shown = false;
                } else {
                    root.volPopupRef.shown = true;
                }
            }
        }

        onWheel: e => {
            var d = e.angleDelta.y > 0 ? 2 : -2
            var v = Math.max(0, Math.min(100, root.volLevel + d))
            root.volChanged(v)
        }
    }
}
