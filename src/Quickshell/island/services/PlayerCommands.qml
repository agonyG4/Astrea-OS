import Quickshell.Io
import QtQuick

Item {
    id: root

    function restart(process) {
        process.running = false
        Qt.callLater(() => { process.running = true })
    }

    function playPause() {
        restart(playerctlPlayPause)
    }

    function next() {
        restart(playerctlNext)
    }

    function prev() {
        restart(playerctlPrev)
    }

    function toggleShuffle() {
        restart(playerctlShuffle)
    }

    function toggleLoop(currentMode) {
        var nextMode = (currentMode === "" || currentMode === "none") ? "playlist" : currentMode === "playlist" ? "track" : "none"
        playerctlLoop.nextMode = nextMode === "playlist" ? "Playlist" : nextMode === "track" ? "Track" : "None"
        restart(playerctlLoop)
        return nextMode
    }

    function setPosition(targetPosMicroSec) {
        playerctlSeek.targetPosSec = targetPosMicroSec / 1000000
        restart(playerctlSeek)
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
}
