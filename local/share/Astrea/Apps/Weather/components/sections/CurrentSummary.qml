import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../common" as Common

ColumnLayout {
    property var weatherData
    property var colors

    Layout.fillWidth: true
    spacing: 0

    Common.DisplayLabel {
        Layout.fillWidth: true
        text: weatherData ? weatherData.city : ""
        font.pixelSize: 22
        horizontalAlignment: Text.AlignHCenter
        topPadding: 24
        textColor: colors.primary
    }

    Common.DisplayLabel {
        Layout.fillWidth: true
        text: weatherData ? weatherData.temp : "--"
        font.pixelSize: 70
        font.weight: Font.Light
        lineHeight: 1.0
        horizontalAlignment: Text.AlignHCenter
        textColor: colors.primary
    }

    Common.TextLabel {
        Layout.fillWidth: true
        text: weatherData ? weatherData.condition : ""
        font.pixelSize: 18
        horizontalAlignment: Text.AlignHCenter
        textColor: colors.mid
        topPadding: 4
    }

    Common.TextLabel {
        Layout.fillWidth: true
        text: weatherData ? "Sensação térmica de " + weatherData.feels_like : ""
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        textColor: colors.secondary
        topPadding: 6
        bottomPadding: 16
    }
}
