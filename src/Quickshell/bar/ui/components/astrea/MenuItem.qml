// MenuItem.qml — item reutilizável do menu Apple-style
import QtQuick
import "../../.."

Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    readonly property bool iconIsImage: icon.indexOf("image://") === 0
        || icon.indexOf("file://") === 0
        || icon.indexOf("qrc:/") === 0
        || icon.indexOf("/") === 0
    signal clicked()

    width:  parent.width
    height: 36
    radius: Theme.radiusMedium
    color:  _mouse.containsMouse ? Theme.shellSeparator : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animationFast } }

    Row {
        anchors { fill: parent; leftMargin: 12 }
        spacing: Theme.spacingLarge

        Item {
            width: root.icon === "" ? 0 : Theme.fontSizeIcon
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.centerIn: parent
                width: Math.min(18, parent.width)
                height: width
                sourceSize: Qt.size(width, height)
                visible: root.iconIsImage
                source: root.iconIsImage ? root.icon : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                anchors.centerIn: parent
                visible: !root.iconIsImage
                text:  root.icon
                color: _mouse.containsMouse ? Theme.shellIconActive : Theme.shellIconMain
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fontSizeIcon
                Behavior on color { ColorAnimation { duration: Theme.animationFast } }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 12
            text:  root.text
            color: _mouse.containsMouse ? Theme.shellTextActive : Theme.shellTextSecondary
            elide: Text.ElideRight
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeBody; weight: Font.Medium }
            Behavior on color { ColorAnimation { duration: Theme.animationFast } }
        }
    }

    MouseArea {
        id:           _mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked:    root.clicked()
    }
}
