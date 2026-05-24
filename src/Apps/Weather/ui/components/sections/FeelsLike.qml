import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../../../AstreaComponents" as UI
import "../common" as WeatherCommon
import "../../../AstreaI18n" as AstreaI18n

ColumnLayout {
    property var weatherData
    property var colors

    Layout.fillWidth: true
    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 160
        radius: 20
        color: UI.Theme.cardBg
        border.color: UI.Theme.cardBorder
        border.width: 1

        ColumnLayout {
            id: feelsContent
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            UI.TextLabel {
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["weather.feels_like.title"]) || "SENSAÇÃO TÉRMICA")
                font.pixelSize: UI.Theme.fontSizeSmall
                font.weight: 600
                textColor: UI.Theme.textTertiary
                Layout.fillWidth: true
            }

            UI.DisplayLabel {
                text: (weatherData ? weatherData.feels_like : "--") + "°"
                font.pixelSize: UI.Theme.fontSizeIconLarge
                font.weight: 500
                textColor: UI.Theme.textPrimary
            }

            Item { Layout.fillHeight: true }

            UI.TextLabel {
                id: messageLabel
                text: {
                    if (!weatherData) return ""
                    var diff = weatherData.feels_like - weatherData.temp
                    if (diff < 0) {
                        if (weatherData.wind > 15) return "O vento está baixando a sensação térmica."
                        return "Está um pouco mais frio que a temperatura real."
                    } else if (diff > 0) {
                        if (weatherData.humidity > 70) return "A umidade está aumentando a sensação térmica."
                        return "Está um pouco mais quente que a temperatura real."
                    }
                    return "Igual à temperatura real."
                }
                font.pixelSize: UI.Theme.fontSizeLarge
                textColor: UI.Theme.textPrimary
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }
}
