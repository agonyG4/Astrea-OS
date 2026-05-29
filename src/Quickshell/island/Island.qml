import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "."
import "./core" as Core
import "./effects" as Effects

PanelWindow {
    id: island
    property QtObject sharedMusicState: null
    property alias islandConfig: config
    property alias gamemodeActive: islandState.gamemodeActive
    property bool canRemapLayer: false
    property bool remapVisible: true
    
    anchors.top: true
    implicitWidth:  screen.width
    implicitHeight: islandConfig.enabled ? islandContent.height + 100 : 0
    color: "transparent"
    visible: islandConfig.enabled && remapVisible

    WlrLayershell.namespace:      "dynamic-island"
    // Keep the island on an interactive layer in both modes.
    // `Bottom` breaks hover/mouse because other top layers eat the input first.
    WlrLayershell.layer:          island.islandConfig.always_on_top ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.exclusiveZone:  -1
    WlrLayershell.keyboardFocus:  WlrLayershell.None

    mask: Region { item: islandContent }

    // ── Config ────────────────────────────────────────────────────
    Core.IslandConfig { id: config }
    Core.IslandState {
        id: islandState

        sharedMusicState: island.sharedMusicState
        musicEnabled: islandConfig.music
        gamemodeNotifyEnabled: islandConfig.show_gamemode_notify
        isExpanded: islandContent.isExpanded
        onFlipRequested: flipAnim.triggerFlip()
    }

    // ── Estado público / compatibilidade ─────────────────────────
    property alias artUrlCache: islandState.artUrlCache
    property alias musicBars: islandState.musicBars
    property alias cavaBars: islandState.cavaBars
    property alias dominantCol: islandState.dominantCol
    property alias musicPosition: islandState.musicPosition
    property alias musicLength: islandState.musicLength
    property alias smoothPosition: islandState.smoothPosition
    property alias musicTitleText: islandState.musicTitleText
    property alias musicArtistText: islandState.musicArtistText
    property alias shouldDisplayMusic: islandState.shouldDisplayMusic
    property alias artSource: islandState.artSource
    property alias isPlaying: islandState.isPlaying
    property alias musicBarsMinHeight: islandState.musicBarsMinHeight
    property alias musicBarsMaxHeightExpanded: islandState.musicBarsMaxHeightExpanded
    property alias musicBarsMaxHeightCompact: islandState.musicBarsMaxHeightCompact
    property alias cavaMinHeight: islandState.cavaMinHeight
    property alias cavaMaxHeightExpanded: islandState.cavaMaxHeightExpanded
    property alias cavaMaxHeightCompact: islandState.cavaMaxHeightCompact
    property alias activeMode: islandState.activeMode
    property alias hasMusic: islandState.hasMusic
    property alias showCompactMusic: islandState.showCompactMusic
    property alias isExpanded: islandState.isExpanded
    property alias musicBarsActive: islandState.musicBarsActive
    property alias cavaActive: islandState.cavaActive
    property alias showGamemodeNotify: islandState.showGamemodeNotify
    property alias artFlipPhase: islandState.artFlipPhase
    property alias artFlipDirection: islandState.artFlipDirection
    property alias artFlipAngle: islandState.artFlipAngle
    property alias pendingArtSource: islandState.pendingArtSource
    property alias isShuffle: islandState.isShuffle
    property alias isLoop: islandState.isLoop
    property alias isLoopTrack: islandState.isLoopTrack
    property alias isLoopPlaylist: islandState.isLoopPlaylist
    property alias loopMode: islandState.loopMode
    property alias targetArtSource: islandState.targetArtSource
    property alias targetArtPath: islandState.targetArtPath

    Connections {
        target: islandConfig
        function onAlways_on_topChanged() {
            if (!island.canRemapLayer)
                return

            island.remapVisible = false
            layerRemapTimer.restart()
        }
    }

    // ── Helpers ───────────────────────────────────────────────────
    function formatTime(us) {
        return islandState.formatTime(us)
    }

    function triggerArtFlip(newSource, localPath, direction) {
        islandState.triggerArtFlip(newSource, localPath, direction)
    }

    function syncPosition() {
        islandState.syncPosition()
    }

    // ── Timers / animações ────────────────────────────────────────
    Timer {
        id: layerRemapTimer
        interval: 1
        onTriggered: island.remapVisible = true
    }

    // ── Componentes ───────────────────────────────────────────────
    Core.IslandProcesses { id: procs }
    Effects.IslandAnimations { id: flipAnim }
    IslandContent {
        id: islandContent

        islandState: islandState
    }

    Component.onCompleted: canRemapLayer = true
}
