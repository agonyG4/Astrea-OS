import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../../../AstreaComponents" as UI
import "../common" as WeatherCommon
import "../../../AstreaI18n" as AstreaI18n

ColumnLayout {
    property var weatherData
    property var colors
    function displayTimeMinutes(value) {
        var text = (value || "").trim()
        if (text.length === 0)
            return -1
        var upper = text.toUpperCase()
        var isPm = upper.indexOf("PM") !== -1
        var isAm = upper.indexOf("AM") !== -1
        var parts = text.split(" ")[0].split(":")
        if (parts.length < 2)
            return -1
        var hour = parseInt(parts[0])
        var minute = parseInt(parts[1])
        if (isNaN(hour) || isNaN(minute))
            return -1
        if (isPm && hour < 12)
            hour += 12
        if (isAm && hour === 12)
            hour = 0
        return hour * 60 + minute
    }
    readonly property string nextSunEventLabel: sunInfo.isAfterSunset
        ? AstreaI18n.I18n.tr("apps.weather.ui.components.sections.current_summary.text.sunrise", "Sunrise")
        : AstreaI18n.I18n.tr("apps.weather.ui.components.sections.current_summary.text.sunset", "Sunset")
    readonly property string nextSunEventTime: {
        if (!weatherData) return "--"
        if (sunInfo.isAfterSunset) {
            return (weatherData.weekly && weatherData.weekly.length > 1)
                ? weatherData.weekly[1].sunrise
                : weatherData.sunrise
        }
        return weatherData.sunset
    }

    Layout.fillWidth: true
    Layout.bottomMargin: 2
    spacing: 3

    UI.DisplayLabel {
        Layout.fillWidth: true
        text: weatherData ? weatherData.city : ""
        font.pixelSize: 22
        font.weight: 400
        horizontalAlignment: Text.AlignHCenter
        topPadding: 2
        textColor: UI.Theme.textPrimary
    }

    UI.DisplayLabel {
        Layout.fillWidth: true
        text: weatherData && weatherData.temp !== undefined ? weatherData.temp + "°" : "--"
        font.pixelSize: 86
        font.weight: 200
        lineHeight: 0.82
        horizontalAlignment: Text.AlignHCenter
        textColor: UI.Theme.textPrimary
    }

    UI.TextLabel {
        Layout.fillWidth: true
        text: weatherData ? weatherData.condition : ""
        font.pixelSize: 15
        font.weight: 400
        horizontalAlignment: Text.AlignHCenter
        textColor: UI.Theme.textSecondary
    }

    UI.TextLabel {
        Layout.fillWidth: true
        text: weatherData ? AstreaI18n.I18n.tr("apps.weather.ui.components.sections.current_summary.text.high_short", "H:") + weatherData.temp_max + "°  " + AstreaI18n.I18n.tr("apps.weather.ui.components.sections.current_summary.text.low_short", "L:") + weatherData.temp_min + "°" : ""
        font.pixelSize: 14
        font.weight: 600
        horizontalAlignment: Text.AlignHCenter
        textColor: UI.Theme.textPrimary
        topPadding: 2
        bottomPadding: 2
    }

    Rectangle {
        id: sunInfo
        Layout.fillWidth: true
        Layout.topMargin: 10
        Layout.bottomMargin: 8
        implicitHeight: 52
        radius: 18
        color: UI.Theme.cardBg
        border.color: UI.Theme.cardBorder
        border.width: 1

        property bool isAfterSunset: {
            if (!weatherData || !weatherData.sunset) return false
            var now = new Date()
            var currentMinutes = now.getHours() * 60 + now.getMinutes()
            var sunsetMin = displayTimeMinutes(weatherData.sunset)
            return sunsetMin >= 0 && currentMinutes > sunsetMin
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: weatherData && weatherData.wind !== undefined

                WeatherCommon.WeatherIcon {
                    condition: "vento"
                    iconSize: 18
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    spacing: 1

                    UI.TextLabel {
                        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.components.sections.current_summary.text.vento"]) || "WIND")
                        font.pixelSize: 10
                        font.weight: 600
                        textColor: UI.Theme.textTertiary
                    }

                    UI.TextLabel {
                        text: weatherData ? weatherData.wind + " km/h" : "--"
                        font.pixelSize: 13
                        font.weight: 500
                        textColor: UI.Theme.textPrimary
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: 12
                Layout.bottomMargin: 12
                color: UI.Theme.cardBorder
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                WeatherCommon.WeatherIcon {
                    condition: sunInfo.isAfterSunset ? "nascer do sol" : "pôr do sol"
                    iconSize: 18
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    spacing: 1

                    UI.TextLabel {
                        text: nextSunEventLabel.toUpperCase()
                        font.pixelSize: 10
                        font.weight: 600
                        textColor: UI.Theme.textTertiary
                    }

                    UI.TextLabel {
                        text: nextSunEventTime
                        font.pixelSize: 13
                        font.weight: 500
                        textColor: UI.Theme.textPrimary
                    }
                }
            }
        }
    }
}
