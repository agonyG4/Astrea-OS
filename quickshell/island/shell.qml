import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

ShellRoot {
    PanelWindow {
        id: island

        anchors {
            top: true
        }

        implicitWidth: screen.width
        implicitHeight: islandContent.height + 16

        color: "transparent"
        WlrLayershell.namespace: "dynamic-island"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrLayershell.None

        mask: Region {
            item: islandContent
        }

        property string artUrlCache: ""
        property var cavaBars: [0, 0, 0, 0, 0, 0]
        property string dominantCol: "#ffffff"
        property real musicPosition: 0
        property real musicLength: 1
        property real smoothPosition: 0

        // Formata microsegundos em "m:ss"
        function formatTime(us) {
            var totalSec = Math.floor(us / 1000000)
            var m = Math.floor(totalSec / 60)
            var s = totalSec % 60
            return m + ":" + (s < 10 ? "0" + s : s)
        }

        onMusicPositionChanged: {
            smoothPosition = musicPosition
        }

        Timer {
            interval: 100
            running: island.musicLength > 0
            repeat: true
            onTriggered: {
                island.smoothPosition = Math.min(island.smoothPosition + 100000, island.musicLength)
            }
        }

        Process {
            id: dominantColor
            property string imagePath: ""
            command: ["/home/agony/.config/quickshell/island/scripts/dominant_color.sh", imagePath]
            running: false
            stdout: SplitParser {
                onRead: data => {
                    var parts = data.trim().split(" ")
                    if (parts.length === 3) {
                        var r = parseInt(parts[0])
                        var g = parseInt(parts[1])
                        var b = parseInt(parts[2])
                        island.dominantCol = Qt.rgba(r/255, g/255, b/255, 1).toString()
                    }
                }
            }
        }

        Process {
            id: spotifySink
            command: ["bash", "/home/agony/.config/quickshell/island/scripts/spotify_sink.sh"]
            running: false
            stdout: SplitParser {
                onRead: data => {
                    cavaProcess.running = false
                    Qt.callLater(function() { cavaProcess.running = true })
                }
            }
        }

        Process {
            id: cavaProcess
            command: ["cava", "-p", "/home/agony/.config/quickshell/island/cava.conf"]
            running: true
            stdout: SplitParser {
                splitMarker: "\n"
                onRead: data => {
                    var trimmed = data.trim()
                    if (trimmed === "") return
                    var parts = trimmed.replace(/;$/, "").split(";")
                    if (parts.length >= 6) {
                        island.cavaBars = [
                            parseInt(parts[0]) || 0,
                            parseInt(parts[1]) || 0,
                            parseInt(parts[2]) || 0,
                            parseInt(parts[3]) || 0,
                            parseInt(parts[4]) || 0,
                            parseInt(parts[5]) || 0
                        ]
                    }
                }
            }
        }

        Process {
            id: playerctlFollow
            command: ["playerctl", "--player=spotify", "metadata", "--format", "{{title}}|||{{artist}}|||{{mpris:artUrl}}", "--follow"]
            running: true
            stdout: SplitParser {
                onRead: data => {
                    var parts = data.split("|||")
                    var newTitle = parts[0] || ""
                    if (newTitle !== "" && musicTitle.text === "") {
                        spotifySink.running = false
                        Qt.callLater(function() { spotifySink.running = true })
                    }
                    musicTitle.text = newTitle
                    musicArtist.text = parts[1] || ""

                    var artUrl = parts[2] || ""
                    if (artUrl.startsWith("https://")) {
                        island.artUrlCache = artUrl
                        fetchArt.running = false
                        Qt.callLater(function() { fetchArt.running = true })
                    } else if (artUrl.startsWith("file://")) {
                        var path = artUrl.replace("file://", "")
                        albumArt.source = ""
                        albumArt.source = artUrl
                        dominantColor.imagePath = path
                        dominantColor.running = false
                        Qt.callLater(function() { dominantColor.running = true })
                    } else {
                        albumArt.source = ""
                        island.dominantCol = "#ffffff"
                    }
                }
            }
        }

        Process {
            id: playerctlProgress
            command: ["playerctl", "--player=spotify", "metadata", "--format", "{{position}} {{mpris:length}}", "--follow"]
            running: true
            stdout: SplitParser {
                onRead: data => {
                    var parts = data.trim().split(" ")
                    if (parts.length === 2) {
                        island.musicPosition = parseInt(parts[0]) || 0
                        island.musicLength = parseInt(parts[1]) || 1
                    }
                }
            }
        }

        Process {
            id: fetchArt
            command: ["bash", "-c", "FILE=~/.cache/island_art_$(date +%s).jpg && curl -sL '" + island.artUrlCache + "' -o \"$FILE\" && echo \"$FILE\""]
            running: false
            stdout: SplitParser {
                onRead: data => {
                    var path = data.trim()
                    albumArt.source = ""
                    albumArt.source = "file://" + path
                    dominantColor.imagePath = path
                    dominantColor.running = false
                    Qt.callLater(function() { dominantColor.running = true })
                }
            }
        }

        Process {
            id: playerctlPlayPause
            command: ["playerctl", "--player=spotify", "play-pause"]
            running: false
        }

        Process {
            id: playerctlNext
            command: ["playerctl", "--player=spotify", "next"]
            running: false
        }

        Process {
            id: playerctlPrev
            command: ["playerctl", "--player=spotify", "previous"]
            running: false
        }

        Rectangle {
            id: islandContent

            width: {
                if (musicTitle.text === "") {
                    return mouseArea.containsMouse ? 140 : 120
                }
                return mouseArea.containsMouse ? 360 : 180
            }

            height: {
                if (musicTitle.text === "") {
                    return mouseArea.containsMouse ? 38 : 34
                }
                return mouseArea.containsMouse ? 160 : 34
            }

            property real currentRadius: mouseArea.containsMouse && musicTitle.text !== "" ? 32 : 17
            radius: currentRadius

            color: "transparent"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 8
            clip: true

            Behavior on width {
                NumberAnimation { duration: 400; easing.type: Easing.OutExpo }
            }
            Behavior on height {
                NumberAnimation { duration: 400; easing.type: Easing.OutExpo }
            }
            Behavior on currentRadius {
                NumberAnimation { duration: 400; easing.type: Easing.OutExpo }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.currentRadius
                color: "#000000"
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
            }

            // MODO COMPACTO
            Item {
                anchors.fill: parent
                visible: musicTitle.text !== "" && !mouseArea.containsMouse
                opacity: (musicTitle.text !== "" && !mouseArea.containsMouse) ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    color: "#333333"
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: albumArt.source
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                            }
                        }
                    }
                }

                Row {
                    id: compactBars
                    spacing: 3
                    width: 30
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: 6
                        Item {
                            width: 3
                            height: 20

                            Rectangle {
                                width: 3
                                height: Math.max(3, (island.cavaBars[index] / 100) * 18)
                                radius: 2
                                color: island.dominantCol
                                anchors.centerIn: parent

                                Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutSine } }
                                Behavior on color { ColorAnimation { duration: 800 } }
                            }
                        }
                    }
                }
            }

            // MODO EXPANDIDO
            Item {
                anchors.fill: parent
                visible: musicTitle.text !== "" && mouseArea.containsMouse
                opacity: (musicTitle.text !== "" && mouseArea.containsMouse) ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                // Topo: Capa, Título/Artista, Waveform
                Item {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 18
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    height: 60

                    Rectangle {
                        id: artRect
                        width: 60
                        height: 60
                        radius: 14
                        color: "#333333"
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: albumArt
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: albumArt.width
                                    height: albumArt.height
                                    radius: 14
                                }
                            }
                        }
                    }

                    Column {
                        anchors.left: artRect.right
                        anchors.leftMargin: 14
                        anchors.right: expandedWaveform.left
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            id: musicTitle
                            color: "white"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            id: musicArtist
                            color: "#aaaaaa"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    Row {
                        id: expandedWaveform
                        width: 36
                        spacing: 3
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: 6
                            Item {
                                width: 3
                                height: 36

                                Rectangle {
                                    width: 3
                                    height: Math.max(3, (island.cavaBars[index] / 100) * 34)
                                    radius: 2
                                    color: island.dominantCol
                                    anchors.centerIn: parent

                                    Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutSine } }
                                    Behavior on color { ColorAnimation { duration: 800 } }
                                }
                            }
                        }
                    }
                }

                // Barra de progresso com tempos nas laterais
                Item {
                    id: progressSection
                    anchors.top: parent.top
                    anchors.topMargin: 90
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    height: 22

                    // Tempo atual (esquerda)
                    Text {
                        id: currentTimeLabel
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: island.formatTime(island.smoothPosition)
                        color: "#aaaaaa"
                        font.pixelSize: 12
                    }

                    // Barra de progresso (centro)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: currentTimeLabel.right
                        anchors.right: totalTimeLabel.left
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        height: 5
                        radius: 2.5
                        color: Qt.rgba(1, 1, 1, 0.2)

                        Rectangle {
                            width: parent.width * (island.musicLength > 0 ? island.smoothPosition / island.musicLength : 0)
                            height: parent.height
                            radius: 2.5
                            color: island.dominantCol

                            Behavior on color { ColorAnimation { duration: 800 } }
                        }
                    }

                    // Tempo total (direita)
                    Text {
                        id: totalTimeLabel
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: island.formatTime(island.musicLength)
                        color: "#aaaaaa"
                        font.pixelSize: 12
                    }
                }

                // Controles de Playback
                Row {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 40

                    Image {
                        source: "./img/left_skip.png"
                        width: 24
                        height: 24
                        fillMode: Image.PreserveAspectFit
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: playerctlPrev.running = true
                        }
                    }

                    Image {
                        source: "./img/pause.png"
                        width: 32
                        height: 32
                        fillMode: Image.PreserveAspectFit
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: playerctlPlayPause.running = true
                        }
                    }

                    Image {
                        source: "./img/right_skip.png"
                        width: 24
                        height: 24
                        fillMode: Image.PreserveAspectFit
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: playerctlNext.running = true
                        }
                    }
                }
            }
        }
    }
}
