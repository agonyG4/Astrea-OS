import QtQuick
import "../system/base" as SystemComponents
import "../../.."

SystemComponents.TopbarIndicator {
    id: root

    property bool   netConnected: false
    property string netType:      "none"
    property string downloadText: "0 B/s"
    property string uploadText:   "0 B/s"

    Text {
        text: !root.netConnected ? "󰖪"
            : root.netType === "wifi" ? "󰖩"
            : "󰈀"
        color: !root.netConnected ? Theme.iconWarning : Theme.shellIconMain
        font { family: Theme.iconFontFamily; pixelSize: Theme.fontSizeIcon }
        Behavior on color { ColorAnimation { duration: Theme.animationFast } }
    }
}
