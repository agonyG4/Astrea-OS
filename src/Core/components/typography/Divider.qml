import QtQuick
import QtQuick.Layouts
import ".." as Components

Rectangle {
    property color lineColor: Components.Theme.cardBorder

    Layout.fillWidth: true
    height: 1
    color: lineColor

    Behavior on color {
        ColorAnimation { duration: Components.Theme.animationFast; easing.type: Easing.OutCubic }
    }
}
