import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../.."

Rectangle {
    property color lineColor: Theme.cardBorder

    Layout.fillWidth: true
    implicitHeight: 1
    color: lineColor
    opacity: 0.75
}
