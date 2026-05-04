import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../common" as Common
import "../.."

Item {
    property var weatherData
    property var colors
    readonly property var alerts: weatherData && weatherData.alerts ? weatherData.alerts : []
    readonly property var mainAlert: alerts.length > 0 ? alerts[0] : null
    signal alertSelected(var alert)

    Layout.fillWidth: true
    Layout.preferredHeight: visible ? 78 : 0
    visible: mainAlert !== null

    Rectangle {
        anchors.fill: parent
        radius: Theme.cardRadius
        color: Theme.cardBg
        border.color: mainAlert ? (mainAlert.color || "#F96602") : "#F96602"
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 10
                Layout.fillHeight: true
                radius: 5
                color: mainAlert ? (mainAlert.color || "#F96602") : "#F96602"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Common.TextLabel {
                    text: "INMET"
                    font.pixelSize: 10
                    font.weight: 600
                    textColor: mainAlert ? (mainAlert.color || "#F96602") : "#F96602"
                }

                Common.DisplayLabel {
                    text: mainAlert ? (mainAlert.title || "Aviso meteorológico") : ""
                    font.pixelSize: 19
                    font.weight: 500
                    textColor: Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Common.TextLabel {
                    text: mainAlert ? (mainAlert.severity || "") : ""
                    font.pixelSize: 12
                    textColor: "#C9CAD2"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Common.TextLabel {
                text: alerts.length > 1 ? alerts.length + " avisos" : "Detalhes"
                font.pixelSize: 12
                font.weight: 500
                textColor: "#C9CAD2"
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: alertSelected(mainAlert)
        }
    }
}
