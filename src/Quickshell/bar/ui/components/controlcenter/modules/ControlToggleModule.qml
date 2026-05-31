import QtQuick
import "../../../.."
import "../../../../../AstreaI18n" as AstreaI18n

ControlTile {
    id: module

    property var control: null
    property string moduleKind: ""
    property string moduleSize: "small"
    property string moduleGroup: ""

    function t(key, fallback, params) {
        return AstreaI18n.I18n.tr(key, fallback, params)
    }

    icon: {
        if (moduleKind === "wifi")
            return control && control.netConnected && control.netType !== "none"
                ? (control.netType === "wifi" ? "󰖩" : "󰈀")
                : "󰖪"
        if (moduleKind === "bluetooth")
            return control && (control.btPowerPending || control.btScanning) ? "󰑐" : (control && control.btOn ? "󰂯" : "󰂲")
        if (moduleKind === "airdrop")
            return "󰀝"
        if (moduleKind === "focus")
            return "󰘶"
        if (moduleKind === "mirror")
            return "󰍺"
        return "󰕰"
    }

    title: {
        if (moduleKind === "wifi")
            return control ? control.wifiTitle : "Wi-Fi"
        if (moduleKind === "bluetooth")
            return t("quickshell.bar.ui.components.controlcenter.module.bluetooth", "Bluetooth")
        if (moduleKind === "airdrop")
            return t("quickshell.bar.ui.components.controlcenter.module.airdrop", "AirDrop")
        if (moduleKind === "focus")
            return t("quickshell.bar.ui.components.controlcenter.module.focus", "Focus")
        if (moduleKind === "mirror")
            return t("quickshell.bar.ui.components.controlcenter.module.mirror", "Mirror")
        return moduleKind
    }

    subtitle: {
        if (moduleKind === "wifi")
            return control ? control.wifiSubtitle : t("quickshell.bar.ui.components.controlcenter.status.disconnected", "Disconnected")
        if (moduleKind === "bluetooth")
            return control ? control.bluetoothSubtitle : t("quickshell.bar.ui.components.controlcenter.status.off", "Off")
        if (moduleKind === "airdrop")
            return control && control.airdropOn
                ? t("quickshell.bar.ui.components.controlcenter.status.active", "Active")
                : t("quickshell.bar.ui.components.controlcenter.status.inactive", "Inactive")
        if (moduleKind === "focus")
            return control && control.focusOn
                ? t("quickshell.bar.ui.components.controlcenter.status.active", "Active")
                : t("quickshell.bar.ui.components.controlcenter.status.inactive", "Inactive")
        if (moduleKind === "mirror")
            return t("quickshell.bar.ui.components.controlcenter.module.display", "Display")
        return ""
    }

    active: {
        if (moduleKind === "wifi")
            return control ? control.netConnected : false
        if (moduleKind === "bluetooth")
            return control ? control.btOn : false
        if (moduleKind === "airdrop")
            return control ? control.airdropOn : false
        if (moduleKind === "focus")
            return control ? control.focusOn : false
        return false
    }

    busy: moduleKind === "bluetooth" && control ? (control.btPowerPending || control.btScanning) : false
    error: moduleKind === "bluetooth" && control ? control.btPowerError !== "" : false

    onClicked: {
        if (!control)
            return

        if (moduleKind === "wifi")
            control.toggleWifi()
        else if (moduleKind === "bluetooth")
            control.toggleBluetooth()
        else if (moduleKind === "airdrop")
            control.airdropOn = !control.airdropOn
        else if (moduleKind === "focus")
            control.focusOn = !control.focusOn
    }
}
