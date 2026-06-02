import QtQuick
import "../../../.."

Rectangle {
    id: mediaButton

    property string icon: ""
    property bool primary: false
    signal clicked()

    width: primary ? 38 : 30
    height: primary ? 38 : 30
    radius: width / 2
    scale: mediaArea.pressed ? 0.94 : 1
    color: !enabled ? Theme.background
                    : primary ? (mediaArea.containsMouse ? Theme.barBorderHover : Theme.background)
                              : (mediaArea.containsMouse ? Theme.shellHover : "transparent")
    border.width: primary ? 1 : 0
    border.color: Theme.border
    opacity: enabled ? 1 : 0.38

    Behavior on color { ColorAnimation { duration: Theme.animationQuick } }
    Behavior on opacity { NumberAnimation { duration: Theme.animationQuick } }
    Behavior on scale { NumberAnimation { duration: Theme.animationMicro; easing.type: Easing.OutCubic } }

    Text {
        anchors.centerIn: parent
        text: mediaButton.icon
        color: Theme.shellIconMain
        font { family: Theme.iconFontFamily; pixelSize: mediaButton.primary ? Theme.fontSizeIconLarge : Theme.fontSizeIcon }
    }

    MouseArea {
        id: mediaArea
        anchors.fill: parent
        enabled: mediaButton.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mediaButton.clicked()
    }
}
