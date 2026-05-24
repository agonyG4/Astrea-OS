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
    readonly property string themePath: (Quickshell.env("HOME") || "") + "/.config/AstreaOS/ui/theme.json"
    readonly property real normalizedLevel: muted ? 0 : Math.min(level, 100) / 100
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

    function applyThemeText(text) {
        try {
            const cfg = JSON.parse((text || "").trim())
            if (typeof cfg.accent === "string" && cfg.accent.length > 0)
                accentHex = cfg.accent
            if (typeof cfg.shell_style === "number")
                shellStyle = Math.max(0, Math.min(2, cfg.shell_style))
            if (typeof cfg.theme_mode === "number")
                themeMode = cfg.theme_mode === 1 ? 1 : 0
        } catch (error) {}
    }

    function showVolume(value, isMuted) {
        disappearAnim.stop()
        appearAnim.stop()
        themeFile.reload()
        level = Math.max(0, Math.min(150, Math.round(value)))
        muted = isMuted
        hideTimer.restart()
        shown = true
        appearAnim.restart()
    }

    property bool shown: false

    visible: shown
    color: "transparent"
    anchors.left: true
    anchors.bottom: true
    implicitWidth: indicatorWidth + surfacePadding * 2
    implicitHeight: indicatorHeight + surfacePadding * 2

    WlrLayershell.namespace: "volume-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.margins.left: Math.round(((screen ? screen.width : 1920) - implicitWidth) / 2)
    WlrLayershell.margins.bottom: 58

    Timer {
        id: hideTimer
        interval: 1150
        repeat: false
        onTriggered: disappearAnim.restart()
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

        anchors.fill: parent
        anchors.margins: osd.surfacePadding
        radius: height / 2
        antialiasing: true
        opacity: 0
        scale: 0.96
        color: "transparent"
        border.width: 0

        Shape {
            id: pillBorder

            anchors.fill: parent
            antialiasing: true
            layer.enabled: true
            layer.samples: 4

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
                family: Theme.fontFamily
                pixelSize: 18
            }
            Behavior on color { ColorAnimation { duration: Theme.animationFast } }
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
            Behavior on color { ColorAnimation { duration: Theme.animationFast } }

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
                        duration: Theme.animationNormal
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color { ColorAnimation { duration: Theme.animationFast } }
            }
        }
    }

    ParallelAnimation {
        id: appearAnim
        ScriptAction {
            script: {
                pill.opacity = Math.max(pill.opacity, 0.01)
                pill.scale = 0.96
            }
        }
        NumberAnimation { target: pill; property: "opacity"; to: 1; duration: 110; easing.type: Easing.OutCubic }
        NumberAnimation { target: pill; property: "scale"; to: 1; duration: Theme.animationFast; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: disappearAnim
        NumberAnimation { target: pill; property: "opacity"; to: 0; duration: 180; easing.type: Easing.OutCubic }
        ScriptAction { script: osd.shown = false }
    }
}
