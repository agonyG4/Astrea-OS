import Quickshell.Io
import QtQuick

Item {
    // ── Funções Públicas ───────────────────────────────────────────
    function setDominantColor(path) {
        dominantColor.imagePath = path
        dominantColor.running = false
        Qt.callLater(() => { dominantColor.running = true })
    }

    function playPause() { playerctlPlayPause.running = true }
    function next()      { playerctlNext.running = true }
    function prev()      { playerctlPrev.running = true }

    function clearIsland() {
        if (island.musicTitleText !== "") {
            island.musicTitleText  = ""
            island.musicArtistText = ""
            island.isPlaying       = false
            island.artUrlCache     = ""
            island.artSource       = ""
            island.triggerArtFlip("", "")
            island.dominantCol     = "#ffffff"
            cavaProcess.running    = false
        }
    }

    // ── Processos ──────────────────────────────────────────────────

    // Cor dominante da capa
    Process {
        id: dominantColor
        property string imagePath: ""
        command: [Qt.resolvedUrl("scripts/get-dominant-color.sh").toString().replace("file://", ""), imagePath]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(" ")
                if (parts.length === 3) {
                    var r = parseInt(parts[0]), g = parseInt(parts[1]), b = parseInt(parts[2])
                    island.dominantCol = Qt.rgba(r/255, g/255, b/255, 1).toString()
                }
            }
        }
    }

    // Sink do CAVA
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

    // CAVA
    Process {
        id: cavaProcess
        command: ["cava", "-p", Qt.resolvedUrl("config/cava.conf").toString().replace("file://", "")]
        running: island.cavaActive
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var trimmed = data.trim()
                if (!trimmed) return
                var parts = trimmed.split(";")
                if (parts.length < 6) return
                for (var i = 0; i < 6; i++) island.cavaBars[i] = parseInt(parts[i]) || 0
                island.cavaBarsChanged()
            }
        }
    }

    // Monitor principal do Spotify
    Process {
        id: playerMonitor
        command: ["playerctl", "--player=spotify", "metadata",
                  "--format", "{{status}}|||{{title}}|||{{artist}}|||{{mpris:artUrl}}|||{{position}}|||{{mpris:length}}", "--follow"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var parts  = data.split("|||")
                if (parts.length < 6) return

                var status = parts[0].trim().toLowerCase()
                var title  = parts[1].trim()
                var artist = parts[2].trim()
                var artUrl = (parts[3] || "").trim()
                var pos    = parseInt(parts[4]) || 0
                var len    = parseInt(parts[5]) || 1

                if (title === "" || status === "stopped") {
                    clearIsland()
                    return
                }

                island.isPlaying = (status === "playing")

                if (island.musicTitleText !== title) {
                    var wasEmpty = (island.musicTitleText === "")
                    island.musicTitleText = title
                    if (wasEmpty) spotifySink.running = true
                }

                if (island.musicArtistText !== artist) island.musicArtistText = artist
                island.musicPosition = pos
                island.musicLength   = len

                if (artUrl !== island.artUrlCache) {
                    island.artUrlCache = artUrl
                    if (artUrl.startsWith("http")) {
                        fetchArt.running = false
                        Qt.callLater(() => { fetchArt.running = true })
                    } else if (artUrl !== "") {
                        island.triggerArtFlip(artUrl, artUrl.replace("file://", ""))
                    } else {
                        island.triggerArtFlip("", "")
                        island.dominantCol = "#ffffff"
                    }
                }
            }
        }

        stderr: SplitParser {
            onRead: data => {
                if (data.includes("No players found")) clearIsland()
            }
        }
    }

    // Retry do playerMonitor
    Timer {
        id: retryTimer
        interval: 1500
        repeat: true
        running: !playerMonitor.running
        onTriggered: playerMonitor.running = true
    }

    // Watcher do processo Spotify via tail --pid
    // Zero overhead — o kernel avisa quando o processo morre, sem polling
    Process {
        id: spotifyWatcher
        command: ["bash", "-c", "pid=$(pgrep -x spotify | head -1); [ -n \"$pid\" ] && tail --pid=$pid -f /dev/null"]
        running: true

        onRunningChanged: {
            if (!running) {
                clearIsland()
                playerMonitor.running = false
                Qt.callLater(() => { playerMonitor.running = true })
                spotifyWatcherRetry.restart()
            }
        }
    }

    // Retry do watcher até o Spotify abrir de novo
    Timer {
        id: spotifyWatcherRetry
        interval: 1500
        repeat: true
        onTriggered: {
            if (!spotifyWatcher.running) spotifyWatcher.running = true
            else spotifyWatcherRetry.stop()
        }
    }

    // Arte da web
    Process {
        id: fetchArt
        command: ["bash", "-c", "curl -sL '" + island.artUrlCache + "' -o ~/.cache/island_art.jpg && echo ~/.cache/island_art.jpg"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var path = data.trim()
                island.triggerArtFlip("file://" + path + "?" + Date.now(), path)
            }
        }
    }

    // Comandos rápidos
    Process { id: playerctlPlayPause; command: ["playerctl", "--player=spotify", "play-pause"]; running: false }
    Process { id: playerctlNext;      command: ["playerctl", "--player=spotify", "next"];       running: false }
    Process { id: playerctlPrev;      command: ["playerctl", "--player=spotify", "previous"];   running: false }

    // Gamemode monitor
    Process {
        id: gamemodeMonitor
        command: ["bash", "-c", "if gamemoded -s | grep -q 'is active'; then echo 'active'; else echo 'inactive'; fi; tail -F /tmp/gamemode_status 2>/dev/null"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                island.gamemodeActive = (data.trim() === "active")
            }
        }
    }
}
