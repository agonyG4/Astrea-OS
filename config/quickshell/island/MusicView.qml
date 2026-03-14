import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: musicView

    readonly property real flipScale: Math.abs(Math.cos(island.artFlipAngle * Math.PI / 180))

    anchors.fill: parent
    opacity: (island.isExpanded && !island.showGamemodeNotify && islandContent.height > 100) ? 1 : 0
    visible: opacity > 0.01

    // ── Topo: capa + título/artista + waveform ────────────────────────
    Item {
        anchors {
            top: parent.top; left: parent.left; right: parent.right
            topMargin: 18; leftMargin: 18; rightMargin: 18
        }
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
                    asynchronous: true

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: artImage.width
                            height: artImage.height
                            radius: 14
                        }
                    }
                }
            }
        }

        Column {
            anchors {
                left: artRect.right; leftMargin: 14
                right: waveform.left; rightMargin: 14
                top: parent.top; topMargin: 10
            }
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
                        height: Math.min(
                            island.cavaMaxHeightExpanded,
                            Math.max(island.cavaMinHeight, (island.cavaBars[index] / 100) * 34)
                        )
                        radius: 2
                        anchors.centerIn: parent
                        color: island.dominantCol
                        Behavior on height {
                            enabled: island.isExpanded
                            NumberAnimation { duration: 60; easing.type: Easing.OutSine }
                        }
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }
            }
        }
    }

    // ── Barra de progresso ────────────────────────────────────────────
    Item {
        anchors {
            top: parent.top; left: parent.left; right: parent.right
            topMargin: 90; leftMargin: 20; rightMargin: 20
        }
        height: 22

        Text {
            id: currentTimeLabel
            anchors { left: parent.left; top: parent.top; topMargin: 4 }
            text: island.formatTime(island.smoothPosition)
            color: "#aaaaaa"; font.pixelSize: 12
        }

        Rectangle {
            anchors {
                top: parent.top; topMargin: 8
                left: currentTimeLabel.right; leftMargin: 6
                right: totalTimeLabel.left; rightMargin: 6
            }
            height: 5; radius: 2.5
            color: Qt.rgba(1, 1, 1, 0.2)

            Rectangle {
                width: parent.width * (island.musicLength > 0
                    ? Math.min(island.smoothPosition / island.musicLength, 1.0)
                    : 0)
                height: parent.height; radius: 2.5
                color: island.dominantCol
                Behavior on color { ColorAnimation { duration: 300 } }
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

        Image {
            source: "./assets/skip-back.png"
            width: 18; height: 18
            fillMode: Image.PreserveAspectFit
            smooth: true; mipmap: true
            anchors.verticalCenter: parent.verticalCenter
            layer.enabled: true; layer.smooth: true
            layer.effect: ColorOverlay {
                color: island.dominantCol
                Behavior on color { ColorAnimation { duration: 300 } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: island.prev()
            }
        }

        Image {
            source: island.isPlaying ? "./assets/pause.png" : "./assets/play.png"
            width: 24; height: 24
            fillMode: Image.PreserveAspectFit
            smooth: true; mipmap: true
            anchors.verticalCenter: parent.verticalCenter
            layer.enabled: true; layer.smooth: true
            layer.effect: ColorOverlay {
                color: island.dominantCol
                Behavior on color { ColorAnimation { duration: 300 } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: island.playPause()
            }
        }

        Image {
            source: "./assets/skip-forward.png"
            width: 18; height: 18
            fillMode: Image.PreserveAspectFit
            smooth: true; mipmap: true
            anchors.verticalCenter: parent.verticalCenter
            layer.enabled: true; layer.smooth: true
            layer.effect: ColorOverlay {
                color: island.dominantCol
                Behavior on color { ColorAnimation { duration: 300 } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: island.next()
            }
        }
    }
}