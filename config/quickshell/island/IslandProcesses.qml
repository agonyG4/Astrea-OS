import Quickshell.Io
import QtQuick

Item {
    // ── API Pública ────────────────────────────────────────────────

    function setDominantColor(path) {
        dominantColor.imagePath = path
        dominantColor.running = false
        Qt.callLater(() => { dominantColor.running = true })
    }

    function playPause() { playerctlPlayPause.running = true }
    function next()      { playerctlNext.running = true }
    function prev()      { playerctlPrev.running = true }

    function clearIsland() {
        if (island.musicTitleText === "") return
        island.musicTitleText  = ""
        island.musicArtistText = ""
        island.isPlaying       = false
        island.artUrlCache     = ""
        island.artSource       = ""
        island.triggerArtFlip("", "")
        island.dominantCol     = "#ffffff"
        cavaProcess.running    = false
        _sinkInitialized       = false
    }

    // ── Estado Interno ─────────────────────────────────────────────
    property bool _sinkInitialized: false

    // ── Processos ──────────────────────────────────────────────────

    Process {
        id: dominantColor
        property string imagePath: ""
        command: [
            Qt.resolvedUrl("scripts/get-dominant-color.sh").toString().replace("file://", ""),
            imagePath
        ]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(" ")
                if (parts.length !== 3) return
                var r = parseInt(parts[0]), g = parseInt(parts[1]), b = parseInt(parts[2])
                if (isNaN(r) || isNaN(g) || isNaN(b)) return
                island.dominantCol = Qt.rgba(r/255, g/255, b/255, 1).toString()
            }
        }
    }

    Process {
        id: spotifySink
        command: ["bash", Qt.resolvedUrl("scripts/spotify-sink.sh").toString().replace("file://", "")]
        running: false
        stdout: SplitParser {
            onRead: _ => {
                cavaProcess.running = false
                Qt.callLater(() => { cavaProcess.running = true })
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
                var trimmed = data.trim()
                if (!trimmed) return
                var parts = trimmed.split(";")
                if (parts.length < 6) return
                for (var i = 0; i < 6; i++)
                    island.cavaBars[i] = parseInt(parts[i]) || 0
                island.cavaBarsChanged()
            }
        }
    }

    Process {
        id: playerMonitor
        command: [
            "playerctl", "--player=spotify", "metadata",
            "--format", "{{status}}|||{{title}}|||{{artist}}|||{{mpris:artUrl}}|||{{position}}|||{{mpris:length}}",
            "--follow"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var parts = data.split("|||")
                if (parts.length < 6) return

                var status = parts[0].trim().toLowerCase()
                var title  = parts[1].trim()
                var artist = parts[2].trim()
                var artUrl = (parts[3] || "").trim()
                var pos    = parseInt(parts[4]) || 0
                var len    = parseInt(parts[5]) || 1

                if (!title || status === "stopped") {
                    clearIsland()
                    return
                }

                island.isPlaying = (status === "playing")

                if (island.musicTitleText !== title) {
                    island.musicTitleText = title
                    if (!_sinkInitialized) {
                        _sinkInitialized = true
                        spotifySink.running = true
                    }
                }

                if (island.musicArtistText !== artist) island.musicArtistText = artist
                island.musicPosition = pos
                island.musicLength   = len

                if (artUrl === island.artUrlCache) return
                island.artUrlCache = artUrl

                if (!artUrl) {
                    island.triggerArtFlip("", "")
                    island.dominantCol = "#ffffff"
                } else if (artUrl.startsWith("http")) {
                    fetchArt.running = false
                    Qt.callLater(() => {
                        fetchArt._url = artUrl
                        fetchArt.running = true
                    })
                } else {
                    island.triggerArtFlip(artUrl, artUrl.replace("file://", ""))
                }
            }
        }

        stderr: SplitParser {
            onRead: data => {
                if (data.includes("No players found")) clearIsland()
            }
        }
    }

    Timer {
        id: retryTimer
        interval: 1500
        repeat: true
        running: !playerMonitor.running
        onTriggered: playerMonitor.running = true
    }

    Process {
        id: spotifyWatcher
        command: ["bash", "-c",
            "pid=$(pgrep -x spotify | head -1); [ -n \"$pid\" ] && tail --pid=$pid -f /dev/null"]
        running: true

        onRunningChanged: {
            if (running) return
            clearIsland()
            playerMonitor.running = false
            Qt.callLater(() => { playerMonitor.running = true })
            spotifyWatcherRetry.restart()
        }
    }

    Timer {
        id: spotifyWatcherRetry
        interval: 1500
        repeat: true
        onTriggered: {
            if (spotifyWatcher.running) {
                spotifyWatcherRetry.stop()
            } else {
                spotifyWatcher.running = true
            }
        }
    }

    // URL guardada como property — command tem binding correto
    Process {
        id: fetchArt
        property string _url: ""
        command: ["bash", "-c",
            "curl -sL --max-time 10 --output ~/.cache/island_art.jpg -- \"$1\" && echo ~/.cache/island_art.jpg",
            "--", _url]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var path = data.trim()
                if (!path) return
                island.triggerArtFlip("file://" + path + "?" + Date.now(), path)
                setDominantColor(path)
            }
        }
    }

    Process { id: playerctlPlayPause; command: ["playerctl", "--player=spotify", "play-pause"]; running: false }
    Process { id: playerctlNext;      command: ["playerctl", "--player=spotify", "next"];       running: false }
    Process { id: playerctlPrev;      command: ["playerctl", "--player=spotify", "previous"];   running: false }

    Process {
        id: gamemodeMonitor
        command: ["bash", "-c",
            "gamemoded -s 2>/dev/null | grep -q 'is active' && echo active || echo inactive;" +
            "while inotifywait -q -e modify /tmp/gamemode_status 2>/dev/null; do" +
            "  cat /tmp/gamemode_status; done"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                island.gamemodeActive = (data.trim() === "active")
            }
        }
    }
}