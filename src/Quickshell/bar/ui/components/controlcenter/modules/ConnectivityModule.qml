import QtQuick
import "../../../.."
import "../../../../../AstreaI18n" as AstreaI18n

Rectangle {
    id: module

    property var control: null

    radius: Theme.radiusLarge
    color: Theme.surface
    border.width: 1
    border.color: Theme.border

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacing
        spacing: Theme.spacingMicro

        ConnectivityRow {
            width: parent.width
            height: (parent.height - parent.spacing * 2) / 3
            icon: module.control && module.control.netConnected && module.control.netType !== "none"
                ? (module.control.netType === "wifi" ? "󰖩" : "󰈀")
                : "󰖪"
            title: module.control ? module.control.wifiTitle : "Wi-Fi"
            subtitle: module.control ? module.control.wifiSubtitle : AstreaI18n.I18n.tr("quickshell.bar.ui.components.controlcenter.status.disconnected", "Disconnected")
            active: module.control ? module.control.netConnected : false
            onClicked: if (module.control) module.control.toggleWifi()
        }

        ConnectivityRow {
            width: parent.width
            height: (parent.height - parent.spacing * 2) / 3
            icon: module.control && (module.control.btPowerPending || module.control.btScanning)
                ? "󰑐"
                : (module.control && module.control.btOn ? "󰂯" : "󰂲")
            title: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.controlcenter.modules.connectivity_module.title.bluetooth"]) || "Bluetooth")
            subtitle: module.control ? module.control.bluetoothSubtitle : AstreaI18n.I18n.tr("quickshell.bar.ui.components.controlcenter.status.off", "Off")
            active: module.control ? module.control.btOn : false
            busy: module.control ? (module.control.btPowerPending || module.control.btScanning) : false
            error: module.control ? module.control.btPowerError !== "" : false
            onClicked: if (module.control) module.control.toggleBluetooth()
        }

        ConnectivityRow {
            width: parent.width
            height: (parent.height - parent.spacing * 2) / 3
            icon: "󰀝"
            title: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.controlcenter.modules.connectivity_module.title.airdrop"]) || "AirDrop")
            subtitle: module.control && module.control.airdropOn
                ? AstreaI18n.I18n.tr("quickshell.bar.ui.components.controlcenter.status.active", "Active")
                : AstreaI18n.I18n.tr("quickshell.bar.ui.components.controlcenter.status.inactive", "Inactive")
            active: module.control ? module.control.airdropOn : false
            onClicked: if (module.control) module.control.airdropOn = !module.control.airdropOn
        }
    }
}
