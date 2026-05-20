import Quickshell.Io
import Quickshell
import QtQuick
import "../../services" as Services

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
    property bool   performancePaused: false
    property string loopMode: "none"

    property bool _playerMonitorStarting: false
    property bool _playerAvailabilityResetting: false
    property var _dominantColorCache: ({})

    function setDominantColor(path, cacheKey) {
        if (!path) {
            dominantCol = "#ffffff"
            return
        }

        var key = cacheKey || path
        if (_dominantColorCache[key]) {
            dominantCol = _dominantColorCache[key]
            return
        }

        if (dominantColor.running && dominantColor.imagePath === path)
            return

        dominantColor.start(path, key)
    }

    function playPause() {
        playerCommands.playPause()
    }

    function next() {
        playerCommands.next()
    }

    function prev() {
        playerCommands.prev()
    }

    function toggleShuffle() {
        playerCommands.toggleShuffle()
    }

    function toggleLoop() {
        var next = playerCommands.toggleLoop(loopMode)
        loopMode = next
        isLoop = next !== "none"
        isLoopTrack = next === "track"
        isLoopPlaylist = next === "playlist"
    }

    function setPosition(targetPosMicroSec) {
        playerCommands.setPosition(targetPosMicroSec)
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
        musicBarsProcess.stop()
    }

    function hideInactiveVisual() {
        shouldDisplayMusic = false
        isPlaying = false
        musicBarsProcess.stop()
    }

    function scheduleInactiveReset() {
        inactiveTimer.restart()
    }

    function handlePlayerUnavailable() {
        inactiveTimer.stop()
        clearState()
    }

    function suspendForPerformance() {
        retryTimer.stop()
        inactiveTimer.stop()
        playerAvailabilityCheck.running = false
        playerMonitor.running = false
        musicBarsProcess.stop()
        dominantColor.running = false
        fetchArt.running = false
        shouldDisplayMusic = false
        isPlaying = false
    }

    function resumeAfterPerformance() {
        playerAvailabilityCheck.running = false
        ensureMonitoring()
    }

    function resetUnavailablePlayer() {
        if (performancePaused || _playerAvailabilityResetting)
            return

        _playerAvailabilityResetting = true
        playerMonitor.running = false
        root.handlePlayerUnavailable()
        retryTimer.restart()
        Qt.callLater(() => { root._playerAvailabilityResetting = false })
    }

    function ensureMonitoring() {
        if (performancePaused)
            return

        if (!_playerMonitorStarting && !playerMonitor.running) {
            _playerMonitorStarting = true
            playerMonitor.running = false
            Qt.callLater(() => { playerMonitor.running = true })
        }
    }

    function ensureMusicBars() {
        if (performancePaused) {
            musicBarsProcess.stop()
            return
        }

        if (!root.isPlaying || !root.shouldDisplayMusic) {
            musicBarsProcess.stop()
            return
        }

        if (!musicBarsProcess.running)
            Qt.callLater(() => { if (root.isPlaying && root.shouldDisplayMusic) musicBarsProcess.running = true })
    }

    Services.DominantColorProcess {
        id: dominantColor
        scriptPath: Qt.resolvedUrl("../../scripts/get-dominant-color.py").toString().replace("file://", "")
        onColorReady: function(color, cacheKey, imagePath) {
            root.dominantCol = color
            var cache = Object.assign({}, root._dominantColorCache)
            cache[cacheKey || imagePath] = color
            root._dominantColorCache = cache
        }
    }

    onPerformancePausedChanged: {
        if (performancePaused)
            suspendForPerformance()
        else
            resumeAfterPerformance()
    }

    Services.MusicBarsProcess {
        id: musicBarsProcess
        commandPath: root.musicBarsService
        onBarsChanged: root.musicBars = bars
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
                    fetchArt.fetch(artUrl)
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
            } else if (!root.performancePaused && !root._playerMonitorStarting && !root._playerAvailabilityResetting) {
                root.handlePlayerUnavailable()
                retryTimer.restart()
            }
        }
    }

    Process {
        id: playerAvailabilityCheck
        command: ["playerctl", "--player=spotify", "status"]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0)
                root.ensureMonitoring()
            else
                root.resetUnavailablePlayer()
        }
    }

    Services.ArtworkFetcher {
        id: fetchArt
        scriptPath: Qt.resolvedUrl("../../scripts/fetch_art.py").toString().replace("file://", "")
        onFetched: function(path, url) {
            root.artSource = "file://" + path + "?" + Date.now()
            root.artPath = path
            root.setDominantColor(path, url)
        }
    }

    Services.PlayerCommands {
        id: playerCommands
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
        running: !root.performancePaused
        onTriggered: {
            if (!root.performancePaused && !playerAvailabilityCheck.running)
                playerAvailabilityCheck.running = true
        }
    }

    Timer {
        id: inactiveTimer
        interval: 5000
        repeat: false
        onTriggered: root.hideInactiveVisual()
    }

    Component.onCompleted: if (!performancePaused) ensureMonitoring()
}
