import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../../../AstreaComponents" as UI
import "../common" as WeatherCommon
import "../../../AstreaI18n" as AstreaI18n

ColumnLayout {
    id: root
    property var weatherData
    property var colors
    signal daySelected(var day)

    Layout.fillWidth: true
    spacing: 0

    function days() {
        return weatherData ? weatherData.weekly.slice(0, 10) : []
    }

    function lowestTemp() {
        var list = days()
        var value = 999
        for (var i = 0; i < list.length; i++)
            value = Math.min(value, Number(list[i].lo))
        return value === 999 ? 0 : value
    }

    function highestTemp() {
        var list = days()
        var value = -999
        for (var i = 0; i < list.length; i++)
            value = Math.max(value, Number(list[i].hi))
        return value === -999 ? 1 : value
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: weeklyColumn.implicitHeight + 22
        radius: 20
        color: UI.Theme.cardBg
        border.color: UI.Theme.cardBorder
        border.width: 1

        ColumnLayout {
            id: weeklyColumn
            anchors.fill: parent
            anchors.margins: 13
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 8

                UI.TextLabel {
                    text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.weather.ui.components.sections.weekly_forecast.text.previsao_de_10_dias"]) || "PREVISÃO DE 10 DIAS")
                    font.pixelSize: 10
                    font.weight: 600
                    textColor: UI.Theme.textTertiary
                    Layout.fillWidth: true
                }
            }

            UI.Divider {
                lineColor: UI.Theme.cardBorder
            }

            Repeater {
                model: root.days()

                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48

                        RowLayout {
                            anchors.fill: parent
                            spacing: 0

                            UI.TextLabel {
                                text: index === 0 ? AstreaI18n.I18n.tr("apps.weather.ui.components.sections.weekly_forecast.text.today", "Today") : modelData.day
                                font.pixelSize: UI.Theme.fontSizeTitle
                                font.weight: 400
                                textColor: UI.Theme.textPrimary
                                Layout.preferredWidth: 72
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 38
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 0

                                WeatherCommon.WeatherIcon {
                                    condition: modelData.cond
                                    iconSize: 22
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                UI.TextLabel {
                                    visible: (modelData.rain || 0) > 0
                                    text: modelData.rain + "%"
                                    font.pixelSize: UI.Theme.fontSizeMicro
                                    font.weight: 500
                                    textColor: UI.Theme.accent
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            UI.TextLabel {
                                text: modelData.lo + "°"
                                font.pixelSize: 15
                                font.weight: 400
                                textColor: UI.Theme.textTertiary
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 36
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 14
                                Layout.leftMargin: 8
                                Layout.rightMargin: 8

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 4
                                    radius: 2
                                    color: UI.Theme.textTertiary
                                }

                                Rectangle {
                                    property real globalLo: root.lowestTemp()
                                    property real globalHi: root.highestTemp()
                                    property real span: Math.max(1, globalHi - globalLo)
                                    property real dayLo: Number(modelData.lo)
                                    property real dayHi: Number(modelData.hi)
                                    x: Math.max(0, parent.width * ((dayLo - globalLo) / span))
                                    width: Math.max(24, parent.width * ((dayHi - dayLo) / span))
                                    height: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: 2
                                    color: "#F5D44A"
                                }
                            }

                            UI.TextLabel {
                                text: modelData.hi + "°"
                                font.pixelSize: 15
                                font.weight: 400
                                textColor: UI.Theme.textPrimary
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 36
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: daySelected(modelData)
                        }
                    }

                    UI.Divider {
                        lineColor: UI.Theme.cardBorder
                        visible: index < Math.min(10, weatherData ? weatherData.weekly.length : 0) - 1
                    }
                }
            }
        }
    }
}
