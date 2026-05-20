import Quickshell
import Quickshell.Io
import QtQuick
import "../services" as Services

Item {
    id: root

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
    property string legacyConfigFile:     Qt.resolvedUrl("../config/island.json").toString().replace("file://", "")
    property string stateDir:             Quickshell.env("HOME") + "/.local/state/Astrea/island"
    property string configFile:           stateDir + "/island.json"
    property string stateScript:          Qt.resolvedUrl("../scripts/island_state.py").toString().replace("file://", "")

    // ── Monitores de config / estado ───────────────────────────────
    Services.IslandConfigMonitor {
        id: configMonitor
        configFile: root.configFile
        legacyConfigFile: root.legacyConfigFile
        stateScript: root.stateScript
        onConfigChanged: function(c) {
            island.islandConfig.enabled              = c.enabled              ?? true
            island.islandConfig.always_on_top        = c.always_on_top        ?? true
            island.islandConfig.music                = c.music                ?? true
            island.islandConfig.show_gamemode_notify = c.show_gamemode_notify ?? false
            island.islandConfig.style                = c.style                ?? "Notch"
        }
    }

}
