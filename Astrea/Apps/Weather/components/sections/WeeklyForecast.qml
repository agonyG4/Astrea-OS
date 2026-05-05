import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../common" as Common
import "../.."

ColumnLayout {
    property var weatherData
    property var colors
    signal daySelected(var day)

    Layout.fillWidth: true
    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: weeklyColumn.implicitHeight + 20
        radius: Theme.cardRadius
        color: Theme.cardBg
        opacity: 0.92

        ColumnLayout {
            id: weeklyColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 8

                Common.TextLabel {
                    text: "10 dias de previsão"
                    font.pixelSize: Theme.fontSmall
                    font.weight: 500
                    textColor: Theme.textTertiary
                    Layout.fillWidth: true
                }
            }

            Common.Divider {
                lineColor: "#4A4A50"
            }

            Repeater {
                model: weatherData ? weatherData.weekly.slice(0, 10) : []

                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46

                        RowLayout {
                            anchors.fill: parent
                            spacing: 0

                            Common.TextLabel {
                                text: index === 0 ? "Hoje" : modelData.day
                                font.pixelSize: Theme.fontMedium
                                font.weight: 400
                                textColor: Theme.textPrimary
                                Layout.preferredWidth: 76
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 34
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 0

                                Common.WeatherIcon {
                                    condition: modelData.cond
                                    iconSize: 22
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Common.TextLabel {
                                    visible: (modelData.rain || 0) > 0
                                    text: modelData.rain + "%"
                                    font.pixelSize: Theme.fontTiny
                                    font.weight: 500
                                    textColor: Theme.rain
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            Common.TextLabel {
                                text: modelData.lo + "°"
                                font.pixelSize: 14
                                font.weight: 400
                                textColor: Theme.textTertiary
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 38
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 3
                                radius: 2
                                color: "#7E7E88"

                                Rectangle {
                                    width: parent.width * 0.42
                                    height: parent.height
                                    anchors.right: parent.right
                                    radius: 2
                                    color: Theme.sun
                                }
                            }

                            Common.TextLabel {
                                text: modelData.hi + "°"
                                font.pixelSize: 14
                                font.weight: 400
                                textColor: Theme.textPrimary
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 38
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: daySelected(modelData)
                        }
                    }

                    Common.Divider {
                        lineColor: "#424248"
                        visible: index < Math.min(10, weatherData ? weatherData.weekly.length : 0) - 1
                    }
                }
            }
        }
    }
}
