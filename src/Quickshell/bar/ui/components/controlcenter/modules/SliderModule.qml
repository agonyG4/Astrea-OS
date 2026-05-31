import QtQuick
import "../../../.."
import "../../../../../AstreaI18n" as AstreaI18n

Rectangle {
    id: sliderCard

    property var control: null
    property string moduleKind: "volume"
    readonly property bool isVolume: moduleKind === "volume"
    readonly property string title: isVolume
        ? AstreaI18n.I18n.tr("quickshell.bar.ui.components.controlcenter.module.sound", "Sound")
        : AstreaI18n.I18n.tr("quickshell.bar.ui.components.controlcenter.module.display", "Display")
    readonly property string leftIcon: isVolume && control ? control.volumeIcon() : "󰃞"
    readonly property string rightIcon: isVolume && control && control.masterMuted ? "󰝟" : (isVolume ? "󰕾" : "󰃠")
    readonly property int value: isVolume && control ? control.masterVol : (control ? control.brightness : 0)
    readonly property bool muted: isVolume && control ? control.masterMuted : false
    readonly property string valueText: muted ? AstreaI18n.I18n.tr("quickshell.bar.ui.components.controlcenter.status.muted", "Muted") : value + "%"

    signal valueChangedByUser(int value)
    signal wheelChangedByUser(int delta)
    signal iconClicked()

    height: 68
    radius: Theme.radiusLarge
    color: sliderMouse.containsMouse ? Theme.shellHover : Theme.surface
    border.width: 1
    border.color: sliderCard.muted
        ? Qt.rgba(Theme.shellIconMuted.r, Theme.shellIconMuted.g, Theme.shellIconMuted.b, 0.38)
        : (sliderMouse.containsMouse ? Theme.barBorderHover : Theme.border)

    Behavior on color { ColorAnimation { duration: Theme.animationHover } }
    Behavior on border.color { ColorAnimation { duration: Theme.animationHover } }

    onValueChangedByUser: value => {
        if (!control)
            return
        if (isVolume)
            control.applyVolume(value)
        else
            control.applyBrightness(value)
    }

    onWheelChangedByUser: delta => {
        if (!control)
            return
        if (isVolume)
            control.applyVolume(control.masterVol + delta * 2)
        else
            control.applyBrightness(control.brightness + delta * control.brightnessStep)
    }

    onIconClicked: if (control && isVolume) control.toggleMute()

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: Theme.spacingLarge
        anchors.topMargin: Theme.spacingControlGap
        text: sliderCard.title
        color: Theme.shellTextActive
        opacity: Theme.opacitySubtle
        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSmall; weight: Font.DemiBold }
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Theme.spacingLarge
        anchors.topMargin: Theme.spacingControlGap
        text: sliderCard.valueText
        color: sliderCard.muted ? Theme.shellIconMuted : Theme.shellTextSecondary
        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeCaption; weight: Font.DemiBold }
    }

    Rectangle {
        id: sliderLeftIconShell
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.spacingLarge
        anchors.bottomMargin: 9
        width: 28
        height: 28
        radius: height / 2
        color: sliderCard.muted ? Theme.background : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.13)
        border.width: 1
        border.color: sliderCard.muted ? Theme.border : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)

        Text {
            id: sliderLeftIcon
            anchors.centerIn: parent
            text: sliderCard.leftIcon
            color: sliderCard.muted ? Theme.shellIconMuted : Theme.shellIconMain
            font { family: Theme.iconFontFamily; pixelSize: Theme.fontSizeIcon }
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            anchors.margins: -8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sliderCard.iconClicked()
        }
    }

    Item {
        id: sliderArea
        anchors.left: sliderLeftIconShell.right
        anchors.right: sliderRightIcon.left
        anchors.verticalCenter: sliderLeftIconShell.verticalCenter
        anchors.leftMargin: Theme.spacingLarge
        anchors.rightMargin: Theme.spacingLarge
        height: 24

        Rectangle {
            id: sliderTrack
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: Theme.shellSeparator

            Rectangle {
                width: Math.max(radius * 2, sliderTrack.width * (sliderCard.value / 100))
                height: parent.height
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: sliderCard.muted ? Theme.shellIconMuted : Theme.shellIconMain }
                    GradientStop { position: 1.0; color: sliderCard.muted ? Theme.shellIconMuted : Theme.shellIconActive }
                }
                Behavior on width {
                    enabled: sliderCard.control ? sliderCard.control.sliderAnimationsEnabled : false
                    NumberAnimation { duration: Theme.animationSlider; easing.type: Easing.OutCubic }
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(sliderTrack.width - width, sliderTrack.width * (sliderCard.value / 100) - width / 2))
            width: sliderMouse.pressed ? 20 : (sliderMouse.containsMouse ? 18 : 14)
            height: width
            radius: width / 2
            color: Theme.shellIconActive

            Behavior on width { NumberAnimation { duration: Theme.animationMicro; easing.type: Easing.OutCubic } }
            Behavior on x {
                enabled: !sliderMouse.pressed && (sliderCard.control ? sliderCard.control.sliderAnimationsEnabled : false)
                NumberAnimation { duration: Theme.animationSlider; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Theme.border
            }
        }

        MouseArea {
            id: sliderMouse
            anchors.fill: parent
            anchors.topMargin: -10
            anchors.bottomMargin: -10
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor

            onPressed: e => sliderCard.valueChangedByUser(sliderCard.control ? sliderCard.control.volumePercentFromX(e.x, sliderTrack.width) : 0)
            onPositionChanged: e => {
                if (pressed && sliderCard.control)
                    sliderCard.valueChangedByUser(sliderCard.control.volumePercentFromX(e.x, sliderTrack.width))
            }
            onWheel: e => sliderCard.wheelChangedByUser(e.angleDelta.y > 0 ? 1 : -1)
        }
    }

    Text {
        id: sliderRightIcon
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Theme.spacingLarge
        anchors.bottomMargin: Theme.spacingLarge
        text: sliderCard.rightIcon
        color: sliderCard.muted ? Theme.shellIconMuted : Theme.shellIconMain
        font { family: Theme.iconFontFamily; pixelSize: Theme.fontSizeIcon }
    }
}
