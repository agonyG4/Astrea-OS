import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import "../../.."

PanelWindow {
    id: root

    property bool shown: false
    property real anchorX: screen.width - 60 // fallback
    property int  brightness: 100

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

    Timer {
        id: openDelay
        interval: 150
        onTriggered: {
            brightReadProc.running = false
            brightReadProc.running = true
        }
    }

    onShownChanged: {
        if (shown) {
            appearAnim.start()
            // Espera a animação rodar para evitar que o lag do ddcutil congele a janela
            openDelay.start()
        }
    }

    // ─── Fundo: clique fora fecha ─────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: root.shown = false
        z: 0
    }

    // ─── Processos auxiliares ──────────────────────────────
    Process {
        id: brightSetProc
        command: []
        running: false
        property bool updatePending: false
        property int pendingVal: 50
        onRunningChanged: {
            if (!running && updatePending) {
                updatePending = false
                command = ["ddcutil", "--bus", "3", "setvcp", "10", pendingVal.toString(), "--noverify", "--sleep-multiplier=0.05"]
                running = true
            }
        }
    }

    Process {
        id: brightReadProc
        command: ["ddcutil", "--bus", "3", "getvcp", "10", "--terse"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                // Return example: "VCP 10 C 50 100"
                const parts = data.trim().split(" ")
                if (parts.length >= 4) {
                    root.brightness = parseInt(parts[3])
                }
            }
        }
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
            Text {
                text:  "Central de Controle"
                color: Theme.textActive
                font {
                    pixelSize:     Theme.fontSizeTitle
                    weight:        Font.DemiBold
                    letterSpacing: 0.3
                }
            }

            // ── Conteúdo da Central ────────────────────────────
            Column {
                width: parent.width
                spacing: 12
                
                // ── Brilho ─────────────────────────────────────────
                Item {
                    width: parent.width
                    height: 48
                    
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusMedium
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: Theme.border
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12
                        
                        Text {
                            text: "󰃠" // Icon for brightness
                            color: Theme.iconMain
                            font.pixelSize: 18
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            width:  parent.width - 30
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                id: brightTrack
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 6; radius: 3
                                color: Qt.rgba(0, 0, 0, 0.4)

                                Rectangle {
                                    width: Math.max(radius * 2, brightTrack.width * (root.brightness / 100))
                                    height: parent.height
                                    radius: parent.radius
                                    color: Theme.iconActive
                                    Behavior on width { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } }
                                }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.max(0, Math.min(
                                       brightTrack.width - width,
                                       brightTrack.width * (root.brightness / 100) - width / 2))
                                width:  brightMouse.pressed ? 20 : (brightMouse.containsMouse ? 18 : 14)
                                height: width
                                radius: width / 2
                                color:  "white"

                                Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                                Behavior on x     {
                                    enabled: !brightMouse.pressed
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
                                id: brightMouse
                                anchors.fill: parent
                                anchors.topMargin:    -10
                                anchors.bottomMargin: -10
                                hoverEnabled:    true
                                preventStealing: true
                                cursorShape:     Qt.PointingHandCursor

                                function applyBright(v) {
                                    v = Math.round(Math.max(0, Math.min(100, v)))
                                    if (v === root.brightness) return
                                    root.brightness = v
                                    
                                    if (!brightSetProc.running) {
                                        brightSetProc.command = ["ddcutil", "--bus", "3", "setvcp", "10", v.toString(), "--noverify", "--sleep-multiplier=0.05"]
                                        brightSetProc.running = true
                                    } else {
                                        brightSetProc.pendingVal = v
                                        brightSetProc.updatePending = true
                                    }
                                }

                                onPressed:         e => applyBright(Math.round(Math.max(0, Math.min(brightTrack.width, e.x)) / brightTrack.width * 100))
                                onPositionChanged: e => { if (pressed) applyBright(Math.round(Math.max(0, Math.min(brightTrack.width, e.x)) / brightTrack.width * 100)) }
                                onWheel:           e => applyBright(root.brightness + (e.angleDelta.y > 0 ? 5 : -5))
                            }
                        }
                    }
                }
            }
        }
    }
}
