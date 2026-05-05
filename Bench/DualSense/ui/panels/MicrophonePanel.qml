import QtQuick
import QtQuick.Layouts
import "../../AstreaComponents" as Astrea
import "../controls" as Control

Control.Card {
    id: panel
    property var backend
    property string microphone: "on"
    property string microphoneLed: "on"
    property string microphoneMode: "headset"
    property string speaker: "on"
    property int volume: 160

    function restoreConfig() {
        if (!backend || !backend.config || !backend.config.audio)
            return
        var saved = backend.config.audio
        microphone = saved.microphone === undefined ? microphone : saved.microphone
        microphoneLed = saved.microphone_led === undefined ? microphoneLed : saved.microphone_led
        microphoneMode = saved.microphone_mode === undefined ? microphoneMode : saved.microphone_mode
        speaker = saved.speaker === undefined ? speaker : saved.speaker
        volume = saved.volume === undefined ? volume : saved.volume
    }

    function saveConfig() {
        if (!backend)
            return
        backend.saveConfig({
            "audio": {
                "microphone": microphone,
                "microphone_led": microphoneLed,
                "microphone_mode": microphoneMode,
                "speaker": speaker,
                "volume": volume
            }
        })
    }

    function indexOf(values, value) {
        for (var i = 0; i < values.length; i++) {
            if (values[i] === value)
                return i
        }
        return 0
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
        text: "Microphone and audio"
    }

    Astrea.SettingRow {
        Layout.fillWidth: true
        label: "Microphone"
        sublabel: "Controller capture"
        Astrea.SelectButton {
            implicitWidth: 130
            label: panel.microphone
            options: ["on", "off"]
            selectedIndex: panel.microphone === "on" ? 0 : 1
            onSelected: index => {
                panel.microphone = index === 0 ? "on" : "off"
                panel.saveConfig()
                if (panel.backend && panel.backend.ready)
                    panel.backend.applyAction("microphone", ["--state", panel.microphone], false)
            }
        }
    }

    Astrea.SettingRow {
        Layout.fillWidth: true
        label: "Mic LED"
        sublabel: "Orange mute light"
        Astrea.SelectButton {
            implicitWidth: 130
            label: panel.microphoneLed
            options: ["on", "off"]
            selectedIndex: panel.microphoneLed === "on" ? 0 : 1
            onSelected: index => {
                panel.microphoneLed = index === 0 ? "on" : "off"
                panel.saveConfig()
                if (panel.backend && panel.backend.ready)
                    panel.backend.applyAction("microphone-led", ["--state", panel.microphoneLed], false)
            }
        }
    }

    Astrea.SettingRow {
        Layout.fillWidth: true
        label: "Mic mode"
        sublabel: "Input route"
        Astrea.SelectButton {
            implicitWidth: 150
            label: panel.microphoneMode
            options: ["headset", "speaker", "both"]
            selectedIndex: panel.indexOf(["headset", "speaker", "both"], panel.microphoneMode)
            onSelected: index => {
                panel.microphoneMode = ["headset", "speaker", "both"][index]
                panel.saveConfig()
                if (panel.backend && panel.backend.ready)
                    panel.backend.applyAction("microphone-mode", ["--state", panel.microphoneMode], false)
            }
        }
    }

    Astrea.SettingRow {
        Layout.fillWidth: true
        label: "Speaker"
        sublabel: "Controller speaker"
        Astrea.SelectButton {
            implicitWidth: 130
            label: panel.speaker
            options: ["on", "off"]
            selectedIndex: panel.speaker === "on" ? 0 : 1
            onSelected: index => {
                panel.speaker = index === 0 ? "on" : "off"
                panel.saveConfig()
                if (panel.backend && panel.backend.ready)
                    panel.backend.applyAction("speaker", ["--state", panel.speaker], false)
            }
        }
    }

    Control.ValueSlider {
        Layout.fillWidth: true
        label: "Volume"
        value: panel.volume
        onEdited: value => { panel.volume = value; panel.saveConfig() }
    }

    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        Control.PrimaryButton {
            text: "Apply"
            enabledState: panel.backend && panel.backend.ready && !panel.backend.applying
            onClicked: panel.backend.applyAction("volume", ["--value", panel.volume], false)
        }
    }
}
