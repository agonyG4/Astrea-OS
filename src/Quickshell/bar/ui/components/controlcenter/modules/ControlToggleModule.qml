import QtQuick
import "../../../.."

ControlTile {
    id: module

    property var control: null
    property string moduleKind: ""
    property string moduleSize: "small"
    property string moduleGroup: ""

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
            return "Bluetooth"
        if (moduleKind === "airdrop")
            return "AirDrop"
        if (moduleKind === "focus")
            return "Foco"
        if (moduleKind === "mirror")
            return "Espelhar"
        return moduleKind
    }

    subtitle: {
        if (moduleKind === "wifi")
            return control ? control.wifiSubtitle : "Desconectado"
        if (moduleKind === "bluetooth")
            return control ? control.bluetoothSubtitle : "Desligado"
        if (moduleKind === "airdrop")
            return control && control.airdropOn ? "Ativo" : "Desativado"
        if (moduleKind === "focus")
            return control && control.focusOn ? "Ativo" : "Desativado"
        if (moduleKind === "mirror")
            return "Tela"
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
