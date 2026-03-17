import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "."

PanelWindow {
        id: island

        anchors.top: true
        implicitWidth: screen.width
        implicitHeight: islandContent.height + 100
        color: "transparent"

        WlrLayershell.namespace: "dynamic-island"
        // WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrLayershell.None

        mask: Region { item: islandContent }

        // ── Estado global ─────────────────────────────────────────────
        property string artUrlCache:    ""
        property var    cavaBars:       [0, 0, 0, 0, 0, 0]
        property string dominantCol:    "#ffffff"
        property real   musicPosition:  0
        property real   musicLength:    1
        property real   smoothPosition: 0
        property string musicTitleText:  ""
        property string musicArtistText: ""
        property string artSource:       ""
        property bool   isPlaying:       false
        property int    cavaMinHeight:         4
        property int    cavaMaxHeightExpanded: 32
        property int    cavaMaxHeightCompact:  18

        property bool hasMusic:           musicTitleText !== ""
        property bool isExpanded:         islandContent.isMouseOver
        property bool cavaActive:         hasMusic && !showGamemodeNotify

        property bool gamemodeActive:     false
        property bool showGamemodeNotify: false

        // ── Flip state ────────────────────────────────────────────────
        property int    artFlipPhase:     0
        property real   artFlipAngle:     0
        property string pendingArtSource: ""

        // ── Handlers ──────────────────────────────────────────────────
        onIsExpandedChanged:    { if (isExpanded) syncPosition() }
        onMusicPositionChanged: syncPosition()
        onIsPlayingChanged:     syncPosition()

        onMusicTitleTextChanged: {
            smoothPositionAnim.stop()
            smoothPosition = 0
            musicPosition  = 0
            musicLength    = 1
        }

        onGamemodeActiveChanged: {
            if (gamemodeActive) {
                showGamemodeNotify = true
                gamemodeNotifyTimer.restart()
            }
        }

        // ── Helpers ───────────────────────────────────────────────────
        function formatTime(us) {
            var s = Math.floor(us / 1000000)
            var m = Math.floor(s / 60)
            s = s % 60
            return m + ":" + (s < 10 ? "0" + s : s)
        }

        function triggerArtFlip(newSource, localPath) {
            if (artFlipPhase !== 0) { pendingArtSource = newSource; return }
            if (newSource === artSource) return
            pendingArtSource = newSource
            artFlipPhase = 1
            flipAnim.triggerFlip()  // corrigido: era .hide()
            if (localPath !== "") procs.setDominantColor(localPath)
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

        function playPause() { procs.playPause() }
        function next()      { procs.next() }
        function prev()      { procs.prev() }

        // ── Timers e animações ────────────────────────────────────────
        Timer {
            id: gamemodeNotifyTimer
            interval: 3000
            repeat: false
            onTriggered: island.showGamemodeNotify = false
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