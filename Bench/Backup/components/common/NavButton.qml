import QtQuick 2.15
import QtQuick.Controls 2.15
import "../.."

ToolButton {
    property bool   active:  false
    property string tooltip: ""

    font.pixelSize: 16
    width: 30; height: 30

    contentItem: Text {
        text: parent.text; font: parent.font
        color: !parent.enabled      ? Theme.textTer
             : parent.active        ? Theme.accent
             : parent.hovered       ? Theme.text
                                    : Theme.textSec
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment:   Text.AlignVCenter
    }

    background: Rectangle {
        radius: 6
        color: parent.active   ? Theme.accentLight
             : parent.hovered  ? Theme.hover
                               : "transparent"
    }

    ToolTip.text:    tooltip
    ToolTip.visible: tooltip !== "" && hovered
    ToolTip.delay:   600
}
