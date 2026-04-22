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
    backgroundColor: Theme.background
    borderColor: Theme.border

    Item {
        width: parent.width
        height: 24

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text:  root.ssid !== "" ? root.ssid : (root.netType === "wifi" ? "Wi-Fi" : "Ethernet")
            color: Theme.textActive
            opacity: 0.85
            width: parent.width - headerIcon.width - 8
            elide: Text.ElideRight
            font { pixelSize: Theme.fontSizeBody; weight: Font.DemiBold; letterSpacing: 0.3; family: Theme.fontFamily }
        }

        Text {
            id: headerIcon
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text:  root.netType === "wifi" ? "󰖩" : "󰈀"
            color: Theme.textDim
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeIcon }
        }
    }

    Row {
        width: parent.width
        spacing: 20

        Repeater {
            model: [
                { icon: "󰇚", label: "Download", value: root.downloadText },
                { icon: "󰕒", label: "Upload",   value: root.uploadText   }
            ]
            delegate: Row {
                spacing: 8
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
                        opacity: 0.85
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeBody; weight: Font.Medium }
                    }
                }
            }
        }
    }
}
