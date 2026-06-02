import Quickshell
import QtQuick
import "../system/popups" as SystemComponents
import "../../.."
import "../../../../AstreaI18n" as AstreaI18n

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
                { icon: "󰇚", label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.network.network_popup.label.download"]) || "Download"), value: root.downloadText },
                { icon: "󰕒", label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.network.network_popup.label.upload"]) || "Upload"),   value: root.uploadText   }
            ]
            delegate: Row {
                spacing: Theme.spacing
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text:  modelData.icon
                    color: Qt.rgba(1, 1, 1, 0.40)
                    font { family: Theme.iconFontFamily; pixelSize: Theme.fontSizeIconLarge }
                }
                Column {
                    Text { text: modelData.label; color: Theme.shellTextSecondary; font { family: Theme.fontFamily; pixelSize: Theme.fontSizeExtraSmall } }
                    Text {
                        text:    modelData.value
                        color:   Theme.shellTextActive
                        opacity: Theme.opacitySecondary
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeBody; weight: Font.Medium }
                    }
                }
            }
        }
    }
}
