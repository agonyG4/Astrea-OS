import QtQuick

Item {
    id: root

    property bool active: false
    property bool expanded: false
    property bool compactActive: false
    property real flipScale: 1

    anchors.fill: parent

    MusicCompactBars {
        anchors.fill: parent
        active: root.active && root.compactActive && !root.expanded
        bars: island.musicBars
        minHeight: island.musicBarsMinHeight
        maxHeight: island.musicBarsMaxHeightCompact
        tint: island.dominantCol
    }

    Loader {
        id: musicViewLoader

        anchors.fill: parent
        active: root.active
        asynchronous: true
        sourceComponent: MusicView {
            anchors.fill: parent
        }
    }

    Loader {
        id: floatingArtLoader

        active: root.active
        asynchronous: true
        sourceComponent: MusicArtwork {
            active: root.active && (root.compactActive || root.expanded)
            expanded: root.expanded
            artSource: island.artSource
            flipScale: root.flipScale
            expandDuration: flipAnim.artExpandDuration
            collapseDuration: flipAnim.artCollapseDuration
        }
    }
}
