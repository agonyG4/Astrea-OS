import QtQuick 2.15
import QtQuick.Controls 2.15
import "../.."

ToolButton {
    property bool   active:  false
    property string tooltip: ""

    font.pixelSize: 15
    width: 32; height: 32

    contentItem: Text {
        text: parent.text; font: parent.font
        color: !parent.enabled      ? Theme.textTer
             : parent.active        ? Theme.accent
             : parent.hovered       ? Theme.text
                                    : Theme.textSec
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment:   Text.AlignVCenter

        Behavior on color { ColorAnimation { duration: 80 } }
    }

    background: Rectangle {
        radius: 8
        color: parent.active   ? Qt.rgba(0.25, 0.55, 1.0, 0.18)
             : parent.hovered  ? Qt.rgba(1, 1, 1, 0.09)
                               : "transparent"
        Behavior on color { ColorAnimation { duration: 80 } }
    }

    ToolTip.text:    tooltip
    ToolTip.visible: tooltip !== "" && hovered
    ToolTip.delay:   500
}
