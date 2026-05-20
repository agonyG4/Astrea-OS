import QtQuick
import "../bar" as Bar
import "./modes/gamemode" as Gamemode
import "./modes/music" as Music

Rectangle {
    id: islandContent

    // ── Estado derivado ───────────────────────────────────────────
    readonly property bool isGamemodeNotify:       island.showGamemodeNotify
    readonly property bool isMouseOver:            mouseArea.hovered
    readonly property real flipScale:              Math.abs(Math.cos(island.artFlipAngle * Math.PI / 180))
    readonly property bool isNotch:                island.islandConfig.style === "Notch"

    // ── Dimensões ─────────────────────────────────────────────────
    width: {
        if (isGamemodeNotify)  return isNotch ? 210 : 100
        if (!island.hasMusic)
            return isNotch ? 210 : 120
        if (island.isExpanded)
            return isNotch ? 380 : 360
        if (!island.showCompactMusic)
            return isNotch ? 210 : 120
        return isNotch ? 210 : 180
    }
    height: {
        if (isGamemodeNotify)  return 100
        if (!island.hasMusic)
            return isNotch ? 32 : 34
        if (island.isExpanded)
            return 160
        if (!island.showCompactMusic)
            return isNotch ? 32 : 34
        return isNotch ? 32 : 34
    }

    property real currentRadius: {
        if (isGamemodeNotify)  return 32
        if (island.isExpanded) return (isNotch && !island.hasMusic) ? 17 : 32
        return 17
    }

    radius:            currentRadius
    color:             "transparent"
    clip:              true
    transformOrigin:   Item.Top
    scale:             pulseScale
    anchors {
        horizontalCenter: parent.horizontalCenter
        top:              parent.top
        topMargin:        isNotch ? 0 : 8
    }

    property real pulseScale: 1.0
    function triggerPulse() { islandPulse.start() }

    SequentialAnimation {
        id: islandPulse
        NumberAnimation { target: islandContent; property: "pulseScale"; to: 1.045; duration: 70;  easing.type: Easing.OutQuad }
        NumberAnimation { target: islandContent; property: "pulseScale"; to: 1.0;   duration: 480; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.56, 0.64, 1.0] }
    }

    Behavior on width         { NumberAnimation { duration: (island.isExpanded || isGamemodeNotify) ? flipAnim.containerExpandDuration  : flipAnim.containerCollapseDuration; easing.type: Easing.OutExpo } }
    Behavior on height        { NumberAnimation { duration: (island.isExpanded || isGamemodeNotify) ? flipAnim.containerExpandDuration  : flipAnim.containerCollapseDuration; easing.type: Easing.OutExpo } }
    Behavior on currentRadius { NumberAnimation { duration: flipAnim.radiusDuration; easing.type: Easing.OutExpo } }

    // ── Background ────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius:       parent.currentRadius
        color:        Bar.Theme.islandBackground

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height:  parent.radius
            color:   parent.color
            visible: islandContent.isNotch
        }

    }

    HoverHandler { id: mouseArea }

    // ── Compact: music bars ───────────────────────────────────────
    Music.MusicCompactBars {
        anchors.fill: parent
        active: !isGamemodeNotify && island.showCompactMusic && !isMouseOver
        bars: island.musicBars
        minHeight: island.musicBarsMinHeight
        maxHeight: island.musicBarsMaxHeightCompact
        tint: island.dominantCol
    }

    // ── Gamemode notify ───────────────────────────────────────────
    Gamemode.GamemodeNotifyView {
        anchors.fill: parent
        active: isGamemodeNotify
        fontFamily: Bar.Theme.fontFamilyDisplay
    }

    // ── Home: MusicView ───────────────────────────────────────────
    Music.MusicView {
        id: musicView
        anchors.fill: parent
    }

    // ── Floating album art ────────────────────────────────────────
    Music.MusicArtwork {
        id:      floatingArt
        active: island.hasMusic && !isGamemodeNotify && (island.showCompactMusic || island.isExpanded)
        expanded: island.isExpanded && island.hasMusic && !isGamemodeNotify
        artSource: island.artSource
        flipScale: islandContent.flipScale
        expandDuration: flipAnim.artExpandDuration
        collapseDuration: flipAnim.artCollapseDuration
    }
}
