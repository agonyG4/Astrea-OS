// MenuItem.qml — item reutilizável do menu Apple-style
import QtQuick
import "../../.."

Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    signal clicked()

    width:  parent.width
    height: 36
    radius: Theme.radiusMedium
    color:  _mouse.containsMouse ? Theme.separator : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animationFast } }

    Row {
        anchors { fill: parent; leftMargin: 12 }
        spacing: Theme.spacingLarge

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:  root.icon
            color: _mouse.containsMouse ? Theme.iconActive : Theme.iconMain
            font.pixelSize: Theme.fontSizeIcon
            Behavior on color { ColorAnimation { duration: Theme.animationFast } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:  root.text
            color: _mouse.containsMouse ? Theme.textActive : Qt.rgba(1, 1, 1, 0.8)
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
