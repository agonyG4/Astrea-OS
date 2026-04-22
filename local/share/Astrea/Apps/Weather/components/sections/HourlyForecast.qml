import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../common" as Common
import "../utils/WeatherFormat.js" as WeatherFormat

ColumnLayout {
    property var weatherData
    property var colors

    Layout.fillWidth: true
    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 10

        Common.TextLabel {
            text: "Próximas horas"
            font.pixelSize: 13
            font.weight: Font.Medium
            textColor: colors.secondary
            Layout.fillWidth: true
        }

        Common.TextLabel {
            text: weatherData ? weatherData.hourly.length + "h" : ""
            font.pixelSize: 12
            textColor: colors.tertiary
        }
    }

    ListView {
        id: hourlyList
        Layout.fillWidth: true
        Layout.preferredHeight: 142
        orientation: ListView.Horizontal
        spacing: 10
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: weatherData ? weatherData.hourly.slice(0, 24) : []

        delegate: Rectangle {
            width: 76
            height: 138
            radius: 14
            color: index === 0 ? colors.selected : colors.elevatedSurface
            border.color: index === 0 ? colors.accent : colors.subtleBorder
            border.width: 1

            Behavior on color {
                ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            Behavior on border.color {
                ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                Common.TextLabel {
                    text: index === 0 ? "Agora" : modelData.time
                    font.pixelSize: 12
                    textColor: colors.secondary
                    Layout.alignment: Qt.AlignHCenter
                }

                Common.DisplayLabel {
                    text: WeatherFormat.icon(modelData.cond)
                    font.pixelSize: 24
                    textColor: colors.primary
                    Layout.alignment: Qt.AlignHCenter
                }

                Common.TextLabel {
                    text: WeatherFormat.temp(modelData.temp)
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    textColor: colors.primary
                    Layout.alignment: Qt.AlignHCenter
                }

                Common.TextLabel {
                    text: "Sens. " + WeatherFormat.temp(modelData.feels_like)
                    font.pixelSize: 10
                    textColor: colors.tertiary
                    Layout.alignment: Qt.AlignHCenter
                }

                Common.Divider {
                    lineColor: colors.subtleBorder
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Common.TextLabel {
                        text: "☔"
                        font.pixelSize: 10
                        textColor: colors.accent
                    }

                    Common.TextLabel {
                        text: WeatherFormat.percent(modelData.rain)
                        font.pixelSize: 10
                        textColor: colors.secondary
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Common.TextLabel {
                        text: "↗"
                        font.pixelSize: 10
                        textColor: colors.secondary
                    }

                    Common.TextLabel {
                        text: WeatherFormat.wind(modelData.wind)
                        font.pixelSize: 10
                        textColor: colors.secondary
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
