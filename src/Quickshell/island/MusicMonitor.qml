import Quickshell.Io
import Quickshell
import QtQuick

Item {
    id: root

    property string artUrlCache: ""
    readonly property string musicBarsService: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/System/services/music_bars.sh"
    readonly property string playerMonitorService: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/System/services/player_monitor.sh"
    property var    musicBars: [0, 0, 0, 0, 0, 0]
    readonly property var cavaBars: musicBars
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
    property bool _playerAvailabilityResetting: false

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
        musicBars = [0, 0, 0, 0, 0, 0]
        musicBarsProcess.running = false
    }

    function hideInactiveVisual() {
        shouldDisplayMusic = false
        isPlaying = false
        musicBars = [0, 0, 0, 0, 0, 0]
        musicBarsProcess.running = false
    }

    function scheduleInactiveReset() {
        inactiveTimer.restart()
    }

    function handlePlayerUnavailable() {
        inactiveTimer.stop()
        clearState()
    }

    function resetUnavailablePlayer() {
        if (_playerAvailabilityResetting)
            return

        _playerAvailabilityResetting = true
        playerMonitor.running = false
        root.handlePlayerUnavailable()
        retryTimer.restart()
        Qt.callLater(() => { root._playerAvailabilityResetting = false })
    }

    function ensureMonitoring() {
        if (!_playerMonitorStarting && !playerMonitor.running) {
            _playerMonitorStarting = true
            playerMonitor.running = false
            Qt.callLater(() => { playerMonitor.running = true })
        }
    }

    function ensureMusicBars() {
        if (!musicBarsProcess.running) {
            musicBarsProcess.running = false
            Qt.callLater(() => { musicBarsProcess.running = true })
        }
    }

    Process {
        id: dominantColor
        property string imagePath: ""
        command: [Qt.resolvedUrl("scripts/get-dominant-color.py").toString().replace("file://", ""), imagePath]
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
        id: musicBarsProcess
        command: [root.musicBarsService]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var frame = null
                try {
                    frame = JSON.parse(data)
                } catch (error) {
                    return
                }

                if (!frame || !frame.bands || frame.bands.length < 6)
                    return

                var nextBars = []
                for (var i = 0; i < 6; i++) {
                    var value = Number(frame.bands[i])
                    if (!isFinite(value))
                        value = 0
                    nextBars.push(Math.max(0, Math.min(100, Math.round(value * 100))))
                }
                root.musicBars = nextBars
            }
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => {}
        }
    }

    Process {
        id: playerMonitor
        command: ["bash", root.playerMonitorService]
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
                    root.ensureMusicBars()
                } else {
                    root.ensureMusicBars()
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
            } else if (!root._playerMonitorStarting && !root._playerAvailabilityResetting) {
                root.handlePlayerUnavailable()
                retryTimer.restart()
            }
        }
    }

    Process {
        id: playerAvailabilityCheck
        command: ["bash", "-c", "playerctl --player=spotify status >/dev/null 2>&1 && echo available || echo unavailable"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var state = data.trim()
                if (state === "unavailable")
                    root.resetUnavailablePlayer()
                else if (state === "available")
                    root.ensureMonitoring()
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
        interval: 15000
        repeat: false
        onTriggered: root.ensureMonitoring()
    }

    Timer {
        id: playerAvailabilityTimer
        interval: playerMonitor.running ? 30000 : 15000
        repeat: true
        running: true
        onTriggered: {
            if (!playerAvailabilityCheck.running)
                playerAvailabilityCheck.running = true
        }
    }

    Timer {
        id: inactiveTimer
        interval: 5000
        repeat: false
        onTriggered: root.hideInactiveVisual()
    }

    Component.onCompleted: ensureMonitoring()
}
