import QtQuick
import QtQuick.Layouts
import "../../AstreaComponents" as Astrea
import "../controls" as Control

Control.Card {
    id: panel
    property var backend

    function indexOfDevice() {
        if (!backend)
            return -1
        for (var i = 0; i < backend.devices.length; i++) {
            if (backend.devices[i] === backend.device)
                return i
        }
        return -1
    }

    Astrea.SectionHeader {
        Layout.fillWidth: true
        text: "Device"
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Astrea.StatusDot {
            active: backend && backend.ready
        }
        Text {
            Layout.fillWidth: true
            text: !backend ? "Unavailable" : (backend.ready ? "Connected" : (backend.installed ? backend.message : "dualsensectl missing"))
            color: Astrea.Theme.textPrimary
            font.family: Astrea.Theme.fontFamily
            font.pixelSize: Astrea.Theme.fontSizeNormal
            font.weight: Font.Medium
        }
    }

    Text {
        Layout.fillWidth: true
        visible: backend && backend.battery !== ""
        text: backend ? backend.battery : ""
        color: Astrea.Theme.textSecondary
        font.family: Astrea.Theme.fontFamily
        font.pixelSize: Astrea.Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    Astrea.SelectButton {
        Layout.fillWidth: true
        label: backend && backend.device !== "" ? backend.device : "No devices"
        options: backend && backend.devices.length ? backend.devices : ["No devices"]
        selectedIndex: panel.indexOfDevice()
        onSelected: index => {
            if (backend && backend.devices.length && index >= 0) {
                backend.device = backend.devices[index]
                backend.refresh()
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Control.PrimaryButton {
            text: "Refresh"
            enabledState: backend && !backend.loading
            onClicked: backend.refresh()
        }
        Control.PrimaryButton {
            text: "Power off"
            enabledState: backend && backend.ready && !backend.applying
            onClicked: backend.applyAction("power-off", [])
        }
    }
}
