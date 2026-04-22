import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../common" as Common
import "../utils/WeatherFormat.js" as WeatherFormat

ColumnLayout {
    property var weatherData
    property var colors

    Layout.fillWidth: true
    spacing: 0

    Repeater {
        model: weatherData ? weatherData.weekly.slice(0, 8) : []

        delegate: ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 12
                Layout.bottomMargin: 12

                Common.TextLabel {
                    text: index === 0 ? "Hoje" : modelData.day
                    font.pixelSize: 15
                    textColor: colors.primary
                    Layout.fillWidth: true
                }

                Common.DisplayLabel {
                    text: WeatherFormat.icon(modelData.cond)
                    font.pixelSize: 18
                    textColor: colors.primary
                }

                Item { implicitWidth: 12 }

                Common.TextLabel {
                    text: modelData.hi
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    textColor: colors.primary
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                }

                Common.TextLabel {
                    text: modelData.lo
                    font.pixelSize: 15
                    textColor: colors.secondary
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                }
            }

            Common.Divider {
                lineColor: colors.subtleBorder
                visible: index < (weatherData ? weatherData.weekly.length - 1 : 0)
            }
        }
    }
}
