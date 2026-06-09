import QtQuick
import "."
import "../bar" as Bar
import "./core" as Core

Rectangle {
    id: islandContent

    property QtObject islandState: null

    // ── Estado derivado ───────────────────────────────────────────
    readonly property bool isGamemodeNotify:       island.showGamemodeNotify
    readonly property bool isEmailCodeNotify:      island.showEmailCodeNotify
    readonly property bool isMouseOver:            interaction.hovered
    readonly property bool isExpanded:             interaction.expanded
    readonly property real flipScale:              Math.abs(Math.cos(island.artFlipAngle * Math.PI / 180))
    readonly property bool isNotch:                geometry.isNotch

    // ── Dimensões ─────────────────────────────────────────────────
    Core.IslandGeometry {
        id: geometry

        style: island.islandConfig.style
        hasMusic: island.hasMusic
        isExpanded: island.isExpanded
        showCompactMusic: island.showCompactMusic
        showGamemodeNotify: islandContent.isGamemodeNotify
        showEmailCodeNotify: island.showEmailCodeNotify
    }

    width:             geometry.width
    height:            geometry.height
    radius:            geometry.radius
    color:             "transparent"
    clip:              true
    transformOrigin:   Item.Top
    scale:             pulseScale
    anchors {
        horizontalCenter: parent.horizontalCenter
        top:              parent.top
        topMargin:        geometry.topMargin
    }

    property real pulseScale: 1.0
    function triggerPulse() { islandPulse.start() }

    SequentialAnimation {
        id: islandPulse
        NumberAnimation { target: islandContent; property: "pulseScale"; to: 1.045; duration: 70;  easing.type: Easing.OutQuad }
        NumberAnimation { target: islandContent; property: "pulseScale"; to: 1.0;   duration: 480; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.56, 0.64, 1.0] }
    }

    Behavior on width  { NumberAnimation { duration: geometry.isExpandedOrNotify ? flipAnim.containerExpandDuration : flipAnim.containerCollapseDuration; easing.type: Easing.OutExpo } }
    Behavior on height { NumberAnimation { duration: geometry.isExpandedOrNotify ? flipAnim.containerExpandDuration : flipAnim.containerCollapseDuration; easing.type: Easing.OutExpo } }
    Behavior on radius { NumberAnimation { duration: flipAnim.radiusDuration; easing.type: Easing.OutExpo } }

    // ── Background ────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius:       parent.radius
        color:        Bar.Theme.islandBackground

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height:  parent.radius
            color:   parent.color
            visible: islandContent.isNotch
        }

    }

    Core.IslandInteraction {
        id: interaction
    }

    IslandModeHost {
        isGamemodeNotify: islandContent.isGamemodeNotify
        isEmailCodeNotify: islandContent.isEmailCodeNotify
        isMouseOver: islandContent.isMouseOver
        flipScale: islandContent.flipScale
    }
}
