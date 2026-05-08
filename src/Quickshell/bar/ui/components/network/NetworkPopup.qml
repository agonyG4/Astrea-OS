import Quickshell
import QtQuick
import "../system" as SystemComponents
import "../../.."

SystemComponents.TopbarPopup {
    id: root

    property string netType:      "none"
    property string ssid:         ""
    property string downloadText: "0 B/s"
    property string uploadText:   "0 B/s"

    popupWidth: 280

    SystemComponents.PopupHeader {
        title: root.ssid !== "" ? root.ssid : (root.netType === "wifi" ? "Wi-Fi" : "Ethernet")
        icon: root.netType === "wifi" ? "󰖩" : "󰈀"
    }

    Row {
        width: parent.width
        spacing: Theme.spacingXXLarge

        Repeater {
            model: [
                { icon: "󰇚", label: "Download", value: root.downloadText },
                { icon: "󰕒", label: "Upload",   value: root.uploadText   }
            ]
            delegate: Row {
                spacing: Theme.spacing
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text:  modelData.icon
                    color: Qt.rgba(1, 1, 1, 0.40)
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeIconLarge }
                }
                Column {
                    Text { text: modelData.label; color: Theme.textSecondary; font { family: Theme.fontFamily; pixelSize: Theme.fontSizeExtraSmall } }
                    Text {
                        text:    modelData.value
                        color:   Theme.textActive
                        opacity: Theme.opacitySecondary
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeBody; weight: Font.Medium }
                    }
                }
            }
        }
    }
}
