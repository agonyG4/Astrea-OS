import Quickshell
import QtQuick 2.15
import QtQuick.Effects

FloatingWindow {
    id: root

    title: "transparency-test"
    implicitWidth: 920
    implicitHeight: 560
    minimumSize: Qt.size(520, 340)
    visible: true
    color: "transparent"

    property real blurAmount: 0.1
    property real glassAlpha: 0.0
    property real borderAlpha: 0.28
    property real edgeThickness: 0.82

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
                color: "#090b0f"
            }

            Repeater {
                model: 7

                delegate: Rectangle {
                    required property int index

                    width: 280 + index * 22
                    height: 84
                    radius: 4
                    x: -40 + index * 132 + Math.sin(motion.phase + index) * 18
                    y: 30 + (index % 4) * 116 + Math.cos(motion.phase * 0.8 + index) * 14
                    rotation: -8 + index * 2.5
                    color: Qt.hsla((0.54 + index * 0.075) % 1, 0.72, 0.56, 0.46)
                }
            }

            Repeater {
                model: [
                    { text: "TRANSPARENCY", x: 44, y: 50, size: 78, color: "#f5f0db" },
                    { text: "QT EFFECTS", x: 450, y: 140, size: 86, color: "#b8f4ff" },
                    { text: "SOURCE RECT", x: 70, y: 286, size: 72, color: "#d9ffbe" },
                    { text: "LIVE BLUR", x: 494, y: 404, size: 80, color: "#ffd2ef" }
                ]

                delegate: Text {
                    required property int index
                    required property var modelData

                    x: modelData.x + Math.sin(motion.phase * 0.7 + index) * 8
                    y: modelData.y + Math.cos(motion.phase * 0.9 + index) * 6
                    text: modelData.text
                    color: modelData.color
                    opacity: 0.82
                    font.pixelSize: modelData.size
                    font.weight: Font.Black
                    font.capitalization: Font.AllUppercase
                }
            }

            Repeater {
                model: 32

                delegate: Rectangle {
                    required property int index

                    width: backdrop.width * 1.22
                    height: 2
                    x: -backdrop.width * 0.11
                    y: 20 + index * 18
                    rotation: index % 2 === 0 ? -10 : 6
                    color: index % 4 === 0 ? "#ffffff" : "#69e7ff"
                    opacity: index % 4 === 0 ? 0.36 : 0.20
                }
            }
        }

        Item {
            id: controls
            anchors.fill: parent

            GlassButton {
                x: Math.max(28, root.width - width - 48)
                y: 72
                width: Math.min(330, root.width - 72)
                label: "Blur button"
                detail: "MultiEffect over ShaderEffectSource"
                sourceItem: backdrop
                accent: "#b8f4ff"
            }

            GlassButton {
                x: Math.max(28, root.width - width - 96)
                y: 166
                width: Math.min(360, root.width - 72)
                label: "Transparent shell"
                detail: "Window color is transparent"
                sourceItem: backdrop
                accent: "#d9ffbe"
            }

            GlassButton {
                x: Math.max(28, root.width - width - 52)
                y: 260
                width: Math.min(310, root.width - 72)
                label: "Drag me"
                detail: "sourceRect follows position"
                sourceItem: backdrop
                accent: "#ffd2ef"
            }

            Item {
                x: 42
                y: root.height - height - 44
                width: Math.min(410, root.width - 84)
                height: 144

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Qt.rgba(0.02, 0.025, 0.032, 0.42)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.18)
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    TuningRow {
                        label: "blur"
                        value: root.blurAmount
                        onChanged: value => root.blurAmount = value
                    }

                    TuningRow {
                        label: "glass"
                        value: root.glassAlpha
                        onChanged: value => root.glassAlpha = value
                    }

                    TuningRow {
                        label: "border"
                        value: root.borderAlpha
                        onChanged: value => root.borderAlpha = value
                    }

                    TuningRow {
                        label: "edge"
                        value: root.edgeThickness
                        onChanged: value => root.edgeThickness = value
                    }
                }
            }
        }
    }

    NumberAnimation {
        id: motion
        property real phase: 0
        from: 0
        to: Math.PI * 2
        duration: 11000
        loops: Animation.Infinite
        running: true
    }

    component TuningRow: Item {
        id: row

        required property string label
        property real value: 0
        signal changed(real value)

        height: 20

        Text {
            id: caption
            width: 54
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            color: Qt.rgba(1, 1, 1, 0.78)
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Rectangle {
            id: rail
            x: 68
            width: row.width - x
            height: 6
            radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(1, 1, 1, 0.16)

            Rectangle {
                width: rail.width * Math.max(0, Math.min(1, row.value))
                height: parent.height
                radius: parent.radius
                color: Qt.rgba(1, 1, 1, 0.62)
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true

                function updateValue(mouseX) {
                    row.changed(Math.max(0, Math.min(1, mouseX / rail.width)))
                }

                onPressed: mouse => updateValue(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        updateValue(mouse.x)
                }
            }
        }
    }

    component GlassButton: Item {
        id: button

        required property string label
        required property string detail
        required property var sourceItem
        property color accent: "#ffffff"

        height: 72
        scale: mouse.pressed ? 0.982 : 1.0

        Behavior on scale {
            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
        }

        ShaderEffectSource {
            id: source

            readonly property real pad: 32

            x: -pad
            y: -pad
            width: button.width + pad * 2
            height: button.height + pad * 2
            sourceItem: button.sourceItem
            sourceRect: Qt.rect(button.x - pad, button.y - pad, width, height)
            textureSize: Qt.size(Math.max(1, Math.round(width / 3)), Math.max(1, Math.round(height / 3)))
            live: true
            smooth: true
            recursive: true
            visible: false
        }

        ShaderEffectSource {
            id: refractTop

            readonly property real edgePx: 4 + root.edgeThickness * 34
            readonly property real shift: 2 + root.edgeThickness * 14

            width: button.width
            height: edgePx
            sourceItem: button.sourceItem
            sourceRect: Qt.rect(button.x - shift, button.y - shift, width + shift * 2, height + shift * 2)
            textureSize: Qt.size(Math.max(1, Math.round(width / 2)), Math.max(1, Math.round(height / 2)))
            live: true
            smooth: true
            recursive: true
            visible: false
        }

        ShaderEffectSource {
            id: refractBottom

            readonly property real edgePx: 4 + root.edgeThickness * 34
            readonly property real shift: 2 + root.edgeThickness * 14

            width: button.width
            height: edgePx
            sourceItem: button.sourceItem
            sourceRect: Qt.rect(button.x + shift, button.y + button.height - height + shift, width + shift * 2, height + shift * 2)
            textureSize: Qt.size(Math.max(1, Math.round(width / 2)), Math.max(1, Math.round(height / 2)))
            live: true
            smooth: true
            recursive: true
            visible: false
        }

        ShaderEffectSource {
            id: refractLeft

            readonly property real edgePx: 4 + root.edgeThickness * 24
            readonly property real shift: 2 + root.edgeThickness * 10

            width: edgePx
            height: button.height
            sourceItem: button.sourceItem
            sourceRect: Qt.rect(button.x - shift, button.y - shift, width + shift * 2, height + shift * 2)
            textureSize: Qt.size(Math.max(1, Math.round(width / 2)), Math.max(1, Math.round(height / 2)))
            live: true
            smooth: true
            recursive: true
            visible: false
        }

        ShaderEffectSource {
            id: refractRight

            readonly property real edgePx: 4 + root.edgeThickness * 24
            readonly property real shift: 2 + root.edgeThickness * 10

            width: edgePx
            height: button.height
            sourceItem: button.sourceItem
            sourceRect: Qt.rect(button.x + button.width - width + shift, button.y + shift, width + shift * 2, height + shift * 2)
            textureSize: Qt.size(Math.max(1, Math.round(width / 2)), Math.max(1, Math.round(height / 2)))
            live: true
            smooth: true
            recursive: true
            visible: false
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            clip: true
            color: "transparent"

            MultiEffect {
                x: source.x
                y: source.y
                width: source.width
                height: source.height
                source: source
                blurEnabled: true
                blurMax: 48
                blur: root.blurAmount
                blurMultiplier: 1.25
                autoPaddingEnabled: false
                saturation: 1.16
                brightness: mouse.containsMouse ? 0.10 : 0.02
            }

            Item {
                anchors.fill: parent
                opacity: 0.14 + root.edgeThickness * 0.40

                MultiEffect {
                    x: 0
                    y: 0
                    width: refractTop.width
                    height: refractTop.height
                    source: refractTop
                    blurEnabled: true
                    blurMax: 8
                    blur: Math.min(1, root.blurAmount * 0.18)
                    autoPaddingEnabled: false
                    saturation: 1.18
                    brightness: 0.06
                }

                MultiEffect {
                    x: 0
                    y: 0
                    width: refractLeft.width
                    height: refractLeft.height
                    source: refractLeft
                    blurEnabled: true
                    blurMax: 8
                    blur: Math.min(1, root.blurAmount * 0.12)
                    autoPaddingEnabled: false
                    saturation: 1.14
                    brightness: 0.03
                }

                Rectangle {
                    x: button.width - refractRight.width
                    y: 0
                    width: refractRight.width
                    height: parent.height
                    clip: true
                    color: "transparent"

                    MultiEffect {
                        x: 0
                        y: 0
                        width: refractRight.width
                        height: refractRight.height
                        source: refractRight
                        blurEnabled: true
                        blurMax: 8
                        blur: Math.min(1, root.blurAmount * 0.12)
                        autoPaddingEnabled: false
                        saturation: 1.14
                        brightness: 0.03
                    }
                }

                Rectangle {
                    x: 0
                    y: button.height - refractBottom.height
                    width: parent.width
                    height: refractBottom.height
                    clip: true
                    color: "transparent"

                    MultiEffect {
                        x: 0
                        y: 0
                        width: refractBottom.width
                        height: refractBottom.height
                        source: refractBottom
                        blurEnabled: true
                        blurMax: 8
                        blur: Math.min(1, root.blurAmount * 0.14)
                        autoPaddingEnabled: false
                        saturation: 1.12
                        brightness: -0.01
                    }
                }

                Rectangle {
                    x: 12
                    y: button.height - refractBottom.height - 1
                    width: parent.width - 24
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.12 + root.edgeThickness * 0.20)
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Qt.rgba(1, 1, 1, root.glassAlpha)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, mouse.containsMouse ? root.borderAlpha + 0.16 : root.borderAlpha)
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 24
                radius: parent.radius
                color: Qt.rgba(1, 1, 1, mouse.containsMouse ? 0.18 : 0.08)
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 5
                radius: 3
                color: button.accent
                opacity: mouse.containsMouse ? 0.95 : 0.68
            }
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 22
            anchors.rightMargin: 18
            spacing: 4

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
