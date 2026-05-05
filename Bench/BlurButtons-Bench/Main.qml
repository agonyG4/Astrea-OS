import Quickshell
import QtQuick 2.15
import QtQuick.Effects

FloatingWindow {
    id: root

    title: "Blur Buttons Bench"
    implicitWidth: 900
    implicitHeight: 560
    minimumSize: Qt.size(520, 360)
    visible: true
    color: "transparent"

    onVisibleChanged: {
        if (!visible)
            Qt.quit()
    }

    Item {
        id: scene
        anchors.fill: parent

        Item {
            id: backdrop
            anchors.fill: parent
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                color: "#111317"
            }

            Repeater {
                model: [
                    { text: "TEXTO ATRAS", x: 54, y: 42, size: 88, color: "#fff0ba" },
                    { text: "QT EFFECTS", x: 438, y: 128, size: 104, color: "#bcecff" },
                    { text: "BLUR SIZE 3", x: 82, y: 284, size: 104, color: "#ffd6ee" },
                    { text: "TRANSPARENTE", x: 398, y: 432, size: 82, color: "#d9ffba" }
                ]

                delegate: Text {
                    required property int index
                    required property var modelData

                    x: modelData.x + Math.sin(drift.phase + index * 0.7) * 9
                    y: modelData.y + Math.cos(drift.phase + index * 0.9) * 7
                    text: modelData.text
                    color: modelData.color
                    opacity: 0.82
                    font.pixelSize: modelData.size
                    font.weight: Font.Black
                    font.capitalization: Font.AllUppercase
                }
            }

            Repeater {
                model: 20

                delegate: Rectangle {
                    required property int index

                    width: 116 + (index % 5) * 34
                    height: 36
                    radius: 18
                    x: 36 + (index * 81) % Math.max(1, backdrop.width - width - 72)
                    y: 52 + (index * 67) % Math.max(1, backdrop.height - height - 104)
                    rotation: -16 + (index % 7) * 5
                    color: Qt.hsla((index * 0.074) % 1, 0.62, 0.58, 0.42)
                }
            }

            Repeater {
                model: 34

                delegate: Rectangle {
                    required property int index

                    width: backdrop.width * 1.25
                    height: 3
                    x: -backdrop.width * 0.12
                    y: 24 + index * 18
                    rotation: index % 2 === 0 ? -11 : 7
                    color: index % 3 === 0 ? "#ffffff" : "#0df0ff"
                    opacity: index % 3 === 0 ? 0.42 : 0.28
                }
            }
        }

        Item {
            id: buttonLayer
            anchors.fill: parent

            Repeater {
                model: [
                    { label: "Open", detail: "QtEffects blurMax 3", yOffset: -123 },
                    { label: "Preview", detail: "sourceRect atrás", yOffset: -41 },
                    { label: "Sync", detail: "transparente", yOffset: 41 },
                    { label: "Close", detail: "arrasta livre", yOffset: 123 }
                ]

                delegate: GlassButton {
                    required property var modelData

                    width: Math.min(330, buttonLayer.width - 68)
                    label: modelData.label
                    detail: modelData.detail
                    sourceItem: backdrop

                    Component.onCompleted: {
                        x = buttonLayer.width - width - 34
                        y = buttonLayer.height / 2 + modelData.yOffset - height / 2
                    }
                }
            }
        }
    }

    NumberAnimation {
        id: drift
        property real phase: 0
        from: 0
        to: Math.PI * 2
        duration: 9000
        loops: Animation.Infinite
        running: true
    }

    component GlassButton: Item {
        id: button

        required property string label
        required property string detail
        required property var sourceItem

        height: 68
        scale: mouse.pressed ? 0.985 : 1

        Behavior on scale {
            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
        }

        ShaderEffectSource {
            id: behindButton

            readonly property real capturePadding: 28

            x: -capturePadding
            y: -capturePadding
            width: button.width + capturePadding * 2
            height: button.height + capturePadding * 2
            sourceItem: button.sourceItem
            sourceRect: Qt.rect(button.x - capturePadding, button.y - capturePadding, width, height)
            textureSize: Qt.size(Math.max(1, Math.round(width / 3)), Math.max(1, Math.round(height / 3)))
            live: true
            smooth: true
            recursive: true
            visible: false
        }

        Rectangle {
            anchors.fill: parent
            radius: 19
            clip: true
            color: "transparent"

            MultiEffect {
                x: behindButton.x
                y: behindButton.y
                width: behindButton.width
                height: behindButton.height
                source: behindButton
                blurEnabled: true
                blur: 1.0
                blurMax: 32
                blurMultiplier: 1.35
                autoPaddingEnabled: false
                saturation: 1.0
                brightness: 0.0
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Qt.rgba(0, 0, 0, 0.10)
                border.width: 1
                border.color: mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.14)
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 26
                radius: parent.radius
                color: Qt.rgba(1, 1, 1, mouse.containsMouse ? 0.08 : 0.035)
            }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 18
            spacing: 14

            Rectangle {
                width: 34
                height: 34
                radius: 17
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(0, 0, 0, 0.10)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.18)

                Text {
                    anchors.centerIn: parent
                    text: button.label.slice(0, 1)
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
            }

            Column {
                width: parent.width - 66
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: button.label
                    color: "#ffffff"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: button.detail
                    color: Qt.rgba(1, 1, 1, 0.72)
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: button
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 10
            drag.maximumX: Math.max(10, button.parent.width - button.width - 10)
            drag.minimumY: 10
            drag.maximumY: Math.max(10, button.parent.height - button.height - 10)
        }
    }
}
