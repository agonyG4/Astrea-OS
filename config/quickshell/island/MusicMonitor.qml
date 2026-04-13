import Quickshell.Io
import QtQuick

Item {
    id: root

    property string artUrlCache: ""
    property var    cavaBars: [0, 0, 0, 0, 0, 0]
    property string dominantCol: "#ffffff"
    property real   musicPosition: 0
    property real   musicLength: 1
    property string musicTitleText: ""
    property string musicArtistText: ""
    property string artSource: ""
    property string artPath: ""
    property bool   isPlaying: false
    property bool   shouldDisplayMusic: false
    property bool   isShuffle: false
    property bool   isLoop: false
    property bool   isLoopTrack: false
    property bool   isLoopPlaylist: false
    property string loopMode: "none"

    property bool _playerMonitorStarting: false

    function setDominantColor(path) {
        dominantColor.imagePath = path
        dominantColor.running = false
        Qt.callLater(() => { dominantColor.running = true })
    }

    function playPause() {
        playerctlPlayPause.running = false
        Qt.callLater(() => { playerctlPlayPause.running = true })
    }

    function next() {
        playerctlNext.running = false
        Qt.callLater(() => { playerctlNext.running = true })
    }

    function prev() {
        playerctlPrev.running = false
        Qt.callLater(() => { playerctlPrev.running = true })
    }

    function toggleShuffle() {
        playerctlShuffle.running = false
        Qt.callLater(() => { playerctlShuffle.running = true })
    }

    function toggleLoop() {
        var next = (loopMode === "" || loopMode === "none") ? "playlist" : loopMode === "playlist" ? "track" : "none"
        playerctlLoop.nextMode = next === "playlist" ? "Playlist" : next === "track" ? "Track" : "None"
        playerctlLoop.running = false
        Qt.callLater(() => {
            playerctlLoop.running = true
            loopMode = next
            isLoop = next !== "none"
            isLoopTrack = next === "track"
            isLoopPlaylist = next === "playlist"
        })
    }

    function setPosition(targetPosMicroSec) {
        playerctlSeek.targetPosSec = targetPosMicroSec / 1000000
        playerctlSeek.running = false
        Qt.callLater(() => { playerctlSeek.running = true })
    }

    function clearState() {
        inactiveTimer.stop()
        artUrlCache = ""
        musicPosition = 0
        musicLength = 1
        musicTitleText = ""
        musicArtistText = ""
        artSource = ""
        artPath = ""
        dominantCol = "#ffffff"
        isPlaying = false
        shouldDisplayMusic = false
        isShuffle = false
        isLoop = false
        isLoopTrack = false
        isLoopPlaylist = false
        loopMode = "none"
        cavaBars = [0, 0, 0, 0, 0, 0]
        cavaProcess.running = false
    }

    function scheduleInactiveReset() {
        inactiveTimer.restart()
    }

    function handlePlayerUnavailable() {
        inactiveTimer.stop()
        clearState()
    }

    function ensureMonitoring() {
        if (!_playerMonitorStarting && !playerMonitor.running) {
            _playerMonitorStarting = true
            playerMonitor.running = false
            Qt.callLater(() => { playerMonitor.running = true })
        }
    }

    Process {
        id: dominantColor
        property string imagePath: ""
        command: [Qt.resolvedUrl("scripts/get-dominant-color.sh").toString().replace("file://", ""), imagePath]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split(" ")
                if (p.length !== 3) return
                var r = parseInt(p[0]), g = parseInt(p[1]), b = parseInt(p[2])
                if (isNaN(r) || isNaN(g) || isNaN(b)) return
                root.dominantCol = Qt.rgba(r / 255, g / 255, b / 255, 1).toString()
            }
        }
    }

    Process {
        id: cavaProcess
        command: ["cava", "-p", Qt.resolvedUrl("config/cava.conf").toString().replace("file://", "")]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var parts = data.trim().split(";")
                if (parts.length < 6) return
                var nextBars = []
                for (var i = 0; i < 6; i++)
                    nextBars.push(parseInt(parts[i]) || 0)
                root.cavaBars = nextBars
            }
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if ((data || "").trim() !== "")
                    root.cavaBars = [0, 0, 0, 0, 0, 0]
            }
        }
    }

    Process {
        id: playerMonitor
        command: ["playerctl", "--player=spotify", "metadata",
            "--format", "{{status}}|||{{title}}|||{{artist}}|||{{mpris:artUrl}}|||{{position}}|||{{mpris:length}}|||{{shuffle}}",
            "--follow"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var p = data.split("|||")
                if (p.length < 7) return

                var status = p[0].trim().toLowerCase()
                var title = p[1].trim()
                var artist = p[2].trim()
                var artUrl = (p[3] || "").trim()
                var pos = parseInt(p[4]) || 0
                var len = parseInt(p[5]) || 1
                var shuffle = p[6].trim().toLowerCase()

                if (!title || status === "stopped") {
                    root.isPlaying = false
                    root.scheduleInactiveReset()
                    return
                }

                root.isPlaying = status === "playing"
                root.shouldDisplayMusic = true
                root.musicTitleText = title
                root.musicArtistText = artist
                root.musicPosition = pos
                root.musicLength = len
                root.isShuffle = shuffle === "true" || shuffle === "1"

                if (root.isPlaying) {
                    inactiveTimer.stop()
                    if (!cavaProcess.running) {
                        cavaProcess.running = false
                        Qt.callLater(() => { cavaProcess.running = true })
                    }
                } else {
                    cavaProcess.running = false
                    root.cavaBars = [0, 0, 0, 0, 0, 0]
                    root.scheduleInactiveReset()
                }

                if (artUrl === root.artUrlCache)
                    return

                root.artUrlCache = artUrl

                if (!artUrl) {
                    root.artSource = ""
                    root.artPath = ""
                    root.dominantCol = "#ffffff"
                } else if (artUrl.startsWith("http")) {
                    fetchArt.running = false
                    Qt.callLater(() => {
                        fetchArt.url = artUrl
                        fetchArt.running = true
                    })
                } else {
                    root.artSource = artUrl
                    root.artPath = artUrl.replace("file://", "").split("?")[0]
                    root.setDominantColor(root.artPath)
                }
            }
        }
        stderr: SplitParser {
            onRead: data => {
                if (data.includes("No players found"))
                    root.handlePlayerUnavailable()
            }
        }
        onRunningChanged: {
            if (running) {
                root._playerMonitorStarting = false
            } else if (!root._playerMonitorStarting) {
                root.handlePlayerUnavailable()
                retryTimer.restart()
            }
        }
    }

    Process {
        id: fetchArt
        property string url: ""
        command: ["bash", "-c",
            "curl -sL --max-time 10 --output ~/.cache/island_art.jpg -- \"$1\" && echo ~/.cache/island_art.jpg",
            "--", url]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var path = data.trim()
                if (!path) return
                root.artSource = "file://" + path + "?" + Date.now()
                root.artPath = path
                root.setDominantColor(path)
            }
        }
    }

    Process { id: playerctlPlayPause; command: ["playerctl", "--player=spotify", "play-pause"]; running: false }
    Process { id: playerctlNext; command: ["playerctl", "--player=spotify", "next"]; running: false }
    Process { id: playerctlPrev; command: ["playerctl", "--player=spotify", "previous"]; running: false }
    Process { id: playerctlShuffle; command: ["playerctl", "--player=spotify", "shuffle", "toggle"]; running: false }

    Process {
        id: playerctlLoop
        property string nextMode: "Playlist"
        command: ["playerctl", "--player=spotify", "loop", nextMode]
        running: false
    }

    Process {
        id: playerctlSeek
        property real targetPosSec: 0
        command: ["playerctl", "--player=spotify", "position", targetPosSec.toString()]
        running: false
    }

    Timer {
        id: retryTimer
        interval: 5000
        repeat: false
        onTriggered: root.ensureMonitoring()
    }

    Timer {
        id: inactiveTimer
        interval: 5000
        repeat: false
        onTriggered: root.clearState()
    }

    Component.onCompleted: ensureMonitoring()
}
