import QtQuick
import Qt5Compat.GraphicalEffects
import "../bar" as Bar

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
    Item {
        anchors.fill: parent
        visible:      opacity > 0
        opacity:      (!isGamemodeNotify && island.showCompactMusic && !isMouseOver) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Row {
            spacing: 3
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }

            Repeater {
                model: 6
                Item {
                    width: 3; height: 20
                    Rectangle {
                        width:  3
                        height: Math.min(island.musicBarsMaxHeightCompact, Math.max(island.musicBarsMinHeight, island.musicBars[index] / 100 * 18))
                        radius: 2
                        anchors.centerIn: parent
                        color:  island.dominantCol
                        Behavior on height { NumberAnimation { duration: 60;  easing.type: Easing.OutSine } }
                        Behavior on color  { ColorAnimation  { duration: 800 } }
                    }
                }
            }
        }
    }

    // ── Gamemode notify ───────────────────────────────────────────
    Item {
        anchors.fill: parent
        visible:      opacity > 0
        opacity:      isGamemodeNotify ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text:             "🎮"
            font.family:       Bar.Theme.fontFamilyDisplay
            font.pixelSize:    48
            antialiasing:      true
            renderType:        Text.NativeRendering
            RotationAnimation on rotation {
                from: 0; to: 360; duration: 1500
                loops: Animation.Infinite; running: isGamemodeNotify
            }
        }
    }

    // ── Home: MusicView ───────────────────────────────────────────
    MusicView {
        id: musicView
        anchors.fill: parent
    }

    // ── Floating album art ────────────────────────────────────────
    Item {
        id:      floatingArt
        visible: opacity > 0
        opacity: (island.hasMusic && !isGamemodeNotify && (island.showCompactMusic || island.isExpanded)) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        readonly property bool artExpanded: island.isExpanded && island.hasMusic && !isGamemodeNotify

        Rectangle {
            id:      artClipMask
            anchors.fill: parent
            radius:  floatingArt.artExpanded ? 12 : floatingArt.width / 2
            visible: false
            Behavior on radius { NumberAnimation { duration: floatingArt.artExpanded ? flipAnim.artExpandDuration : flipAnim.artCollapseDuration; easing.type: Easing.OutExpo } }
        }

        Item {
            anchors.fill: parent
            transform: Scale {
                origin.x: floatingArt.width  / 2
                origin.y: floatingArt.height / 2
                xScale:   islandContent.flipScale
            }
            Image {
                anchors.fill: parent
                source:       island.artSource
                fillMode:     Image.PreserveAspectCrop
                smooth: true; mipmap: true; cache: false; asynchronous: true
                opacity: source === "" || status === Image.Loading ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 150 } }
                layer.enabled: true
                layer.effect:  OpacityMask { maskSource: artClipMask }
            }
        }

        states: [
            State {
                name: "expanded"; when: floatingArt.artExpanded
                PropertyChanges { target: floatingArt; x: 18; y: 18; width: 60; height: 60 }
            },
            State {
                name: "compact"; when: !floatingArt.artExpanded
                PropertyChanges { target: floatingArt; x: 8; y: 7; width: 20; height: 20 }
            }
        ]
        transitions: [
            Transition {
                from: "compact"; to: "expanded"
                NumberAnimation { properties: "x,y,width,height";    duration: flipAnim.artExpandDuration;   easing.type: Easing.OutExpo }
                NumberAnimation { target: artClipMask; property: "radius"; duration: flipAnim.artExpandDuration;   easing.type: Easing.OutExpo }
            },
            Transition {
                from: "expanded"; to: "compact"
                NumberAnimation { properties: "x,y,width,height";    duration: flipAnim.artCollapseDuration; easing.type: Easing.OutExpo }
                NumberAnimation { target: artClipMask; property: "radius"; duration: flipAnim.artCollapseDuration; easing.type: Easing.OutExpo }
            }
        ]
    }
}
