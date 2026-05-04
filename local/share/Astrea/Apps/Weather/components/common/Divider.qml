import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    property color lineColor: "#D9D9DE"

    Layout.fillWidth: true
    height: 1
    color: lineColor

    Behavior on color {
        ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
}
