// MenuSeparator.qml — linha divisória do menu popup
import QtQuick
import "../../.."

Rectangle {
    width:  parent.width - 16
    height: 1
    color:  Theme.shellSeparator
    anchors.horizontalCenter: parent.horizontalCenter
}
