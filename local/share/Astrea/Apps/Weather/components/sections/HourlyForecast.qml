import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../common" as Common
import "../utils/WeatherFormat.js" as WeatherFormat
import "../.."

ColumnLayout {
    property var weatherData
    property var colors

    Layout.fillWidth: true
    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: hourlyContent.implicitHeight + 24
        radius: Theme.cardRadius
        color: Theme.cardBg
        opacity: 0.92

        ColumnLayout {
            id: hourlyContent
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Common.TextLabel {
                Layout.fillWidth: true
                text: weatherData ? weatherData.condition + ". Sensação térmica de " + WeatherFormat.temp(weatherData.feels_like) + ". Vento de " + WeatherFormat.wind(weatherData.wind) + "." : ""
                wrapMode: Text.WordWrap
                font.pixelSize: 12
                font.weight: 400
                lineHeight: 1.12
                textColor: "#F2F2F7"
            }

            Common.Divider {
                lineColor: "#4A4A50"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Common.TextLabel {
                    text: "Próximas horas"
                    font.pixelSize: Theme.fontSmall
                    font.weight: 600
                    textColor: Theme.textTertiary
                    Layout.fillWidth: true
                }

                Common.TextLabel {
                    text: weatherData ? weatherData.hourly.length + "h" : ""
                    font.pixelSize: Theme.fontSmall
                    textColor: Theme.textTertiary
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

                        Common.TextLabel {
                            text: index === 0 ? "Agora" : modelData.time
                            font.pixelSize: Theme.fontSmall
                            font.weight: 500
                            textColor: "#BFC0C8"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Common.WeatherIcon {
                            condition: modelData.cond
                            isoTime: modelData.iso_time || ""
                            iconSize: 24
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Common.TextLabel {
                            text: WeatherFormat.percent(modelData.rain)
                            visible: modelData.rain > 0
                            font.pixelSize: Theme.fontTiny
                            font.weight: 600
                            textColor: Theme.rain
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Common.TextLabel {
                            text: WeatherFormat.temp(modelData.temp)
                            font.pixelSize: 16
                            font.weight: 600
                            textColor: Theme.textPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
