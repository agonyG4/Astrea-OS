import QtQuick
import QtQuick.Layouts
import "../../AstreaComponents" as Astrea
import "../controls" as Control

Control.Card {
    id: panel
    property var backend
    property int playerLeds: 6
    property int ledBrightness: 1
    readonly property var playerLabels: ["off", "1", "2", "3", "4", "5", "all", "center"]
    readonly property var brightnessLabels: ["low", "medium", "high"]

    function restoreConfig() {
        if (!backend || !backend.config)
            return
        playerLeds = backend.config.player_leds === undefined ? playerLeds : backend.config.player_leds
        ledBrightness = backend.config.led_brightness === undefined ? ledBrightness : backend.config.led_brightness
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
        text: "Player LEDs"
    }

    Astrea.SettingRow {
        Layout.fillWidth: true
        label: "Pattern"
        sublabel: "Player indicator LEDs"
        Astrea.SelectButton {
            implicitWidth: 150
            label: panel.playerLabels[panel.playerLeds]
            options: panel.playerLabels
            selectedIndex: panel.playerLeds
            onSelected: index => {
                panel.playerLeds = index
                if (panel.backend)
                    panel.backend.saveConfig({ "player_leds": panel.playerLeds })
                if (panel.backend && panel.backend.ready)
                    panel.backend.applyAction("player-leds", ["--value", panel.playerLeds, "--instant"], false)
            }
        }
    }

    Astrea.SettingRow {
        Layout.fillWidth: true
        label: "Brightness"
        sublabel: "LED intensity"
        isLast: true
        Astrea.SelectButton {
            implicitWidth: 150
            label: panel.brightnessLabels[panel.ledBrightness]
            options: panel.brightnessLabels
            selectedIndex: panel.ledBrightness
            onSelected: index => {
                panel.ledBrightness = index
                if (panel.backend)
                    panel.backend.saveConfig({ "led_brightness": panel.ledBrightness })
                if (panel.backend && panel.backend.ready)
                    panel.backend.applyAction("led-brightness", ["--value", panel.ledBrightness], false)
            }
        }
    }
}
