import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../../AstreaComponents" as UI
import "../common" as WeatherCommon

ColumnLayout {
    property var colors

    anchors.centerIn: parent
    spacing: 12

    UI.DisplayLabel {
        Layout.alignment: Qt.AlignHCenter
        text: "⛅"
        font.pixelSize: 48
        textColor: colors.primary
    }

    UI.TextLabel {
        Layout.alignment: Qt.AlignHCenter
        text: "Carregando..."
        font.pixelSize: 14
        textColor: colors.secondary
    }
}
