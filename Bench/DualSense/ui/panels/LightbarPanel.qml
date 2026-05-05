import QtQuick
import QtQuick.Layouts
import "../../AstreaComponents" as Astrea
import "../controls" as Control

Control.Card {
    id: panel
    property var backend
    property int red: 0
    property int green: 122
    property int blue: 255
    property int brightness: 180
    property string state: "on"

    function restoreConfig() {
        if (!backend || !backend.config || !backend.config.lightbar)
            return
        var saved = backend.config.lightbar
        red = saved.red === undefined ? red : saved.red
        green = saved.green === undefined ? green : saved.green
        blue = saved.blue === undefined ? blue : saved.blue
        brightness = saved.brightness === undefined ? brightness : saved.brightness
        state = saved.state === undefined ? state : saved.state
    }

    function saveLightbarConfig() {
        if (!backend)
            return
        backend.saveConfig({
            "lightbar": {
                "red": red,
                "green": green,
                "blue": blue,
                "brightness": brightness,
                "state": state
            }
        })
    }

    function applyColor() {
        saveLightbarConfig()
        if (backend && backend.ready)
            backend.applyLiveAction("lightbar", ["--red", red, "--green", green, "--blue", blue, "--brightness", brightness])
    }

    function queueColorApply() {
        colorApplyTimer.restart()
    }

    Timer {
        id: colorApplyTimer
        interval: 0
        repeat: false
        onTriggered: panel.applyColor()
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
        text: "Lightbar"
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            radius: 8
            color: Qt.rgba(red / 255, green / 255, blue / 255, Math.max(0.24, brightness / 255))
            border.width: 1
            border.color: Astrea.Theme.cardBorder
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Control.ValueSlider { Layout.fillWidth: true; label: "Red"; value: panel.red; onEdited: value => { panel.red = value; panel.queueColorApply() } }
            Control.ValueSlider { Layout.fillWidth: true; label: "Green"; value: panel.green; onEdited: value => { panel.green = value; panel.queueColorApply() } }
            Control.ValueSlider { Layout.fillWidth: true; label: "Blue"; value: panel.blue; onEdited: value => { panel.blue = value; panel.queueColorApply() } }
            Control.ValueSlider { Layout.fillWidth: true; label: "Brightness"; value: panel.brightness; onEdited: value => { panel.brightness = value; panel.queueColorApply() } }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Control.SegmentedButton {
            Layout.fillWidth: true
            options: ["on", "off"]
            value: panel.state
            onSelected: value => {
                panel.state = value
                panel.saveLightbarConfig()
                if (panel.backend && panel.backend.ready)
                    panel.backend.applyLiveAction("lightbar-state", ["--state", value])
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            text: panel.backend && panel.backend.ready ? "Live color" : "Connect controller"
            color: Astrea.Theme.textSecondary
            font.family: Astrea.Theme.fontFamily
            font.pixelSize: Astrea.Theme.fontSizeSmall
        }
    }
}
