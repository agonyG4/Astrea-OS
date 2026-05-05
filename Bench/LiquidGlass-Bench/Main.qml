import Quickshell
import QtQuick 2.15
import QtQuick.Effects

FloatingWindow {
    id: root

    title: "LiquidGlass Bench"
    implicitWidth: 760
    implicitHeight: 480
    minimumSize: Qt.size(360, 240)
    visible: true
    color: "transparent"

    property real radius: 38
    property real edge: 86

    onVisibleChanged: {
        if (!visible)
            Qt.quit()
    }

    Item {
        id: scene
        anchors.fill: parent

        Item {
            id: capturePlane
            anchors.fill: parent
        }

        Rectangle {
            id: lens
            anchors.fill: parent
            radius: root.radius
            color: Qt.rgba(1, 1, 1, 0.045)
            clip: true

            component RefractBand: Item {
                id: band

                property var sourceItem
                property rect sampleRect: Qt.rect(0, 0, width, height)
                property real blurAmount: 1.0
                property real brightnessAmount: 0.34
                property real saturationAmount: 1.0

                ShaderEffectSource {
                    id: captured
                    anchors.fill: parent
                    sourceItem: band.sourceItem
                    sourceRect: band.sampleRect
                    live: true
                    smooth: true
                    visible: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: captured
                    blurEnabled: true
                    blurMax: 64
                    blur: band.blurAmount
                    brightness: band.brightnessAmount
                    saturation: band.saturationAmount
                }
            }

            RefractBand {
                x: 0
                y: 0
                width: lens.width
                height: root.edge
                sourceItem: capturePlane
                sampleRect: Qt.rect(-180, -170, width + 360, height + 240)
            }

            RefractBand {
                x: 0
                y: lens.height - root.edge
                width: lens.width
                height: root.edge
                sourceItem: capturePlane
                sampleRect: Qt.rect(180, lens.height - height + 170, width + 340, height + 240)
            }

            RefractBand {
                x: 0
                y: 0
                width: root.edge
                height: lens.height
                sourceItem: capturePlane
                sampleRect: Qt.rect(-190, 160, width + 240, height + 340)
            }

            RefractBand {
                x: lens.width - root.edge
                y: 0
                width: root.edge
                height: lens.height
                sourceItem: capturePlane
                sampleRect: Qt.rect(lens.width - width + 190, -160, width + 240, height + 340)
            }

            Rectangle {
                anchors.fill: parent
                radius: lens.radius
                color: "transparent"
                border.width: 18
                border.color: Qt.rgba(1, 1, 1, 0.18)
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 10
                radius: Math.max(0, lens.radius - 10)
                color: "transparent"
                border.width: 2
                border.color: Qt.rgba(1, 1, 1, 0.46)
            }

            Rectangle {
                x: 20
                y: 14
                width: parent.width - 40
                height: 34
                radius: 17
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.70) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.14) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.00) }
                }
            }

            Rectangle {
                x: 16
                y: parent.height - 52
                width: parent.width - 32
                height: 36
                radius: 18
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.00) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.20) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.62) }
                }
            }

            Rectangle {
                x: 12
                y: 20
                width: 34
                height: parent.height - 40
                radius: 17
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.62) }
                    GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.18) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.00) }
                }
            }

            Rectangle {
                x: parent.width - 46
                y: 20
                width: 34
                height: parent.height - 40
                radius: 17
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.00) }
                    GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.18) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.62) }
                }
            }
        }
    }
}
