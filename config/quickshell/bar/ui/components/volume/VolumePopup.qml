import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import "../../.."

PanelWindow {
    id: root

    property bool   shown:       false
    property int    masterVol:   50
    property bool   masterMuted: false
    property string deviceName:  "Volume"
    property real   anchorX:     screen.width - 158  // fallback: below volume icon

    signal volumeChangeHandled(int v)

    color: "transparent"

    anchors.top:    true
    anchors.bottom: true
    anchors.left:   true
    anchors.right:  true

    WlrLayershell.namespace:     "topbar-popup"
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    visible: root.shown

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
            appearAnim.start()
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

    // ─── Fundo: clique fora fecha ─────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: root.shown = false
        z: 0
    }

    // ─── Card ─────────────────────────────────────────────────────
    Item {
        id: card
        anchors.top:       parent.top
        anchors.topMargin: 54
        x:      Math.max(8, Math.min(parent.width - width - 8, root.anchorX - width / 2))
        width:  300
        height: cardBg.height
        z: 1

        opacity: 0
        SequentialAnimation {
            id: appearAnim
            NumberAnimation {
                target: card
                property: "opacity"
                from: 0; to: 1
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onDoubleClicked: {}
        }

        // ─── Glass background ──────────────────────────────────
        Rectangle {
            id: cardBg
            width:  parent.width
            height: innerCol.implicitHeight + 36
            radius: Theme.radiusLarge
            color:  "transparent"

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.background
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Theme.border
            }


            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled:          true
                shadowColor:            Qt.rgba(0, 0, 0, 0.5)
                shadowBlur:             0.9
                shadowVerticalOffset:   6
                shadowHorizontalOffset: 0
            }
        }

        // ─── Conteúdo ──────────────────────────────────────────
        Column {
            id: innerCol
            anchors {
                top:    cardBg.top
                left:   cardBg.left
                right:  cardBg.right
                margins:   18
                topMargin: 18
            }
            spacing: 14

            // ── Header ─────────────────────────────────────────
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
                        font.pixelSize: Theme.fontSizeBody
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

            // ── Slider ─────────────────────────────────────────
            Row {
                width:   parent.width
                spacing: 10

                Text {
                    text:  "󰕿"
                    color: Qt.rgba(1, 1, 1, 0.30)
                    font.pixelSize: 14
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
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
