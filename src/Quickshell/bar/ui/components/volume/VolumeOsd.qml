import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../.."
import "../../../../AstreaI18n" as AstreaI18n

PanelWindow {
    id: osd

    property int level: 50
    property bool muted: false
    readonly property int indicatorWidth: 286
    readonly property int indicatorHeight: 70
    readonly property string icon: muted || level <= 0 ? "󰝟" : (level < 34 ? "󰕿" : (level < 67 ? "󰖀" : "󰕾"))

    function showVolume(value, isMuted) {
        disappearAnim.stop()
        appearAnim.stop()
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
    implicitWidth: indicatorWidth
    implicitHeight: indicatorHeight

    WlrLayershell.namespace: "volume-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.margins.left: Math.round(((screen ? screen.width : 1920) - indicatorWidth) / 2)
    WlrLayershell.margins.bottom: 46

    Timer {
        id: hideTimer
        interval: 1150
        repeat: false
        onTriggered: disappearAnim.restart()
    }

    Rectangle {
        id: pill

        anchors.fill: parent
        radius: 14
        opacity: 0
        scale: 0.98
        color: Qt.rgba(0.08, 0.09, 0.11, 0.82)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)

        Row {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 14

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                horizontalAlignment: Text.AlignHCenter
                text: osd.icon
                color: osd.muted ? Theme.iconMuted : Theme.iconMain
                font { family: Theme.fontFamily; pixelSize: 20 }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 24 - percentText.width - parent.spacing * 2
                spacing: 8

                Text {
                    width: parent.width
                    text: osd.muted
                        ? ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.volume.muted"]) || "Muted")
                        : ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["shell.volume.volume"]) || "Volume")
                    color: Theme.textActive
                    elide: Text.ElideRight
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeCaption; weight: Font.DemiBold }
                }

                Rectangle {
                    width: parent.width
                    height: 5
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.20)

                    Rectangle {
                        width: Math.max(parent.radius * 2, parent.width * Math.min(osd.level, 100) / 100)
                        height: parent.height
                        radius: parent.radius
                        color: osd.muted ? Theme.iconMuted : Theme.iconActive

                        Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    }
                }
            }

            Text {
                id: percentText
                anchors.verticalCenter: parent.verticalCenter
                width: 46
                horizontalAlignment: Text.AlignRight
                text: osd.muted ? "0%" : Math.min(osd.level, 100) + "%"
                color: Theme.textActive
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeCaption; weight: Font.DemiBold }
            }
        }
    }

    ParallelAnimation {
        id: appearAnim
        ScriptAction {
            script: {
                pill.opacity = Math.max(pill.opacity, 0.01)
                pill.scale = 0.98
            }
        }
        NumberAnimation { target: pill; property: "opacity"; to: 1; duration: 110; easing.type: Easing.OutCubic }
        NumberAnimation { target: pill; property: "scale"; to: 1; duration: 140; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: disappearAnim
        NumberAnimation { target: pill; property: "opacity"; to: 0; duration: 180; easing.type: Easing.OutCubic }
        ScriptAction { script: osd.shown = false }
    }
}
