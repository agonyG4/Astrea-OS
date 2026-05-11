import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../../../AstreaComponents" as UI
import "../common" as WeatherCommon

ColumnLayout {
    property var weatherData
    property var colors

    Layout.fillWidth: true
    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 160
        radius: UI.Theme.cardRadius
        color: UI.Theme.cardBg
        opacity: 0.92

        ColumnLayout {
            id: aqiContent
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            UI.TextLabel {
                text: "QUALIDADE DO AR"
                font.pixelSize: UI.Theme.fontSizeSmall
                font.weight: 600
                textColor: UI.Theme.textTertiary
                Layout.fillWidth: true
            }

            UI.DisplayLabel {
                text: aqiText(weatherData ? weatherData.aqi : 0)
                font.pixelSize: 18
                font.weight: 500
                textColor: UI.Theme.textPrimary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                Layout.topMargin: 4

                Rectangle {
                    id: bar
                    anchors.fill: parent
                    radius: 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#50C878" } // Boa
                        GradientStop { position: 0.2; color: "#FFD700" } // Moderada
                        GradientStop { position: 0.4; color: "#FF8C00" } // Insalubre sensíveis
                        GradientStop { position: 0.6; color: "#FF4500" } // Insalubre
                        GradientStop { position: 0.8; color: "#9400D3" } // Muito insalubre
                        GradientStop { position: 1.0; color: "#7E0023" } // Perigosa
                    }
                }

                Rectangle {
                    property real pos: Math.min(1.0, (weatherData ? weatherData.aqi : 0) / 300.0)
                    x: (parent.width - width) * pos
                    width: 4
                    height: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#FFFFFF"
                    radius: 2
                    border.color: "#000000"
                    border.width: 1
                }
            }

            Item { Layout.fillHeight: true }

            UI.TextLabel {
                text: "O nível é " + (weatherData ? weatherData.aqi : 0) + "."
                font.pixelSize: UI.Theme.fontSizeSmall
                textColor: UI.Theme.textTertiary
                Layout.fillWidth: true
            }
        }
    }

    function aqiText(val) {
        if (!val && val !== 0) return "Sem dados"
        if (val <= 50) return "Boa"
        if (val <= 100) return "Moderada"
        if (val <= 150) return "Insalubre (grupos sensíveis)"
        if (val <= 200) return "Insalubre"
        if (val <= 300) return "Muito Insalubre"
        return "Perigosa"
    }
}
