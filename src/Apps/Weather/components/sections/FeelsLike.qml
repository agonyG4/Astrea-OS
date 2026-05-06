import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../common" as Common
import "../.."

ColumnLayout {
    property var weatherData
    property var colors

    Layout.fillWidth: true
    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 160
        radius: Theme.cardRadius
        color: Theme.cardBg
        opacity: 0.92

        ColumnLayout {
            id: feelsContent
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            Common.TextLabel {
                text: "SENSAÇÃO TÉRMICA"
                font.pixelSize: Theme.fontSmall
                font.weight: 600
                textColor: Theme.textTertiary
                Layout.fillWidth: true
            }

            Common.DisplayLabel {
                text: (weatherData ? weatherData.feels_like : "--") + "°"
                font.pixelSize: Theme.fontLarge
                font.weight: 500
                textColor: Theme.textPrimary
            }

            Item { Layout.fillHeight: true }

            Common.TextLabel {
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
                font.pixelSize: Theme.fontRegular
                textColor: "#F2F2F7"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }
}
