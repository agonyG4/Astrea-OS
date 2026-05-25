import QtQuick
import "../../../.."

Rectangle {
    id: rowRoot

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool busy: false
    property bool error: false
    signal clicked()

    radius: Theme.radiusMedium
    color: error ? Qt.rgba(1, 0.23, 0.19, 0.20)
                  : (rowMouse.containsMouse ? Theme.shellSeparator : "transparent")

    Behavior on color { ColorAnimation { duration: Theme.animationSubtle } }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingInset
        anchors.rightMargin: Theme.spacingInset
        spacing: Theme.spacing

        Rectangle {
            width: 28
            height: 28
            radius: Theme.cornerRadiusLarge
            anchors.verticalCenter: parent.verticalCenter
            color: rowRoot.error ? Qt.rgba(1, 0.23, 0.19, 0.32)
                                 : rowRoot.active ? Theme.accent : Theme.surface

            Text {
                anchors.centerIn: parent
                text: rowRoot.icon
                color: rowRoot.active && !rowRoot.error ? "#ffffff" : (rowRoot.error ? Theme.iconWarning : Theme.shellIconMain)
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeIcon }
                RotationAnimation on rotation {
                    running: rowRoot.busy
                    from: 0
                    to: 360
                    duration: Theme.animationSpin
                    loops: Animation.Infinite
                }
            }
        }

        Column {
            width: parent.width - 36
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                width: parent.width
                text: rowRoot.title
                color: Theme.shellTextActive
                elide: Text.ElideRight
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSmall; weight: Font.DemiBold }
            }

            Text {
                width: parent.width
                text: rowRoot.subtitle
                color: rowRoot.error ? Theme.iconWarning : Theme.shellTextSecondary
                opacity: Theme.opacityEmphasis
                elide: Text.ElideRight
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeMicro; weight: Font.Medium }
            }
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: rowRoot.clicked()
    }
}
