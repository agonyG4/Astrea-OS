import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../../../AstreaComponents" as UI
import "../common" as WeatherCommon

ColumnLayout {
    property var weatherData
    property var colors

    Layout.fillWidth: true
    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 160
        radius: UI.Theme.cardRadius
        color: UI.Theme.cardBg
        opacity: 0.92

        ColumnLayout {
            id: trendContent
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            UI.TextLabel {
                text: "MÉDIA DE TEMP"
                font.pixelSize: UI.Theme.fontSizeSmall
                font.weight: 600
                textColor: UI.Theme.textTertiary
                Layout.fillWidth: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                visible: weatherData && weatherData.temp_history_avg !== undefined && weatherData.temp_history_avg !== null

                UI.DisplayLabel {
                    property int diff: (weatherData && weatherData.temp_history_avg !== undefined && weatherData.temp_history_avg !== null) ? (weatherData.temp - weatherData.temp_history_avg) : 0
                    text: (diff > 0 ? "+" : "") + diff + "°"
                    font.pixelSize: UI.Theme.fontSizeIconLarge
                    font.weight: 500
                    textColor: UI.Theme.textPrimary
                }

                UI.TextLabel {
                    property int diff: (weatherData && weatherData.temp_history_avg !== undefined && weatherData.temp_history_avg !== null) ? (weatherData.temp - weatherData.temp_history_avg) : 0
                    text: diff === 0 ? "Na média." :
                          Math.abs(diff) + "° " + (diff > 0 ? "acima" : "abaixo")
                    font.pixelSize: UI.Theme.fontSizeLarge
                    textColor: "#F2F2F7"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            UI.TextLabel {
                visible: !weatherData || weatherData.temp_history_avg === undefined || weatherData.temp_history_avg === null
                text: "Dados indisponíveis."
                font.pixelSize: UI.Theme.fontSizeLarge
                textColor: UI.Theme.textTertiary
                Layout.fillWidth: true
            }
            
            Item { Layout.fillHeight: true }

            UI.TextLabel {
                text: "Média: " + (weatherData && weatherData.temp_history_avg !== undefined && weatherData.temp_history_avg !== null ? weatherData.temp_history_avg : "--") + "°"
                font.pixelSize: UI.Theme.fontSizeSmall
                textColor: UI.Theme.textTertiary
                Layout.fillWidth: true
            }
        }
    }
}
