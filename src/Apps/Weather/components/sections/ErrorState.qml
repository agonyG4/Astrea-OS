import QtQuick.Controls 2.15
import "../common" as Common

Common.TextLabel {
    property var colors

    anchors.centerIn: parent
    textColor: colors.error
    font.pixelSize: 14
}
