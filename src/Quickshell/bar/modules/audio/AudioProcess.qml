import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    readonly property string statusPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/Astrea/status/audio.json"
    property int level: 50
    property bool muted: false

    function refresh() {
        statusRefreshProc.running = false
        statusRefreshProc.running = true
    }

    function clampLevel(value) {
        var parsed = Math.round(Number(value))
        if (!isFinite(parsed))
            parsed = root.level
        return Math.max(0, Math.min(150, parsed))
    }

    function setVolume(value) {
        var nextLevel = clampLevel(value)
        root.level = nextLevel
        volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", nextLevel + "%"]
        volSetProc.running = false
        volSetProc.running = true
    }

    function applyStatus(text) {
        try {
            var payload = JSON.parse(text || "{}")
            root.level = payload.level !== undefined ? clampLevel(payload.level) : root.level
            root.muted = payload.muted === true
        } catch (error) {
        }
    }

    property var statusFile: FileView {
        path: root.statusPath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyStatus(text())
    }

    property var volSetProc: Process {
        command: []
        running: false
        onExited: root.refresh()
    }

    property var statusRefreshProc: Process {
        command: ["systemctl", "--user", "kill", "-s", "USR1", "astrea-status.service"]
        running: false
        onExited: statusFile.reload()
    }
}
