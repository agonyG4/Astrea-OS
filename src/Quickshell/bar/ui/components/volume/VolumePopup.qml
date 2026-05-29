import Quickshell
import Quickshell.Io
import QtQuick
import "../system/popups" as SystemComponents
import "../../.."
import "../../../../AstreaI18n" as AstreaI18n

SystemComponents.TopbarPopup {
    id: root

    property int    masterVol:   50
    property bool   masterMuted: false
    property string deviceName:  (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.volume.volume"]) || "Volume"
    property bool   spatialOn:   false
    property real   lastDeviceInfoRefresh: 0

    signal volumeChangeHandled(int v)

    popupWidth: 300
    readonly property string audioScript: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Core/bridge/system/audio.py"
    readonly property int deviceInfoRefreshMs: 30000

    function volIcon(v, m) {
        if (m || v === 0) return "󰝟"
        if (v < 34)       return "󰕿"
        if (v < 67)       return "󰖀"
        return "󰕾"
    }

    function refresh() {
        volReadProc.running = false
        volReadProc.running = true
        const now = Date.now()
        if (now - lastDeviceInfoRefresh > deviceInfoRefreshMs) {
            lastDeviceInfoRefresh = now
            deviceProc.running = false
            deviceProc.running = true
        }
    }

    onShownChanged: {
        if (shown) {
            refresh()
        }
    }

    // ─── Processes ────────────────────────────────────────────────
    Process {
        id: volReadProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.masterMuted = data.indexOf("[MUTED]") !== -1
                var m = data.match(/[\d.]+/)
                if (m) root.masterVol = Math.round(parseFloat(m[0]) * 100)
            }
        }
    }

    Process {
        id: deviceProc
        command: ["python3", root.audioScript, "info"]
        running: false
        stdout: StdioCollector { id: deviceInfoOut }
        onExited: (code) => {
            if (code !== 0) return
            try {
                var info = JSON.parse(deviceInfoOut.text || "{}")
                var spatial = info.spatial || {}
                var outputs = info.outputs || []
                root.spatialOn = spatial.enabled === true
                var current = null
                for (var i = 0; i < outputs.length; i++) {
                    if (outputs[i].effective_default === true) {
                        current = outputs[i]
                        break
                    }
                }
                if (!current && outputs.length > 0)
                    current = outputs[0]
                if (current)
                    root.deviceName = current.description || current.name || ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.volume.volume"]) || "Volume")
            } catch (error) {
            }
        }
    }

    Process {
        id: volSetProc
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "50%"]
        running: false
    }

    Process {
        id: volMuteProc
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        running: false
        onRunningChanged: { if (!running) root.refresh() }
    }

    SystemComponents.PopupHeader {
        title: root.spatialOn ? root.deviceName + ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.volume.spatial_audio_suffix"]) || " · Spatial Audio") : root.deviceName
        trailingWidth: 28
        trailingHeight: 28
        Rectangle {
            id: mutePill
            anchors.centerIn: parent
            width: 28; height: 28; radius: Theme.cornerRadiusLarge

            color: root.masterMuted
                ? Qt.rgba(1, 0.23, 0.19, 0.25)
                : (muteArea.containsMouse ? Theme.shellSeparator : Qt.rgba(1, 1, 1, 0.07))

            border.width: 1
            border.color: root.masterMuted
                ? Qt.rgba(1, 0.23, 0.19, 0.40)
                : Qt.rgba(1, 1, 1, 0.08)

            Behavior on color        { ColorAnimation { duration: Theme.animationFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.animationFast } }

            Text {
                anchors.centerIn: parent
                text:  root.volIcon(root.masterVol, root.masterMuted)
                color: root.masterMuted ? Theme.iconWarning : Theme.shellIconMain
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeBody }
                Behavior on color { ColorAnimation { duration: Theme.animationFast } }
            }

            MouseArea {
                id: muteArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                onClicked:    volMuteProc.running = true
            }
        }
    }

    Row {
        width:   parent.width
        spacing: Theme.spacingMedium

        Text {
            text:  "󰕿"
            color: Qt.rgba(1, 1, 1, 0.30)
            font { family: Theme.iconFontFamily; pixelSize: Theme.fontSizeTitle }
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            width:  parent.width - 14 - 14 - 20
            height: 30
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 5; radius: 3
                color: Qt.rgba(1, 1, 1, 0.10)

                Rectangle {
                    width: Math.max(radius * 2, track.width * (root.masterVol / 100))
                    height: parent.height
                    radius: parent.radius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.masterMuted ? Qt.rgba(1,1,1,0.15) : Qt.rgba(1,1,1,0.45) }
                        GradientStop { position: 1.0; color: root.masterMuted ? Qt.rgba(1,1,1,0.20) : Qt.rgba(1,1,1,0.90) }
                    }
                    Behavior on width { NumberAnimation { duration: Theme.animationSlider; easing.type: Easing.OutCubic } }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(
                       track.width - width,
                       track.width * (root.masterVol / 100) - width / 2))
                width:  sliderMouse.pressed ? 22 : (sliderMouse.containsMouse ? 20 : 16)
                height: width
                radius: width / 2
                color:  "white"

                Behavior on width { NumberAnimation { duration: Theme.animationMicro; easing.type: Easing.OutCubic } }
                Behavior on x     {
                    enabled: !sliderMouse.pressed
                    NumberAnimation { duration: Theme.animationSlider; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.15)
                }
            }

            MouseArea {
                id: sliderMouse
                anchors.fill: parent
                anchors.topMargin:    -10
                anchors.bottomMargin: -10
                hoverEnabled:    true
                preventStealing: true
                cursorShape:     Qt.PointingHandCursor

                function applyVol(v) {
                    v = Math.round(Math.max(0, Math.min(100, v)))
                    if (v === root.masterVol) return
                    root.masterVol = v
                    volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v + "%"]
                    volSetProc.running = false
                    volSetProc.running = true
                    root.volumeChangeHandled(v)
                }

                onPressed:         e => applyVol(Math.round(Math.max(0, Math.min(track.width, e.x)) / track.width * 100))
                onPositionChanged: e => { if (pressed) applyVol(Math.round(Math.max(0, Math.min(track.width, e.x)) / track.width * 100)) }
                onWheel:           e => applyVol(root.masterVol + (e.angleDelta.y > 0 ? 2 : -2))
            }
        }

        Text {
            text:  "󰕾"
            color: Qt.rgba(1, 1, 1, 0.30)
            font { family: Theme.iconFontFamily; pixelSize: Theme.fontSizeTitle }
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
