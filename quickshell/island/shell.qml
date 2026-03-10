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

        // ── Album art flip state ──────────────────────────────────────
        // 0 = idle, 1 = hiding old (0→90°), 2 = showing new (270°→360°)
        property int   artFlipPhase: 0
        property real  artFlipAngle: 0        // drives both stacked images
        property string pendingArtSource: ""  // new art queued during flip

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
            command: ["/home/agony/.config/quickshell/island/scripts/get-dominant-color.sh", imagePath]
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
            command: ["bash", "/home/agony/.config/quickshell/island/scripts/spotify-sink.sh"]
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
            command: ["cava", "-p", "/home/agony/.config/quickshell/island/config/cava.conf"]
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

        // ── Flip animation helper ─────────────────────────────────────
        // Called when we have a resolved local path (or blank) to swap to
        function triggerArtFlip(newSource, localPath) {
            if (island.artFlipPhase !== 0) {
                // Already mid-flip: just queue the latest source
                island.pendingArtSource = newSource
                return
            }
            if (newSource === artFront.source.toString()) return  // same art

            island.pendingArtSource = newSource
            island.artFlipPhase = 1
            artFlipHide.start()

            if (localPath !== "") {
                dominantColor.imagePath = localPath
                dominantColor.running = false
                Qt.callLater(function() { dominantColor.running = true })
            }
        }

        SequentialAnimation {
            id: artFlipHide  // Phase 1: rotate from 0 to 90 (hide front)
            NumberAnimation {
                target: island; property: "artFlipAngle"
                from: 0; to: 90
                duration: 110; easing.type: Easing.InQuad
            }
            ScriptAction {
                script: {
                    // At 90° both images are invisible → swap source on back
                    artFront.source = island.pendingArtSource
                    island.pendingArtSource = ""
                    island.artFlipPhase = 2
                    artFlipShow.start()
                }
            }
        }

        NumberAnimation {
            id: artFlipShow  // Phase 2: rotate from 90 back to 0 (reveal new)
            target: island; property: "artFlipAngle"
            from: 90; to: 0
            duration: 140; easing.type: Easing.OutQuad
            onStopped: {
                island.artFlipPhase = 0
                // If another track came in while we were animating, flip again
                if (island.pendingArtSource !== "") {
                    island.artFlipPhase = 1
                    artFlipHide.start()
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
                    if (newTitle !== "" && newTitle !== musicTitle.text) {
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
                        island.triggerArtFlip(artUrl, path)
                    } else {
                        island.triggerArtFlip("", "")
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
                    island.triggerArtFlip("file://" + path, path)
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
                    color: "#000000"
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Item {
                        anchors.fill: parent
                        transform: Scale {
                            origin.x: 10
                            origin.y: 10
                            xScale: Math.abs(Math.cos(island.artFlipAngle * Math.PI / 180))
                        }
                        
                        Image {
                            anchors.fill: parent
                            source: artFront.source
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
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
                        color: "#000000"
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        // ── Flip container ────────────────────────────────
                        // artFlipAngle: 0 = fully visible, 90 = fully hidden
                        // We simulate Y-axis perspective with horizontal scale
                        // (cos of angle) — simple & looks great without Transform3D
                        Item {
                            id: artFlipContainer
                            anchors.fill: parent

                            // scaleX = cos(angle_in_radians)
                            // At 0°  → 1.0 (full width), at 90° → 0.0 (invisible)
                            transform: Scale {
                                origin.x: artFlipContainer.width / 2
                                origin.y: 0
                                xScale: Math.abs(Math.cos(island.artFlipAngle * Math.PI / 180))
                            }

                            // Front image (the currently visible art)
                            Image {
                                id: artFront
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: artFront.width
                                        height: artFront.height
                                        radius: 14
                                    }
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
                        source: "./assets/skip-back.png"
                        width: 18
                        height: 18
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        anchors.verticalCenter: parent.verticalCenter
                        layer.enabled: true
                        layer.smooth: true
                        layer.effect: ColorOverlay {
                            color: island.dominantCol
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: playerctlPrev.running = true
                        }
                    }

                    Image {
                        id: playbackBtn
                        source: "./assets/pause.png"
                        width: 24
                        height: 24
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        anchors.verticalCenter: parent.verticalCenter
                        layer.enabled: true
                        layer.smooth: true
                        layer.effect: ColorOverlay {
                            color: island.dominantCol
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: playerctlPlayPause.running = true
                        }
                    }

                    Image {
                        source: "./assets/skip-forward.png"
                        width: 18
                        height: 18
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        anchors.verticalCenter: parent.verticalCenter
                        layer.enabled: true
                        layer.smooth: true
                        layer.effect: ColorOverlay {
                            color: island.dominantCol
                        }

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
