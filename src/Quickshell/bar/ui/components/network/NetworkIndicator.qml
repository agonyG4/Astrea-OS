import QtQuick
import "../system" as SystemComponents
import "../../.."

SystemComponents.IndicatorButton {
    id: root

    property bool   netConnected: false
    property string netType:      "none"
    property var    netPopupRef:  null

    popupRef: root.netPopupRef

    Text {
        text: !root.netConnected ? "󰖪"
            : root.netType === "wifi" ? "󰖩"
            : "󰈀"
        color: !root.netConnected ? Theme.iconWarning : Theme.iconMain
        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeIcon }
        Behavior on color { ColorAnimation { duration: 150 } }
    }
}
