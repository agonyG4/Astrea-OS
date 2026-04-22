import Quickshell
import Quickshell.Io
import QtQuick
import "../system" as SystemComponents
import "../../.."

SystemComponents.TopbarPopup {
    id: control

    property int brightness: 100
    property int ddcBus: 3
    property int brightnessStep: 5

    readonly property color popupGlass: Theme.background
    readonly property color popupWash: "transparent"
    readonly property color popupBorder: Theme.border

    popupWidth: 300
    backgroundColor: control.popupGlass
    washColor: control.popupWash
    borderColor: control.popupBorder

    function brightnessPercentFromX(x) {
        return Math.round(
            Math.max(0, Math.min(brightTrack.width, x))
            / brightTrack.width * 100
        )
    }

    function queueBrightnessRead() {
        brightReadProc.running = false
        brightReadProc.running = true
    }

    function scheduleBrightnessUpdate(value) {
        if (!brightSetProc.running) {
            brightSetProc.command = control.brightnessCommand(value)
            brightSetProc.running = true
        } else {
            brightSetProc.pendingVal = value
            brightSetProc.updatePending = true
        }
    }

    function brightnessCommand(value) {
        return [
            "ddcutil", "--bus", control.ddcBus.toString(), "setvcp", "10",
            value.toString(),
            "--noverify", "--sleep-multiplier=0.05"
        ]
    }

    function applyBrightness(value) {
        const nextValue = Math.round(Math.max(0, Math.min(100, value)))
        if (nextValue === control.brightness)
            return

        control.brightness = nextValue
        control.scheduleBrightnessUpdate(nextValue)
    }

    Timer {
        id: openDelay
        interval: 150
        onTriggered: control.queueBrightnessRead()
    }

    onShownChanged: {
        if (shown)
            openDelay.start()
    }

    Process {
        id: brightSetProc
        command: []
        running: false
        property bool updatePending: false
        property int pendingVal: 50

        onRunningChanged: {
            if (!running && updatePending) {
                updatePending = false
                command = control.brightnessCommand(pendingVal)
                running = true
            }
        }
    }

    Process {
        id: brightReadProc
        command: ["ddcutil", "--bus", control.ddcBus.toString(), "getvcp", "10", "--terse"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(" ")
                if (parts.length >= 4)
                    control.brightness = parseInt(parts[3])
            }
        }
    }

    Item {
        width: parent.width
        height: 24

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Central de Controle"
            color: Theme.textActive
            opacity: 0.85
            font {
                family: Theme.fontFamily
                pixelSize: Theme.fontSizeBody
                weight: Font.DemiBold
                letterSpacing: 0.3
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "󰃠"
            color: Theme.textDim
            font {
                family: Theme.fontFamily
                pixelSize: Theme.fontSizeIcon
            }
        }
    }

    Item {
        width: parent.width
        height: 48

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMedium
            color: Qt.rgba(1, 1, 1, 0.05)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)
        }

        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
                text: "󰃠"
                color: Theme.iconMain
                font {
                    family: Theme.fontFamily
                    pixelSize: Theme.fontSizeIconLarge
                }
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: parent.width - 30
                height: 24
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: brightTrack
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Qt.rgba(0, 0, 0, 0.4)

                    Rectangle {
                        width: Math.max(radius * 2, brightTrack.width * (control.brightness / 100))
                        height: parent.height
                        radius: parent.radius
                        color: Theme.iconActive

                        Behavior on width {
                            NumberAnimation {
                                duration: 60
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(
                        0,
                        Math.min(
                            brightTrack.width - width,
                            brightTrack.width * (control.brightness / 100) - width / 2
                        )
                    )
                    width: brightMouse.pressed ? 20 : (brightMouse.containsMouse ? 18 : 14)
                    height: width
                    radius: width / 2
                    color: "white"

                    Behavior on width {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on x {
                        enabled: !brightMouse.pressed
                        NumberAnimation {
                            duration: 60
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "#01000000"
                        border.width: 1
                        border.color: Qt.rgba(0, 0, 0, 0.15)
                    }
                }

                MouseArea {
                    id: brightMouse
                    anchors.fill: parent
                    anchors.topMargin: -10
                    anchors.bottomMargin: -10
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor

                    onPressed: e => control.applyBrightness(control.brightnessPercentFromX(e.x))

                    onPositionChanged: e => {
                        if (pressed)
                            control.applyBrightness(control.brightnessPercentFromX(e.x))
                    }

                    onWheel: e => control.applyBrightness(
                        control.brightness + (e.angleDelta.y > 0 ? control.brightnessStep : -control.brightnessStep)
                    )
                }
            }
        }
    }
}
