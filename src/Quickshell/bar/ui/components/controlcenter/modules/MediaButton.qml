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
    color: !enabled ? Theme.background
                    : primary ? (mediaArea.containsMouse ? Theme.barBorderHover : Theme.surface)
                              : (mediaArea.containsMouse ? Theme.shellSeparator : "transparent")
    opacity: enabled ? 1 : 0.38

    Behavior on color { ColorAnimation { duration: Theme.animationQuick } }
    Behavior on opacity { NumberAnimation { duration: Theme.animationQuick } }

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
