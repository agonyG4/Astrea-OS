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
            id: trendContent
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            UI.TextLabel {
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.components.sections.temperature_trend.text.madia_de_temp"]) || "MÉDIA DE TEMP")
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
                    text: diff === 0 ? AstreaI18n.I18n.tr("apps.weather.ui.components.sections.temperature_trend.text.on_average", "On average.") :
                          Math.abs(diff) + "° " + (diff > 0 ? AstreaI18n.I18n.tr("apps.weather.ui.components.sections.temperature_trend.text.above", "above") : AstreaI18n.I18n.tr("apps.weather.ui.components.sections.temperature_trend.text.below", "below"))
                    font.pixelSize: UI.Theme.fontSizeLarge
                    textColor: UI.Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            UI.TextLabel {
                visible: !weatherData || weatherData.temp_history_avg === undefined || weatherData.temp_history_avg === null
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.components.sections.temperature_trend.text.dados_indisponaveis"]) || "Dados indisponíveis.")
                font.pixelSize: UI.Theme.fontSizeLarge
                textColor: UI.Theme.textTertiary
                Layout.fillWidth: true
            }
            
            Item { Layout.fillHeight: true }

            UI.TextLabel {
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.components.sections.temperature_trend.text.madia"]) || "Média: ") + (weatherData && weatherData.temp_history_avg !== undefined && weatherData.temp_history_avg !== null ? weatherData.temp_history_avg : "--") + "°"
                font.pixelSize: UI.Theme.fontSizeSmall
                textColor: UI.Theme.textTertiary
                Layout.fillWidth: true
            }
        }
    }
}
