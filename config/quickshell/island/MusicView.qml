import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: musicView

    readonly property real flipScale: Math.abs(Math.cos(island.artFlipAngle * Math.PI / 180))

    // Controles separados pra não recriar o array todo frame que isPlaying muda
    readonly property list<var> controls: [
        { src: "./assets/skip-back.png",    w: 18, fn: function() { island.prev() } },
        { src: "./assets/play.png",         w: 24, fn: function() { island.playPause() } },
        { src: "./assets/skip-forward.png", w: 18, fn: function() { island.next() } }
    ]

    anchors.fill: parent
    opacity: (island.isExpanded && !island.showGamemodeNotify && islandContent.height > 100) ? 1 : 0
    visible: opacity > 0

    // ── Topo: capa + título/artista + waveform ────────────────────────
    Item {
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 18; leftMargin: 18; rightMargin: 18 }
        height: 60

        Item {
            id: artRect
            width: 60; height: 60
            anchors { left: parent.left; top: parent.top }

            Item {
                anchors.fill: parent
                transform: Scale {
                    origin.x: artRect.width / 2
                    xScale: musicView.flipScale
                }
                Image {
                    id: artImage
                    anchors.fill: parent
                    source: island.artSource
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    cache: false
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle { width: artImage.width; height: artImage.height; radius: 14 }
                    }
                }
            }
        }

        Column {
            anchors { left: artRect.right; leftMargin: 14; right: waveform.left; rightMargin: 14; top: parent.top; topMargin: 10 }
            spacing: 2

            Text {
                text: island.musicTitleText
                color: "white"; font.pixelSize: 15; font.weight: Font.DemiBold
                elide: Text.ElideRight; width: parent.width
            }
            Text {
                text: island.musicArtistText
                color: "#aaaaaa"; font.pixelSize: 13
                elide: Text.ElideRight; width: parent.width
            }
        }

        Row {
            id: waveform
            width: 36; spacing: 3
            anchors { right: parent.right; top: parent.top; topMargin: 12 }

            Repeater {
                model: 6
                Item {
                    width: 3; height: 36
                    Rectangle {
                        width: 3
                        height: Math.min(island.cavaMaxHeightExpanded, Math.max(island.cavaMinHeight, (island.cavaBars[index] / 100) * 34))
                        radius: 2; anchors.centerIn: parent
                        color: island.dominantCol
                        Behavior on height {
                            enabled: island.isExpanded
                            NumberAnimation { duration: 60; easing.type: Easing.OutSine }
                        }
                        Behavior on color { ColorAnimation { duration: 800 } }
                    }
                }
            }
        }
    }

    // ── Barra de progresso ────────────────────────────────────────────
    Item {
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 90; leftMargin: 20; rightMargin: 20 }
        height: 22

        Text {
            id: currentTimeLabel
            anchors { left: parent.left; top: parent.top; topMargin: 4 }
            text: island.formatTime(island.smoothPosition)
            color: "#aaaaaa"; font.pixelSize: 12
        }

        Rectangle {
            anchors { top: parent.top; topMargin: 8; left: currentTimeLabel.right; leftMargin: 6; right: totalTimeLabel.left; rightMargin: 6 }
            height: 5; radius: 2.5
            color: Qt.rgba(1, 1, 1, 0.2)

            Rectangle {
                width: parent.width * (island.musicLength > 0 ? island.smoothPosition / island.musicLength : 0)
                height: parent.height; radius: 2.5
                color: island.dominantCol
                Behavior on color { ColorAnimation { duration: 800 } }
            }
        }

        Text {
            id: totalTimeLabel
            anchors { right: parent.right; top: parent.top; topMargin: 4 }
            text: island.formatTime(island.musicLength)
            color: "#aaaaaa"; font.pixelSize: 12
        }
    }

    // ── Controles de playback ─────────────────────────────────────────
    Row {
        y: 120
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 40

    Repeater {
        model: 3

        Image {
            required property int index
            
            readonly property var srcs: [
                "./assets/skip-back.png",
                island.isPlaying ? "./assets/pause.png" : "./assets/play.png",
                "./assets/skip-forward.png"
            ]
            readonly property var sizes: [18, 24, 18]
            readonly property var fns: [
                function() { island.prev() },
                function() { island.playPause() },
                function() { island.next() }
            ]

            source: srcs[index]
            width: sizes[index]; height: sizes[index]
            fillMode: Image.PreserveAspectFit
            smooth: true; mipmap: true
            anchors.verticalCenter: parent.verticalCenter
            layer.enabled: true; layer.smooth: true
            layer.effect: ColorOverlay { color: island.dominantCol }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: fns[index]()
            }
        }
    }
    }
}