import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../../../AstreaComponents" as UI
import "../common" as WeatherCommon
import "../utils/WeatherFormat.js" as WeatherFormat

ColumnLayout {
    property var weatherData
    property var colors

    Layout.fillWidth: true
    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: hourlyContent.implicitHeight + 24
        radius: UI.Theme.cardRadius
        color: UI.Theme.cardBg
        opacity: 0.92

        ColumnLayout {
            id: hourlyContent
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            UI.TextLabel {
                Layout.fillWidth: true
                text: weatherData ? weatherData.condition + ". Sensação térmica de " + WeatherFormat.temp(weatherData.feels_like) + ". Vento de " + WeatherFormat.wind(weatherData.wind) + "." : ""
                wrapMode: Text.WordWrap
                font.pixelSize: 12
                font.weight: 400
                lineHeight: 1.12
                textColor: "#F2F2F7"
            }

            UI.Divider {
                lineColor: "#4A4A50"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                UI.TextLabel {
                    text: "Próximas horas"
                    font.pixelSize: UI.Theme.fontSizeSmall
                    font.weight: 600
                    textColor: UI.Theme.textTertiary
                    Layout.fillWidth: true
                }

                UI.TextLabel {
                    text: weatherData ? weatherData.hourly.length + "h" : ""
                    font.pixelSize: UI.Theme.fontSizeSmall
                    textColor: UI.Theme.textTertiary
                }
            }

            ListView {
                id: hourlyList
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                orientation: ListView.Horizontal
                spacing: 18
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: weatherData ? weatherData.hourly.slice(0, 24) : []

                delegate: Item {
                    width: 48
                    height: 96
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 5

                        UI.TextLabel {
                            text: index === 0 ? "Agora" : modelData.time
                            font.pixelSize: UI.Theme.fontSizeSmall
                            font.weight: 500
                            textColor: "#BFC0C8"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        WeatherCommon.WeatherIcon {
                            condition: modelData.cond
                            isoTime: modelData.iso_time || ""
                            iconSize: 24
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
                            font.pixelSize: 16
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
