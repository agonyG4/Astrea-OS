import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import "../../.."

PanelWindow {
    id: osd

    property int level: 50
    property bool muted: false
    readonly property int indicatorWidth: 270
    readonly property int indicatorHeight: 56
    readonly property int surfacePadding: 4
    readonly property int trackWidth: 178
    readonly property int trackHeight: 5
    readonly property int iosCompactTrackWidth: 10
    readonly property int iosExpandedTrackWidth: 26
    readonly property int iosWidthAnimationDuration: 270
    readonly property int iosFastFillWindowMs: 180
    readonly property int iosTrackWidth: iosWide ? iosExpandedTrackWidth : iosCompactTrackWidth
    readonly property int iosSurfaceWidth: Math.max(iosCompactTrackWidth, iosExpandedTrackWidth)
    readonly property int iosTrackHeight: 196
    readonly property int iosPaddingX: 10
    readonly property int iosPaddingY: 24
    readonly property string themePath: (Quickshell.env("HOME") || "") + "/.config/AstreaOS/ui/theme.json"
    readonly property bool iosStyle: audioOsdStyle === 1
    readonly property real normalizedLevel: muted ? 0 : Math.min(level, 100) / 100
    readonly property int iosFillHeight: normalizedLevel <= 0
        ? 0
        : Math.max(iosTrackWidth, Math.round(iosTrackHeight * normalizedLevel))
    readonly property color themeSurface: {
        if (shellStyle === 0 || shellStyle === 2)
            return themeMode === 1 ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.06)
        return themeMode === 1 ? Qt.rgba(0.97, 0.97, 0.99, 1.0) : Qt.rgba(0.11, 0.11, 0.12, 1.0)
    }
    readonly property int fillWidth: normalizedLevel <= 0
        ? 0
        : Math.max(trackHeight, Math.round(trackWidth * normalizedLevel))
    readonly property string icon: muted || level <= 0 ? "󰝟" : (level < 34 ? "󰕿" : (level < 67 ? "󰖀" : "󰕾"))
    property string accentHex: "#0a84ff"
    property color accentColor: accentHex
    property int shellStyle: 1
    property int themeMode: 0
    property int audioOsdStyle: 0
    property int lastShowAt: 0
    property int fillAnimationDuration: 70
    property bool hiding: false
    property bool iosWide: false
    property int iosVisibleChangeCount: 0
    property real iosSlideOffset: -implicitWidth

    function applyThemeText(text) {
        try {
            const cfg = JSON.parse((text || "").trim())
            if (typeof cfg.accent === "string" && cfg.accent.length > 0)
                accentHex = cfg.accent
            if (typeof cfg.shell_style === "number")
                shellStyle = Math.max(0, Math.min(2, cfg.shell_style))
            if (typeof cfg.theme_mode === "number")
                themeMode = cfg.theme_mode === 1 ? 1 : 0
            if (typeof cfg.audio_osd_style === "number")
                audioOsdStyle = Math.max(0, Math.min(1, cfg.audio_osd_style))
        } catch (error) {}
    }

    function showVolume(value, isMuted) {
        const now = Date.now()
        const wasVisible = shown || hiding
        const fastChange = shown && lastShowAt > 0 && now - lastShowAt < iosFastFillWindowMs
        fillAnimationDuration = fastChange ? 36 : 70
        lastShowAt = now
        level = Math.max(0, Math.min(150, Math.round(value)))
        muted = isMuted
        hideTimer.restart()
        if (iosStyle) {
            iosVisibleChangeCount = wasVisible ? iosVisibleChangeCount + 1 : 1
            iosWide = iosVisibleChangeCount === 1
            iosHideAnimation.stop()
            iosShowAnimation.stop()
            hiding = false
            if (!wasVisible) {
                iosSlideOffset = -implicitWidth
            }
            shown = true
            if (wasVisible) {
                iosSlideOffset = 0
            } else {
                iosShowAnimation.restart()
            }
        } else {
            hiding = false
            shown = true
        }
    }

    function hideOsd() {
        if (iosStyle && shown) {
            iosShowAnimation.stop()
            shown = false
            hiding = true
            iosHideAnimation.restart()
            return
        }

        shown = false
        hiding = false
        iosVisibleChangeCount = 0
        iosWide = false
    }

    property bool shown: false

    visible: shown || hiding
    color: "transparent"
    anchors.left: true
    anchors.bottom: true
    implicitWidth: iosStyle ? iosSurfaceWidth + iosPaddingX * 2 : indicatorWidth + surfacePadding * 2
    implicitHeight: iosStyle ? iosTrackHeight + iosPaddingY * 2 : indicatorHeight + surfacePadding * 2

    WlrLayershell.namespace: "volume-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.margins.left: iosStyle ? 0 : Math.round(((screen ? screen.width : 1920) - implicitWidth) / 2)
    WlrLayershell.margins.bottom: iosStyle ? Math.round(((screen ? screen.height : 1080) - implicitHeight) / 2) : 58

    Timer {
        id: hideTimer
        interval: 1150
        repeat: false
        onTriggered: osd.hideOsd()
    }

    NumberAnimation {
        id: iosShowAnimation
        target: osd
        property: "iosSlideOffset"
        from: -osd.implicitWidth
        to: 0
        duration: 240
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: iosHideAnimation

        NumberAnimation {
            target: osd
            property: "iosSlideOffset"
            to: -osd.implicitWidth
            duration: 220
            easing.type: Easing.InCubic
        }

        ScriptAction {
            script: {
                if (!osd.shown) {
                    osd.hiding = false
                    osd.iosWide = false
                    osd.iosVisibleChangeCount = 0
                }
            }
        }
    }

    FileView {
        id: themeFile
        path: osd.themePath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: osd.applyThemeText(text())
    }

    Rectangle {
        id: pill

        visible: !osd.iosStyle
        anchors.fill: parent
        anchors.margins: osd.surfacePadding
        radius: height / 2
        antialiasing: true
        color: "transparent"
        border.width: 0

        Shape {
            id: pillBorder

            anchors.fill: parent
            antialiasing: true
            layer.enabled: true
            layer.samples: 4
            layer.smooth: true

            readonly property real inset: 0.5
            readonly property real r: Math.max(0, (height - inset * 2) / 2)
            readonly property real leftEdge: inset
            readonly property real topEdge: inset
            readonly property real rightEdge: width - inset
            readonly property real bottomEdge: height - inset

            ShapePath {
                fillColor: osd.themeSurface
                strokeColor: Qt.rgba(1, 1, 1, 0.08)
                strokeWidth: 1
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: pillBorder.leftEdge + pillBorder.r
                startY: pillBorder.topEdge

                PathLine {
                    x: pillBorder.rightEdge - pillBorder.r
                    y: pillBorder.topEdge
                }
                PathArc {
                    x: pillBorder.rightEdge - pillBorder.r
                    y: pillBorder.bottomEdge
                    radiusX: pillBorder.r
                    radiusY: pillBorder.r
                    useLargeArc: false
                    direction: PathArc.Clockwise
                }
                PathLine {
                    x: pillBorder.leftEdge + pillBorder.r
                    y: pillBorder.bottomEdge
                }
                PathArc {
                    x: pillBorder.leftEdge + pillBorder.r
                    y: pillBorder.topEdge
                    radiusX: pillBorder.r
                    radiusY: pillBorder.r
                    useLargeArc: false
                    direction: PathArc.Clockwise
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            horizontalAlignment: Text.AlignHCenter
            text: osd.icon
            color: osd.themeMode === 1
                ? (osd.muted ? Qt.rgba(0, 0, 0, 0.34) : Qt.rgba(0, 0, 0, 0.68))
                : (osd.muted ? Theme.shellIconMuted : Theme.shellIconMain)
            font {
                family: Theme.iconFontFamily
                pixelSize: 18
            }
        }

        Rectangle {
            id: track

            anchors.left: parent.left
            anchors.leftMargin: 56
            anchors.verticalCenter: parent.verticalCenter
            width: osd.trackWidth
            height: osd.trackHeight
            radius: height / 2
            antialiasing: true
            color: osd.muted
                ? Qt.rgba(Theme.shellSeparator.r, Theme.shellSeparator.g, Theme.shellSeparator.b, 0.60)
                : Theme.shellSeparator

            Rectangle {
                id: fill

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: osd.fillWidth
                radius: parent.radius
                antialiasing: true
                color: osd.muted
                    ? Qt.rgba(Theme.shellSeparator.r, Theme.shellSeparator.g, Theme.shellSeparator.b, 0.70)
                    : osd.accentColor

                Behavior on width {
                    NumberAnimation {
                        duration: osd.fillAnimationDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    Item {
        id: iosIndicator

        visible: osd.iosStyle
        anchors.fill: parent
        transform: Translate {
            x: osd.iosSlideOffset
        }

        Rectangle {
            id: iosTrack

            x: osd.iosPaddingX
            y: Math.round((parent.height - height) / 2)
            width: osd.iosTrackWidth
            height: osd.iosTrackHeight
            radius: width / 2
            antialiasing: true
            clip: true
            color: Theme.background
            border.width: 1
            border.color: Theme.border

            Behavior on width {
                NumberAnimation {
                    duration: osd.iosWidthAnimationDuration
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: osd.iosFillHeight
                radius: parent.radius
                antialiasing: true
                color: osd.muted
                    ? Qt.rgba(1, 1, 1, 0.32)
                    : osd.accentColor

                Behavior on height {
                    NumberAnimation {
                        duration: osd.fillAnimationDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
