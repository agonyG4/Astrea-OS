import QtQuick.Controls 2.15
import "../../../AstreaComponents" as UI
import "../common" as WeatherCommon

UI.TextLabel {
    property var colors

    anchors.centerIn: parent
    textColor: colors.error
    font.pixelSize: 14
}
