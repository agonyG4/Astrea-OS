import QtQuick
import "../../../.."

Rectangle {
    id: tile

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool busy: false
    property bool error: false
    readonly property bool compact: width < 96
    readonly property real circleSize: Math.max(44, Math.min(width, height) * 0.72)
    readonly property color baseColor: tile.active
        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, tileMouse.containsMouse ? 0.24 : 0.18)
        : (tileMouse.containsMouse ? Theme.shellHover : Theme.surface)
    signal clicked()

    radius: compact ? height / 2 : Theme.radiusMedium
    scale: tileMouse.pressed ? 0.985 : 1
    color: compact ? "transparent"
                   : (error ? Qt.rgba(1, 0.23, 0.19, 0.16) : tile.baseColor)
    border.width: compact ? 0 : 1
    border.color: error ? Qt.rgba(1, 0.23, 0.19, 0.28)
                        : (active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.38) : Theme.border)

    Behavior on color { ColorAnimation { duration: Theme.animationHover } }
    Behavior on border.color { ColorAnimation { duration: Theme.animationHover } }
    Behavior on scale { NumberAnimation { duration: Theme.animationMicro; easing.type: Easing.OutCubic } }

    Row {
        visible: !tile.compact
        anchors.fill: parent
        anchors.margins: Theme.spacingMedium
        spacing: Theme.spacingControlGap

        Rectangle {
            width: 30
            height: 30
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            color: tile.error ? Qt.rgba(1, 0.23, 0.19, 0.32)
                              : (tile.active ? Theme.accent : Theme.background)
            border.width: 1
            border.color: tile.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.42) : Theme.border

            Text {
                anchors.centerIn: parent
                text: tile.icon
                color: tile.active && !tile.error ? "#ffffff" : (tile.error ? Theme.iconWarning : Theme.shellIconMain)
                font { family: Theme.iconFontFamily; pixelSize: Theme.fontSizeIcon }
                RotationAnimation on rotation {
                    running: tile.busy
                    from: 0
                    to: 360
                    duration: Theme.animationSpin
                    loops: Animation.Infinite
                }
            }
        }

        Column {
            width: parent.width - 39
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: tile.title
                color: Theme.shellTextActive
                elide: Text.ElideRight
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSmall; weight: Font.DemiBold }
            }

            Text {
                width: parent.width
                text: tile.subtitle
                color: tile.error ? Theme.iconWarning : Theme.shellTextSecondary
                opacity: Theme.opacityEmphasis
                elide: Text.ElideRight
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeCaption }
            }
        }
    }

    Rectangle {
        visible: tile.compact
        width: tile.circleSize
        height: tile.circleSize
        radius: height / 2
        anchors.centerIn: parent
        color: tile.error ? Qt.rgba(1, 0.23, 0.19, tileMouse.containsMouse ? 0.38 : 0.30)
                          : tile.active ? Theme.accent
                                        : (tileMouse.containsMouse ? Theme.shellHover : Theme.surface)
        border.width: 1
        border.color: tile.error ? Qt.rgba(1, 0.23, 0.19, 0.34)
                                 : (tile.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.42) : Theme.border)

        Behavior on color { ColorAnimation { duration: Theme.animationHover } }
        Behavior on border.color { ColorAnimation { duration: Theme.animationHover } }

        Text {
            anchors.centerIn: parent
            text: tile.icon
            color: tile.active && !tile.error ? "#ffffff" : (tile.error ? Theme.iconWarning : Theme.shellIconMain)
            font { family: Theme.iconFontFamily; pixelSize: Math.max(12, tile.circleSize * 0.48) }
            RotationAnimation on rotation {
                running: tile.busy
                from: 0
                to: 360
                duration: Theme.animationSpin
                loops: Animation.Infinite
            }
        }
    }

    MouseArea {
        id: tileMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.clicked()
    }
}
