import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Effects
import Quickshell

FloatingWindow {
    title: "RainTest"
    implicitWidth: 450
    implicitHeight: 700
    visible: true

    // ── fundo ──────────────────────────────────────────────────────────
    Item {
        id: background
        anchors.fill: parent

        Rectangle { anchors.fill: parent; color: "#1a2a3a" }

        Rectangle {
            width: 320; height: 320; radius: 160
            x: -60; y: 80
            color: "#3a6ea8"; opacity: 0.5
        }
        Rectangle {
            width: 260; height: 260; radius: 130
            x: 220; y: 280
            color: "#7b3fa0"; opacity: 0.4
        }
        Rectangle {
            width: 200; height: 200; radius: 100
            x: 60; y: 480
            color: "#1a6e8a"; opacity: 0.45
        }
        Rectangle {
            width: 180; height: 180; radius: 90
            x: 280; y: 60
            color: "#a03f5a"; opacity: 0.3
        }
    }

    // ── fios de chuva ao fundo ─────────────────────────────────────────
    Repeater {
        model: 80
        delegate: Rectangle {
            property real rnd: Math.random()
            width: 1
            height: 10 + rnd * 18
            radius: 1
            color: Qt.rgba(1, 1, 1, 0.06 + rnd * 0.08)
            x: Math.random() * 450
            y: -20
            NumberAnimation on y {
                from: -20; to: 720
                duration: 350 + Math.random() * 500
                loops: Animation.Infinite; running: true
            }
            NumberAnimation on x {
                from: x; to: x + 25
                duration: 350 + Math.random() * 500
                loops: Animation.Infinite; running: true
            }
        }
    }

    // ── gotas no vidro com blur real atrás ────────────────────────────
    Repeater {
        model: 45
        delegate: Item {
            id: drop
            property real sz:      10 + Math.random() * 24
            property real originX: Math.random() * 410
            property real originY: Math.random() * 520
            property real spd:     2000 + Math.random() * 3500

            x: originX
            y: originY
            z: 10

            // captura o fundo atrás da gota
            ShaderEffectSource {
                id: src
                width:  drop.sz + 4
                height: drop.sz * 1.5
                sourceItem: background
                sourceRect: Qt.rect(drop.x, drop.y, width, height)
                visible: false
            }

            // blur no conteudo atrás da gota
            MultiEffect {
                width:  drop.sz + 4
                height: drop.sz * 1.5
                source: src
                autoPaddingEnabled: false
                blurEnabled: true
                blurMax: 16
                blur: 0.8
                brightness: 0.12
                saturation: 0.2

                layer.enabled: true
                layer.effect: null

                // mascara oval para a gota
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    visible: false
                }
            }

            // corpo da gota por cima
            Rectangle {
                width:  drop.sz
                height: drop.sz * 1.4
                radius: drop.sz / 2
                color:  Qt.rgba(1, 1, 1, 0.1)
                border.color: Qt.rgba(1, 1, 1, 0.35)
                border.width: 0.8

                Rectangle {
                    width: parent.width * 0.28
                    height: parent.height * 0.22
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, 0.6)
                    x: parent.width * 0.18
                    y: parent.height * 0.12
                }
                Rectangle {
                    width: parent.width * 0.1
                    height: parent.height * 0.08
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, 0.4)
                    x: parent.width * 0.58
                    y: parent.height * 0.16
                }
            }

            // trilha
            Rectangle {
                width: 1.5
                height: drop.sz * 2.8
                x: drop.sz / 2 - 0.75
                y: drop.sz * 0.75
                color: Qt.rgba(1, 1, 1, 0.1)
                radius: 1
            }

            // animacao de escorregamento
            SequentialAnimation on y {
                loops: Animation.Infinite
                PauseAnimation { duration: 500 + Math.random() * 4000 }
                NumberAnimation {
                    from: drop.originY
                    to:   drop.originY + 80 + Math.random() * 160
                    duration: drop.spd
                    easing.type: Easing.InQuad
                }
                PropertyAction { value: drop.originY }
            }
        }
    }
}
