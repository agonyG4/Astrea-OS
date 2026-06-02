import QtQuick
import QtQuick.Effects
import Quickshell

ShellRoot {
    FloatingWindow {
        width: 720
        height: 420
        color: "#15151c"

        Item {
            id: root
            anchors.fill: parent

            Item {
                id: app
                anchors.fill: parent
                layer.enabled: true

                Text {
                    x: 36; y: 4
                    text: "conteúdo do app atrás"
                    color: "white"
                    font.pixelSize: 32
                    font.bold: true
                }

                Row {
                    x: 36; y: 50
                    spacing: 12

                    Repeater {
                        model: 8
                        Rectangle {
                            width: 56
                            height: 56
                            radius: 14
                            color: Qt.hsla(index / 8, 0.75, 0.55, 1)
                        }
                    }
                }

                Repeater {
                    model: 12
                    Text {
                        x: 36
                        y: 130 + index * 24
                        text: "texto passando atrás do botão, linha " + (index + 1)
                        color: Qt.rgba(1, 1, 1, 0.55)
                        font.pixelSize: 18
                    }
                }
            }

            Item {
                id: glass
                x: 150
                y: 38
                width: 230
                height: 72
                clip: true

                property point pos: app.mapFromItem(glass, 0, 0)

                Rectangle {
                    anchors.fill: parent
                    radius: 26
                    color: "transparent"
                    clip: true

                    ShaderEffectSource {
                        id: src
                        sourceItem: app
                        sourceRect: Qt.rect(glass.pos.x, glass.pos.y, glass.width, glass.height)
                        width: glass.width
                        height: glass.height
                        live: true
                        recursive: false
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: src

                        blurEnabled: true
                        blur: 1.0
                        blurMax: 64
                        blurMultiplier: 3.0

                        saturation: 2.0
                        brightness: 0.12

                        autoPaddingEnabled: false
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 26
                        color: Qt.rgba(1, 1, 1, 0.18)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.45)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "glass button"
                        color: "white"
                        font.pixelSize: 18
                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    property real dx
                    property real dy

                    onPressed: {
                        dx = mouse.x
                        dy = mouse.y
                    }

                    onPositionChanged: {
                        if (pressed) {
                            glass.x += mouse.x - dx
                            glass.y += mouse.y - dy
                        }
                    }
                }
            }
        }
    }
}