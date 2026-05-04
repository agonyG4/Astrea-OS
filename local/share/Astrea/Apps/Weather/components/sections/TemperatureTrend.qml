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
            id: trendContent
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            Common.TextLabel {
                text: "MÉDIA DE TEMP"
                font.pixelSize: Theme.fontSmall
                font.weight: 600
                textColor: Theme.textTertiary
                Layout.fillWidth: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                visible: weatherData && weatherData.temp_history_avg !== undefined && weatherData.temp_history_avg !== null

                Common.DisplayLabel {
                    property int diff: (weatherData && weatherData.temp_history_avg !== undefined && weatherData.temp_history_avg !== null) ? (weatherData.temp - weatherData.temp_history_avg) : 0
                    text: (diff > 0 ? "+" : "") + diff + "°"
                    font.pixelSize: Theme.fontLarge
                    font.weight: 500
                    textColor: Theme.textPrimary
                }

                Common.TextLabel {
                    property int diff: (weatherData && weatherData.temp_history_avg !== undefined && weatherData.temp_history_avg !== null) ? (weatherData.temp - weatherData.temp_history_avg) : 0
                    text: diff === 0 ? "Na média." :
                          Math.abs(diff) + "° " + (diff > 0 ? "acima" : "abaixo")
                    font.pixelSize: Theme.fontRegular
                    textColor: "#F2F2F7"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Common.TextLabel {
                visible: !weatherData || weatherData.temp_history_avg === undefined || weatherData.temp_history_avg === null
                text: "Dados indisponíveis."
                font.pixelSize: Theme.fontRegular
                textColor: Theme.textTertiary
                Layout.fillWidth: true
            }
            
            Item { Layout.fillHeight: true }

            Common.TextLabel {
                text: "Média: " + (weatherData && weatherData.temp_history_avg !== undefined && weatherData.temp_history_avg !== null ? weatherData.temp_history_avg : "--") + "°"
                font.pixelSize: Theme.fontSmall
                textColor: Theme.textTertiary
                Layout.fillWidth: true
            }
        }
    }
}
