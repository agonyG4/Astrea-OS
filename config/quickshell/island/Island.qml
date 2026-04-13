import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "."

PanelWindow {
    id: island
    property QtObject sharedMusicState: null
    
    anchors.top: true
    implicitWidth:  screen.width
    implicitHeight: islandConfig.enabled ? islandContent.height + 100 : 0
    color: "transparent"
    visible: islandConfig.enabled

    WlrLayershell.namespace:      "dynamic-island"
    WlrLayershell.layer:          islandConfig.always_on_top ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.exclusiveZone:  -1
    WlrLayershell.keyboardFocus:  WlrLayershell.None

    mask: Region { item: islandContent }

// ── Config ────────────────────────────────────────────────────
property QtObject islandConfig: QtObject {
    property bool   enabled:              true
    property bool   always_on_top:        true
    property bool   music:                true
    property bool   show_gamemode_notify: false
    property string style:                "Notch"  // ou "Notch"
}
    // ── Estado ───────────────────────────────────────────────────
    readonly property string artUrlCache: sharedMusicState ? sharedMusicState.artUrlCache : ""
    readonly property var    cavaBars: sharedMusicState ? sharedMusicState.cavaBars : [0, 0, 0, 0, 0, 0]
    readonly property string dominantCol: sharedMusicState ? sharedMusicState.dominantCol : "#ffffff"
    readonly property real   musicPosition: sharedMusicState ? sharedMusicState.musicPosition : 0
    readonly property real   musicLength: sharedMusicState ? sharedMusicState.musicLength : 1
    property real   smoothPosition: 0
    readonly property string musicTitleText: sharedMusicState ? sharedMusicState.musicTitleText : ""
    readonly property string musicArtistText: sharedMusicState ? sharedMusicState.musicArtistText : ""
    readonly property bool   shouldDisplayMusic: sharedMusicState ? sharedMusicState.shouldDisplayMusic : false
    property string artSource:       ""
    readonly property bool   isPlaying: sharedMusicState ? sharedMusicState.isPlaying : false
    property int    cavaMinHeight:         4
    property int    cavaMaxHeightExpanded: 32
    property int    cavaMaxHeightCompact:  18

    property bool idleHidden:         false
    property bool hasMusic:           islandConfig.music && musicTitleText !== ""
    property bool showCompactMusic:   hasMusic && shouldDisplayMusic && !idleHidden
    property bool isExpanded:         islandContent.isMouseOver
    property bool cavaActive:         hasMusic && !showGamemodeNotify
    property bool gamemodeActive:     false
    property bool showGamemodeNotify: false
    property var  droppedImages:      []
    property bool hasDroppedImages:   droppedImages.length > 0

    property string activeTab: "home"

    // ── Flip ──────────────────────────────────────────────────────
    property int    artFlipPhase:     0
    property int    artFlipDirection: 1
    property real   artFlipAngle:     0
    property string pendingArtSource: ""

    // ── Playback ──────────────────────────────────────────────────
    readonly property bool   isShuffle: sharedMusicState ? sharedMusicState.isShuffle : false
    readonly property bool   isLoop: sharedMusicState ? sharedMusicState.isLoop : false
    readonly property bool   isLoopTrack: sharedMusicState ? sharedMusicState.isLoopTrack : false
    readonly property bool   isLoopPlaylist: sharedMusicState ? sharedMusicState.isLoopPlaylist : false
    readonly property string loopMode: sharedMusicState ? sharedMusicState.loopMode : "none"
    readonly property string targetArtSource: sharedMusicState ? sharedMusicState.artSource : ""
    readonly property string targetArtPath: sharedMusicState ? sharedMusicState.artPath : ""

    // ── Bindings ──────────────────────────────────────────────────
    Binding on smoothPosition {
        when:  isExpanded && isPlaying && musicLength > musicPosition
        value: musicPosition
        restoreMode: Binding.RestoreNone
    }

    onIsExpandedChanged: { if (isExpanded) syncPosition(); else if (!hasDroppedImages) activeTab = "home" }
    onMusicPositionChanged: syncPosition()
    onIsPlayingChanged: {
        syncPosition()
        if (isPlaying) {
            pauseIdleTimer.stop()
            idleHidden = false
        } else if (musicTitleText !== "") {
            pauseIdleTimer.restart()
        }
    }
    onMusicTitleTextChanged: {
        smoothPositionAnim.stop()
        smoothPosition = 0
        if (musicTitleText !== "")
            idleHidden = false
    }
    onTargetArtSourceChanged: {
        if (!targetArtSource) {
            artSource = ""
            pendingArtSource = ""
            return
        }
        triggerArtFlip(targetArtSource, targetArtPath)
    }
    onGamemodeActiveChanged: {
        if (gamemodeActive && islandConfig.show_gamemode_notify) {
            showGamemodeNotify = true
            gamemodeNotifyTimer.restart()
        }
    }

    // ── Helpers ───────────────────────────────────────────────────
    function formatTime(us) {
        const s = Math.floor(us / 1_000_000)
        const m = Math.floor(s / 60)
        return m + ":" + String(s % 60).padStart(2, "0")
    }

    function triggerArtFlip(newSource, localPath, direction) {
        if (direction !== undefined) artFlipDirection = direction
        if (newSource === artSource && pendingArtSource === "") return
        if (artFlipPhase !== 0) { pendingArtSource = newSource; return }
        pendingArtSource = newSource
        flipAnim.triggerFlip()
    }

    function syncPosition() {
        smoothPositionAnim.stop()
        smoothPosition = musicPosition
        if (isExpanded && isPlaying && musicLength > musicPosition) {
            smoothPositionAnim.to       = musicLength
            smoothPositionAnim.duration = (musicLength - musicPosition) / 1000
            smoothPositionAnim.start()
        }
    }

    // ── Timers / animações ────────────────────────────────────────
    Timer {
        id: gamemodeNotifyTimer
        interval: 3000
        onTriggered: island.showGamemodeNotify = false
    }

    Timer {
        id: pauseIdleTimer
        interval: 15000
        onTriggered: island.idleHidden = true
    }

    NumberAnimation {
        id: smoothPositionAnim
        target: island; property: "smoothPosition"
        easing.type: Easing.Linear
        duration: 0; to: 0
    }

    // ── Componentes ───────────────────────────────────────────────
    IslandProcesses  { id: procs }
    IslandAnimations { id: flipAnim }
    IslandContent    { id: islandContent }
}
