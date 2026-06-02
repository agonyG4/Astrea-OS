import Quickshell
import Quickshell.Io
import QtQuick
import ".." as Modules

QtObject {
    id: root

    readonly property string statusPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/Astrea/status/audio.json"
    property int level: 50
    property bool muted: false
    property bool performancePaused: false
    property bool statusInitialized: false

    signal volumeChanged(int level, bool muted)

    function refresh() {
        statusBridge.refresh()
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
        root.volumeChanged(root.level, root.muted)
        volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", nextLevel + "%"]
        volSetProc.running = false
        volSetProc.running = true
    }

    function applyStatus(text) {
        try {
            var payload = JSON.parse(text || "{}")
            var nextLevel = payload.level !== undefined ? clampLevel(payload.level) : root.level
            var nextMuted = payload.muted === true
            var changed = root.statusInitialized && (nextLevel !== root.level || nextMuted !== root.muted)
            root.level = nextLevel
            root.muted = nextMuted
            if (changed)
                root.volumeChanged(root.level, root.muted)
            root.statusInitialized = true
        } catch (error) {
        }
    }

    property var volSetProc: Process {
        command: []
        running: false
    }

    property var statusBridge: Modules.StatusFile {
        statusPath: root.statusPath
        performancePaused: root.performancePaused
        startOnRefreshFailure: false
        signalName: "USR1"
        onLoaded: text => root.applyStatus(text)
    }
}
