import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../../../AstreaComponents" as UI
import "../common" as WeatherCommon
import "../utils/WeatherFormat.js" as WeatherFormat
import "../../../AstreaI18n" as AstreaI18n

ColumnLayout {
    property var weatherData
    property var colors

    Layout.fillWidth: true
    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: hourlyContent.implicitHeight + 26
        radius: 20
        color: "#252529"
        border.color: "#34343A"
        border.width: 1

        ColumnLayout {
            id: hourlyContent
            anchors.fill: parent
            anchors.margins: 13
            spacing: 11

            UI.TextLabel {
                Layout.fillWidth: true
                text: weatherData ? weatherData.condition + ". Sensação térmica de " + WeatherFormat.temp(weatherData.feels_like) + ". Vento de " + WeatherFormat.wind(weatherData.wind) + "." : ""
                wrapMode: Text.WordWrap
                font.pixelSize: 13
                font.weight: 400
                lineHeight: 1.16
                textColor: "#F2F2F7"
            }

            UI.Divider {
                lineColor: "#3A3A40"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                UI.TextLabel {
                    text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.components.sections.hourly_forecast.text.previsao_por_hora"]) || "PREVISÃO POR HORA")
                    font.pixelSize: 10
                    font.weight: 600
                    textColor: UI.Theme.textTertiary
                    Layout.fillWidth: true
                }

                UI.TextLabel {
                    text: weatherData ? weatherData.hourly.length + "h" : ""
                    font.pixelSize: 10
                    font.weight: 600
                    textColor: UI.Theme.textTertiary
                }
            }

            ListView {
                id: hourlyList
                Layout.fillWidth: true
                Layout.preferredHeight: 106
                orientation: ListView.Horizontal
                spacing: 14
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: weatherData ? weatherData.hourly.slice(0, 24) : []

                delegate: Item {
                    width: 52
                    height: 104
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6

                        UI.TextLabel {
                            text: index === 0 ? "Agora" : modelData.time
                            font.pixelSize: 11
                            font.weight: 500
                            textColor: "#C7C7CF"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        WeatherCommon.WeatherIcon {
                            condition: modelData.cond
                            isoTime: modelData.iso_time || ""
                            iconSize: 26
                            Layout.alignment: Qt.AlignHCenter
                        }

                        UI.TextLabel {
                            text: WeatherFormat.percent(modelData.rain)
                            visible: modelData.rain > 0
                            font.pixelSize: UI.Theme.fontSizeMicro
                            font.weight: 600
                            textColor: "#9CC7FF"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        UI.TextLabel {
                            text: WeatherFormat.temp(modelData.temp)
                            font.pixelSize: 17
                            font.weight: 600
                            textColor: UI.Theme.textPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
