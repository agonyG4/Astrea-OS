import Quickshell
import Quickshell.Io
import QtQuick
import "../system" as SystemComponents
import "../../.."

SystemComponents.TopbarPopup {
    id: root

    property int    masterVol:   50
    property bool   masterMuted: false
    property string deviceName:  "Volume"

    signal volumeChangeHandled(int v)

    popupWidth: 300
    backgroundColor: Theme.background
    borderColor: Theme.border

    function volIcon(v, m) {
        if (m || v === 0) return "󰝟"
        if (v < 34)       return "󰕿"
        if (v < 67)       return "󰖀"
        return "󰕾"
    }

    function refresh() {
        volReadProc.running = false
        volReadProc.running = true
        deviceProc.running  = false
        deviceProc.running  = true
    }

    onShownChanged: {
        if (shown) {
            refresh()
        }
    }

    // ─── Processes ────────────────────────────────────────────────
    Process {
        id: volReadProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
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
        command: ["bash", "-c", "wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep 'node.nick\\|node.description\\|device.description' | head -1 | sed 's/.*= \"//;s/\".*//;s/^ *//'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var name = data.trim()
                if (name !== "") root.deviceName = name
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

    Item {
        width: parent.width
        height: 24

        Text {
            anchors.left:           parent.left
            anchors.verticalCenter: parent.verticalCenter
            text:  root.deviceName
            color: Theme.textActive
            opacity: 0.85
            font {
                family:        Theme.fontFamily
                pixelSize:     Theme.fontSizeBody
                weight:        Font.DemiBold
                letterSpacing: 0.3
            }
            elide: Text.ElideRight
            width: parent.width - mutePill.width - 8
        }

        Rectangle {
            id: mutePill
            anchors.right:          parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 28; height: 28; radius: 14

            color: root.masterMuted
                ? Qt.rgba(1, 0.23, 0.19, 0.25)
                : (muteArea.containsMouse ? Theme.separator : Qt.rgba(1, 1, 1, 0.07))

            border.width: 1
            border.color: root.masterMuted
                ? Qt.rgba(1, 0.23, 0.19, 0.40)
                : Qt.rgba(1, 1, 1, 0.08)

            Behavior on color        { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text:  root.volIcon(root.masterVol, root.masterMuted)
                color: root.masterMuted ? Theme.iconWarning : Theme.iconMain
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeBody }
                Behavior on color { ColorAnimation { duration: 150 } }
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
        spacing: 10

        Text {
            text:  "󰕿"
            color: Qt.rgba(1, 1, 1, 0.30)
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeTitle }
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
                    Behavior on width { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } }
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

                Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                Behavior on x     {
                    enabled: !sliderMouse.pressed
                    NumberAnimation { duration: 60; easing.type: Easing.OutCubic }
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
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeTitle }
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
