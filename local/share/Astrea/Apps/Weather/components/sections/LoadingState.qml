import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../common" as Common

ColumnLayout {
    property var colors

    anchors.centerIn: parent
    spacing: 12

    Common.DisplayLabel {
        Layout.alignment: Qt.AlignHCenter
        text: "⛅"
        font.pixelSize: 48
        textColor: colors.primary
    }

    Common.TextLabel {
        Layout.alignment: Qt.AlignHCenter
        text: "Carregando..."
        font.pixelSize: 14
        textColor: colors.secondary
    }
}
