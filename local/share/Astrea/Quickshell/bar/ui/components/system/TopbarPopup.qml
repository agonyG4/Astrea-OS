import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../../.."

PanelWindow {
    id: control

    property bool shown: false
    property bool closing: false
    property var anchorWindow: null
    property real anchorX: screen.width / 2
    property real popupWidth: 300
    property real topOffset: 54
    property real sidePadding: 8
    property real cardPadding: 18
    property real cardRadius: Theme.radiusLarge
    property color backgroundColor: Qt.rgba(0, 0, 0, 0.0)
    property color washColor: "transparent"
    property color borderColor: Qt.rgba(1, 1, 1, 0.08)
    property real contentSpacing: 14
    property bool closeOnOutsideClick: true
    property bool animateScale: true
    property real hiddenScale: 0.97
    property int fadeDuration: 180
    property int scaleDuration: 220
    default property alias contentData: contentColumn.data

    function open() {
        if (shown && !closing)
            return

        closing = false
        shown = true
    }

    function close() {
        if (!shown || closing)
            return

        closing = true
        disappearAnim.start()
    }

    function toggle() {
        if (shown && !closing)
            close()
        else
            open()
    }

    function showAt(x) {
        anchorX = x
        open()
    }

    function toggleAt(x) {
        anchorX = x
        toggle()
    }

    color: "transparent"
    visible: control.shown

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    WlrLayershell.namespace: "topbar-popup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    onShownChanged: {
        if (shown && !closing) {
            appearAnim.stop()
            disappearAnim.stop()

            card.opacity = 0
            card.scale = control.animateScale ? control.hiddenScale : 1.0

            appearAnim.start()
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: control.closeOnOutsideClick
        onClicked: control.close()
        z: 0
    }

    Item {
        id: card
        anchors.top: parent.top
        anchors.topMargin: control.topOffset
        x: Math.round(Math.max(
            control.sidePadding,
            Math.min(parent.width - width - control.sidePadding, control.anchorX - width / 2)
        ))
        width: control.popupWidth
        height: cardBg.height
        opacity: 0
        scale: control.animateScale ? control.hiddenScale : 1.0
        z: 1

        SequentialAnimation {
            id: appearAnim

            ParallelAnimation {
                NumberAnimation {
                    target: card
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: control.fadeDuration
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: card
                    property: "scale"
                    from: control.animateScale ? control.hiddenScale : 1.0
                    to: 1.0
                    duration: control.animateScale ? control.scaleDuration : 0
                    easing.type: Easing.OutBack
                }
            }
        }

        SequentialAnimation {
            id: disappearAnim

            ParallelAnimation {
                NumberAnimation {
                    target: card
                    property: "opacity"
                    from: card.opacity
                    to: 0
                    duration: control.fadeDuration
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: card
                    property: "scale"
                    from: card.scale
                    to: control.animateScale ? control.hiddenScale : 1.0
                    duration: control.animateScale ? control.scaleDuration : 0
                    easing.type: Easing.OutCubic
                }
            }

            ScriptAction {
                script: {
                    control.shown = false
                    control.closing = false
                    card.opacity = 0
                    card.scale = control.animateScale ? control.hiddenScale : 1.0
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
        }

        Rectangle {
            id: cardBg
            width: parent.width
            height: contentColumn.implicitHeight + control.cardPadding * 2
            radius: control.cardRadius
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: control.backgroundColor
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: control.washColor
                visible: control.washColor.a > 0
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                visible: control.borderColor.a > 0
                border.width: 1
                border.color: control.borderColor
            }

            layer.enabled: false
        }

        Column {
            id: contentColumn
            anchors {
                top: cardBg.top
                left: cardBg.left
                right: cardBg.right
                margins: control.cardPadding
                topMargin: control.cardPadding
            }
            spacing: control.contentSpacing
        }
    }
}