import QtQuick

Item {
    id: root

    property QtObject sharedMusicState: null
    property bool musicEnabled: true
    property bool isExpanded: false
    property bool gamemodeActive: false
    property bool gamemodeNotifyEnabled: false

    signal flipRequested()

    readonly property string artUrlCache: sharedMusicState ? sharedMusicState.artUrlCache : ""
    readonly property var musicBars: sharedMusicState ? sharedMusicState.musicBars : [0, 0, 0, 0, 0, 0]
    readonly property var cavaBars: musicBars
    readonly property string dominantCol: sharedMusicState ? sharedMusicState.dominantCol : "#ffffff"
    readonly property real musicPosition: sharedMusicState ? sharedMusicState.musicPosition : 0
    readonly property real musicLength: sharedMusicState ? sharedMusicState.musicLength : 1
    property real smoothPosition: 0
    readonly property string musicTitleText: sharedMusicState ? sharedMusicState.musicTitleText : ""
    readonly property string musicArtistText: sharedMusicState ? sharedMusicState.musicArtistText : ""
    readonly property bool shouldDisplayMusic: sharedMusicState ? sharedMusicState.shouldDisplayMusic : false
    property string artSource: ""
    readonly property bool isPlaying: sharedMusicState ? sharedMusicState.isPlaying : false

    property int musicBarsMinHeight: 4
    property int musicBarsMaxHeightExpanded: 32
    property int musicBarsMaxHeightCompact: 18
    property int cavaMinHeight: musicBarsMinHeight
    property int cavaMaxHeightExpanded: musicBarsMaxHeightExpanded
    property int cavaMaxHeightCompact: musicBarsMaxHeightCompact

    readonly property string activeMode: modeRouter.activeMode
    readonly property bool hasMusic: modeRouter.hasMusic
    readonly property bool showCompactMusic: modeRouter.showCompactMusic
    property bool showGamemodeNotify: false
    readonly property bool musicBarsActive: hasMusic && !showGamemodeNotify
    readonly property bool cavaActive: musicBarsActive

    property int artFlipPhase: 0
    property int artFlipDirection: 1
    property real artFlipAngle: 0
    property string pendingArtSource: ""

    readonly property bool isShuffle: sharedMusicState ? sharedMusicState.isShuffle : false
    readonly property bool isLoop: sharedMusicState ? sharedMusicState.isLoop : false
    readonly property bool isLoopTrack: sharedMusicState ? sharedMusicState.isLoopTrack : false
    readonly property bool isLoopPlaylist: sharedMusicState ? sharedMusicState.isLoopPlaylist : false
    readonly property string loopMode: sharedMusicState ? sharedMusicState.loopMode : "none"
    readonly property string targetArtSource: sharedMusicState ? sharedMusicState.artSource : ""
    readonly property string targetArtPath: sharedMusicState ? sharedMusicState.artPath : ""

    IslandModeRouter {
        id: modeRouter

        musicEnabled: root.musicEnabled
        musicTitle: root.musicTitleText
        shouldDisplayMusic: root.shouldDisplayMusic
        notifyVisible: root.showGamemodeNotify
    }

    Binding on smoothPosition {
        when: root.isExpanded && root.isPlaying && root.musicLength > root.musicPosition
        value: root.musicPosition
        restoreMode: Binding.RestoreNone
    }

    onIsExpandedChanged: if (isExpanded) syncPosition()
    onMusicPositionChanged: syncPosition()
    onIsPlayingChanged: syncPosition()
    onMusicTitleTextChanged: {
        smoothPositionAnim.stop()
        smoothPosition = 0
    }
    onTargetArtSourceChanged: {
        if (!targetArtSource) {
            artSource = ""
            pendingArtSource = ""
            return
        }
        triggerArtFlip(targetArtSource, targetArtPath)
    }
    onGamemodeActiveChanged: maybeShowGamemodeNotify()
    onGamemodeNotifyEnabledChanged: {
        if (!gamemodeNotifyEnabled)
            showGamemodeNotify = false
    }

    function formatTime(us) {
        const s = Math.floor(us / 1000000)
        const m = Math.floor(s / 60)
        return m + ":" + String(s % 60).padStart(2, "0")
    }

    function triggerArtFlip(newSource, localPath, direction) {
        if (direction !== undefined)
            artFlipDirection = direction
        if (newSource === artSource && pendingArtSource === "")
            return
        if (artFlipPhase !== 0) {
            pendingArtSource = newSource
            return
        }
        pendingArtSource = newSource
        flipRequested()
    }

    function syncPosition() {
        smoothPositionAnim.stop()
        smoothPosition = musicPosition
        if (isExpanded && isPlaying && musicLength > musicPosition) {
            smoothPositionAnim.to = musicLength
            smoothPositionAnim.duration = (musicLength - musicPosition) / 1000
            smoothPositionAnim.start()
        }
    }

    function maybeShowGamemodeNotify() {
        if (gamemodeActive && gamemodeNotifyEnabled) {
            showGamemodeNotify = true
            gamemodeNotifyTimer.restart()
        }
    }

    Timer {
        id: gamemodeNotifyTimer

        interval: 3000
        onTriggered: root.showGamemodeNotify = false
    }

    NumberAnimation {
        id: smoothPositionAnim

        target: root
        property: "smoothPosition"
        easing.type: Easing.Linear
        duration: 0
        to: 0
    }
}
