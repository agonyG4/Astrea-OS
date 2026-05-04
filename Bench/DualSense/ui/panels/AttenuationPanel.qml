import QtQuick
import QtQuick.Layouts
import "../../AstreaComponents" as Astrea
import "../controls" as Control

Control.Card {
    id: panel
    property var backend
    property int rumble: 0
    property int trigger: 0

    function restoreConfig() {
        if (!backend || !backend.config || !backend.config.attenuation)
            return
        rumble = backend.config.attenuation.rumble === undefined ? rumble : backend.config.attenuation.rumble
        trigger = backend.config.attenuation.trigger === undefined ? trigger : backend.config.attenuation.trigger
    }

    function saveConfig() {
        if (backend)
            backend.saveConfig({ "attenuation": { "rumble": rumble, "trigger": trigger } })
    }

    Component.onCompleted: restoreConfig()

    Connections {
        target: panel.backend
        function onConfigLoaded() {
            panel.restoreConfig()
        }
    }

    Astrea.SectionHeader {
        Layout.fillWidth: true
        text: "Rumble and trigger attenuation"
    }

    Control.ValueSlider { Layout.fillWidth: true; label: "Rumble"; from: 0; to: 7; value: panel.rumble; onEdited: value => { panel.rumble = value; panel.saveConfig() } }
    Control.ValueSlider { Layout.fillWidth: true; label: "Trigger"; from: 0; to: 7; value: panel.trigger; onEdited: value => { panel.trigger = value; panel.saveConfig() } }

    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        Control.PrimaryButton {
            text: "Apply"
            enabledState: panel.backend && panel.backend.ready && !panel.backend.applying
            onClicked: panel.backend.applyAction("attenuation", ["--rumble", panel.rumble, "--trigger", panel.trigger], false)
        }
    }
}
