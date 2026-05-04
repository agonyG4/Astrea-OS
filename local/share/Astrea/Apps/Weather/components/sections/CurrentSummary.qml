import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../common" as Common
import "../.."

ColumnLayout {
    property var weatherData
    property var colors

    Layout.fillWidth: true
    spacing: 0

    Common.DisplayLabel {
        Layout.fillWidth: true
        text: weatherData ? weatherData.city : ""
        font.pixelSize: Theme.fontLarge
        font.weight: 400
        horizontalAlignment: Text.AlignHCenter
        topPadding: 8
        textColor: Theme.textPrimary
    }

    Common.DisplayLabel {
        Layout.fillWidth: true
        text: weatherData ? weatherData.temp : "--"
        font.pixelSize: Theme.fontGiant
        font.weight: 200
        lineHeight: 0.88
        horizontalAlignment: Text.AlignHCenter
        textColor: Theme.textPrimary
    }

    Common.TextLabel {
        Layout.fillWidth: true
        text: weatherData ? weatherData.condition : ""
        font.pixelSize: Theme.fontMedium
        font.weight: 400
        horizontalAlignment: Text.AlignHCenter
        textColor: Theme.textSecondary
        topPadding: 0
    }

    Common.TextLabel {
        Layout.fillWidth: true
        text: weatherData ? "H:" + weatherData.temp_max + "°  L:" + weatherData.temp_min + "°" : ""
        font.pixelSize: 14
        font.weight: 600
        horizontalAlignment: Text.AlignHCenter
        textColor: "#F2F2F7"
        topPadding: 2
        bottomPadding: 2
    }



    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        spacing: 16

        // Vento
        RowLayout {
            spacing: 6
            visible: weatherData && weatherData.wind !== undefined
            Common.WeatherIcon {
                condition: "vento"
                iconSize: 16
                Layout.alignment: Qt.AlignVCenter
            }
            Common.TextLabel {
                text: weatherData ? weatherData.wind + " km/h" : ""
                font.pixelSize: Theme.fontRegular
                font.weight: 500
                textColor: Theme.textSecondary
            }
        }

    }

    RowLayout {
        id: sunInfo
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: 12
        spacing: 6

        property bool isAfterSunset: {
            if (!weatherData || !weatherData.sunset) return false
            var now = new Date()
            var currentMinutes = now.getHours() * 60 + now.getMinutes()
            var sunsetParts = weatherData.sunset.split(":")
            var sunsetMin = parseInt(sunsetParts[0]) * 60 + parseInt(sunsetParts[1])
            return currentMinutes > sunsetMin
        }

        Common.WeatherIcon {
            condition: sunInfo.isAfterSunset ? "nascer do sol" : "pôr do sol"
            iconSize: 18
            Layout.alignment: Qt.AlignVCenter
        }

        Common.TextLabel {
            text: {
                if (!weatherData) return ""
                if (sunInfo.isAfterSunset) {
                    // Tenta pegar o nascer do sol de amanhã (weekly[1])
                    var nextSunrise = (weatherData.weekly && weatherData.weekly.length > 1) 
                        ? weatherData.weekly[1].sunrise 
                        : weatherData.sunrise
                    return "Nascer do sol " + nextSunrise
                } else {
                    return "Pôr do sol " + weatherData.sunset
                }
            }
            font.pixelSize: Theme.fontRegular
            font.weight: 500
            textColor: Theme.textSecondary
        }
    }
}
