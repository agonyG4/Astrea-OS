import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import "../../../bar" as Bar

Item {
    id: musicView

    readonly property string quickshellAssetRoot: "file://" + (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Assets/ui/quickshell/island/"
    readonly property bool shouldShow: island.isExpanded && !island.showGamemodeNotify && island.hasMusic
    property bool isDraggingSeek: false
    property real dragSeekPosUs:  0

    anchors.fill: parent
    opacity: shouldShow ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { NumberAnimation { duration: shouldShow ? flipAnim.contentFadeInDuration : flipAnim.contentFadeOutDuration; easing.type: Easing.OutCubic } }
    transform: Translate {
        y: musicView.shouldShow ? 0 : -flipAnim.contentSlideDistance
        Behavior on y { NumberAnimation { duration: musicView.shouldShow ? flipAnim.contentSlideInDuration : flipAnim.contentSlideDuration; easing.type: Easing.OutExpo } }
    }

    // ── Helper: ícone de controle ─────────────────────────────────
    component CtrlIcon: Image {
        id: ctrlIconBase
        property color tint: island.dominantCol
        property int   sz:   18

        width: sz; height: sz
        sourceSize: Qt.size(sz, sz)
        fillMode: Image.PreserveAspectFit
        smooth: true; mipmap: true
        anchors.verticalCenter: parent?.verticalCenter
        opacity: 0.95
        layer.enabled: true; layer.smooth: true
        layer.effect: ColorOverlay {
            color: ctrlIconBase.tint
            Behavior on color { ColorAnimation { duration: 250 } }
        }
    }

    // ── Helper: label de tempo ────────────────────────────────────
    component TimeLabel: Text {
        color: Bar.Theme.textSecondary
        font { family: Bar.Theme.fontFamilyText; pixelSize: Bar.Theme.fontSizeBody - 1; weight: Font.Medium; letterSpacing: 0.2 }
        width: 35
        antialiasing: true
        renderType: Text.NativeRendering
    }

    // ── Topo: arte + título + music bars ──────────────────────────
    Item {
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 18; leftMargin: 18; rightMargin: 18 }
        height: 60

        Item { id: artRect; width: 60; height: 60; anchors { left: parent.left; top: parent.top } }

        Column {
            anchors { left: artRect.right; leftMargin: 14; right: waveform.left; rightMargin: 14; top: parent.top; topMargin: 10 }
            spacing: 0

            Text {
                text: island.musicTitleText
                color: Bar.Theme.textActive
                font { family: Bar.Theme.fontFamilyDisplay; pixelSize: Bar.Theme.fontSizeTitle; weight: Font.DemiBold; letterSpacing: -0.3 }
                elide: Text.ElideRight; width: parent.width
                antialiasing: true; renderType: Text.NativeRendering
            }
            Text {
                text: island.musicArtistText
                color: Bar.Theme.textSecondary
                font { family: Bar.Theme.fontFamilyText; pixelSize: Bar.Theme.fontSizeBody; weight: Font.Medium; letterSpacing: -0.1 }
                elide: Text.ElideRight; width: parent.width
                antialiasing: true; renderType: Text.NativeRendering
            }
        }

        Row {
            id: waveform
            width: 36; spacing: 3
            anchors { right: parent.right; top: parent.top; topMargin: 12 }
            Repeater {
                model: 6
                Item {
                    width: 3; height: 36
                    Rectangle {
                        width: 3; radius: 2
                        height: island.musicBars[index] <= 0 ? (musicView.shouldShow ? island.musicBarsMinHeight : 0) : Math.min(island.musicBarsMaxHeightExpanded, Math.max(island.musicBarsMinHeight, island.musicBars[index] / 100 * 34))
                        anchors.centerIn: parent
                        color: island.dominantCol
                        Behavior on height {
                            enabled: island.isExpanded
                            NumberAnimation {
                                duration: island.musicBars[index] <= 0 ? 320 : 90 + index * 4
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on color  { ColorAnimation { duration: 300 } }
                    }
                }
            }
        }
    }

    // ── Barra de progresso ────────────────────────────────────────
    Item {
        id: seekBar
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 90; leftMargin: 20; rightMargin: 20 }
        height: 22

        readonly property real seekPos: isDraggingSeek ? dragSeekPosUs : island.smoothPosition
        readonly property real ratio:   island.musicLength > 0 ? Math.min(seekPos / island.musicLength, 1.0) : 0

        TimeLabel {
            id: currentTimeLabel
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            horizontalAlignment: Text.AlignRight
            text: island.formatTime(seekBar.seekPos)
        }

        Rectangle {
            id: progressBarBg
            anchors { verticalCenter: parent.verticalCenter; left: currentTimeLabel.right; leftMargin: 10; right: totalTimeLabel.left; rightMargin: 10 }
            height: 5; radius: 2.5
            color: Bar.Theme.separator

            Rectangle {
                width: parent.width * seekBar.ratio
                height: parent.height; radius: 2.5
                color: island.dominantCol
                Behavior on color { ColorAnimation { duration: 300 } }
            }

            Rectangle {
                width: 10; height: 10; radius: 5
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width * seekBar.ratio - 5
                color: Bar.Theme.textActive
                opacity: isDraggingSeek ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            MouseArea {
                anchors { fill: parent; topMargin: -10; bottomMargin: -10 }
                cursorShape: Qt.PointingHandCursor

                function posFromMouse(mouse) {
                    return Math.max(0, Math.min(1, mouse.x / width)) * island.musicLength
                }

                onPressed:         (mouse) => { isDraggingSeek = true; dragSeekPosUs = posFromMouse(mouse) }
                onPositionChanged: (mouse) => { if (isDraggingSeek) dragSeekPosUs = posFromMouse(mouse) }
                onReleased:        (mouse) => {
                    if (!isDraggingSeek) return
                    dragSeekPosUs = posFromMouse(mouse)
                    procs.setPosition(dragSeekPosUs)
                    island.smoothPosition = dragSeekPosUs
                    isDraggingSeek = false
                }
            }
        }

        TimeLabel {
            id: totalTimeLabel
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            horizontalAlignment: Text.AlignLeft
            text: island.formatTime(island.musicLength)
        }
    }

    // ── Controles ─────────────────────────────────────────────────
    Row {
        y: 120
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 28

        CtrlIcon {
            source: musicView.quickshellAssetRoot + "shuffle.png"
            tint:    island.isShuffle ? island.dominantCol : Bar.Theme.textSecondary
            opacity: island.isShuffle ? 1.0 : 0.35
            Behavior on opacity { NumberAnimation { duration: 150 } }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: procs.toggleShuffle() }
        }

        CtrlIcon {
            source: musicView.quickshellAssetRoot + "skip-back.png"
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: procs.prev() }
        }

        CtrlIcon {
            id: playPauseBtn
            source: musicView.quickshellAssetRoot + (island.isPlaying ? "pause.png" : "play.png")
            sz: 24

            SequentialAnimation {
                id: playPauseAnim
                NumberAnimation { target: playPauseBtn; property: "scale"; to: 0.75; duration: 60;  easing.type: Easing.OutQuad }
                NumberAnimation { target: playPauseBtn; property: "scale"; to: 1.0;  duration: 350; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.56, 0.64, 1.0] }
            }

            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { playPauseAnim.restart(); procs.playPause() }
            }
        }

        CtrlIcon {
            source: musicView.quickshellAssetRoot + "skip-forward.png"
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: procs.next() }
        }

        Item {
            width: 18; height: 18
            anchors.verticalCenter: parent.verticalCenter

            CtrlIcon {
                id: loopIcon
                anchors.fill: parent
                source: musicView.quickshellAssetRoot + "loop.png"
                tint:    island.isLoop ? island.dominantCol : Bar.Theme.textSecondary
                opacity: island.isLoop ? 1.0 : 0.35
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            Rectangle {
                visible: island.isLoopTrack
                anchors { right: parent.right; top: parent.top; rightMargin: -3; topMargin: -3 }
                width: 10; height: 10; radius: 5
                color: island.dominantCol
                Behavior on color { ColorAnimation { duration: 200 } }
                Text {
                    anchors.centerIn: parent
                    text: "1"
                    font.family: Bar.Theme.fontFamilyText
                    font.pixelSize: 6
                    font.weight: Font.Bold
                    color: "black"
                    antialiasing: true
                    renderType: Text.NativeRendering
                }
            }

            ScaleAnimator { id: loopPulse; target: loopIcon; from: 1.3; to: 1.0; duration: 250; easing.type: Easing.OutBack }

            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { procs.toggleLoop(); loopPulse.start() }
            }
        }
    }
}
