import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../../../AstreaComponents" as UI
import "../common" as WeatherCommon

ColumnLayout {
    property var weatherData
    property var colors
    signal daySelected(var day)

    Layout.fillWidth: true
    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: weeklyColumn.implicitHeight + 20
        radius: UI.Theme.cardRadius
        color: UI.Theme.cardBg
        opacity: 0.92

        ColumnLayout {
            id: weeklyColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 8

                UI.TextLabel {
                    text: "10 dias de previsão"
                    font.pixelSize: UI.Theme.fontSizeSmall
                    font.weight: 500
                    textColor: UI.Theme.textTertiary
                    Layout.fillWidth: true
                }
            }

            UI.Divider {
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

                            UI.TextLabel {
                                text: index === 0 ? "Hoje" : modelData.day
                                font.pixelSize: UI.Theme.fontSizeTitle
                                font.weight: 400
                                textColor: UI.Theme.textPrimary
                                Layout.preferredWidth: 76
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 34
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
                                    textColor: "#9CC7FF"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            UI.TextLabel {
                                text: modelData.lo + "°"
                                font.pixelSize: 14
                                font.weight: 400
                                textColor: UI.Theme.textTertiary
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
                                    color: "#F5D44A"
                                }
                            }

                            UI.TextLabel {
                                text: modelData.hi + "°"
                                font.pixelSize: 14
                                font.weight: 400
                                textColor: UI.Theme.textPrimary
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

                    UI.Divider {
                        lineColor: "#424248"
                        visible: index < Math.min(10, weatherData ? weatherData.weekly.length : 0) - 1
                    }
                }
            }
        }
    }
}
