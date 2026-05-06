import Quickshell
import Quickshell.Io
import QtQuick

Item {
    // ── Playback ───────────────────────────────────────────────────
    function playPause() {
        if (island.sharedMusicState)
            island.sharedMusicState.playPause()
    }

    function next() {
        if (island.sharedMusicState)
            island.sharedMusicState.next()
    }

    function prev() {
        if (island.sharedMusicState)
            island.sharedMusicState.prev()
    }

    function toggleShuffle() {
        if (island.sharedMusicState)
            island.sharedMusicState.toggleShuffle()
    }

    function toggleLoop() {
        if (island.sharedMusicState)
            island.sharedMusicState.toggleLoop()
    }

    function setPosition(targetPosMicroSec) {
        if (island.sharedMusicState)
            island.sharedMusicState.setPosition(targetPosMicroSec)
    }

    // ── Estado interno ─────────────────────────────────────────────
    property string legacyConfigFile:     Qt.resolvedUrl("config/island.json").toString().replace("file://", "")
    property string stateDir:             Quickshell.env("HOME") + "/.local/state/Astrea/island"
    property string configFile:           stateDir + "/island.json"

    // ── Monitores de config / estado ───────────────────────────────
    Process {
        id: gamemodeMonitor
        command: ["bash", "-c",
            "gamemoded -s 2>/dev/null | grep -q 'is active' && echo active || echo inactive;" +
            "while inotifywait -q -e modify /tmp/gamemode_status 2>/dev/null; do cat /tmp/gamemode_status; done"]
        running: true
        stdout: SplitParser { onRead: data => { island.gamemodeActive = data.trim() === "active" } }
    }

    Process {
        id: configMonitor
        command: ["bash", "-c",
            "FILE=\"$1\"; LEGACY=\"$2\";" +
            "mkdir -p \"$(dirname \"$FILE\")\";" +
            "if [ ! -f \"$FILE\" ]; then " +
            "  if [ -f \"$LEGACY\" ]; then cp \"$LEGACY\" \"$FILE\"; " +
            "  else printf '%s\n' '{' '    \"enabled\": true,' '    \"always_on_top\": true,' '    \"music\": true,' '    \"show_gamemode_notify\": false,' '    \"style\": \"Notch\"' '}' > \"$FILE\"; " +
            "  fi; " +
            "fi;" +
            "cat \"$FILE\" | tr '\\n' ' '; echo;" +
            "while inotifywait -q -e modify \"$FILE\" 2>/dev/null; do cat \"$FILE\" | tr '\\n' ' '; echo; done",
            "--", configFile, legacyConfigFile]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    var c = JSON.parse(data.trim())
                    island.islandConfig.enabled              = c.enabled              ?? true
                    island.islandConfig.always_on_top        = c.always_on_top        ?? true
                    island.islandConfig.music                = c.music                ?? true
                    island.islandConfig.show_gamemode_notify = c.show_gamemode_notify ?? false
                    island.islandConfig.style                = c.style                ?? "Notch"
                } catch(e) {}
            }
        }
    }

}
