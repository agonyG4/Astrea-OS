import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../../../AstreaComponents" as UI
import "../common" as WeatherCommon
import "../../../AstreaI18n" as AstreaI18n

Item {
    property var weatherData
    property var colors
    readonly property var alerts: weatherData && weatherData.alerts ? weatherData.alerts : []
    readonly property var mainAlert: alerts.length > 0 ? alerts[0] : null
    readonly property string sourceLabel: mainAlert ? (mainAlert.source || "Weather") : ""
    signal alertSelected(var alert)

    Layout.fillWidth: true
    Layout.preferredHeight: visible ? 78 : 0
    visible: mainAlert !== null

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: UI.Theme.cardBg
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

                UI.TextLabel {
                    text: sourceLabel
                    font.pixelSize: 10
                    font.weight: 600
                    textColor: mainAlert ? (mainAlert.color || "#F96602") : "#F96602"
                }

                UI.DisplayLabel {
                    text: mainAlert ? (mainAlert.title || AstreaI18n.I18n.tr("apps.weather.ui.components.sections.weather_alerts.text.weather_alert", "Weather alert")) : ""
                    font.pixelSize: 19
                    font.weight: 500
                    textColor: UI.Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                UI.TextLabel {
                    text: mainAlert ? (mainAlert.severity || "") : ""
                    font.pixelSize: 12
                    textColor: UI.Theme.textSecondary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            UI.TextLabel {
                text: alerts.length > 1
                    ? AstreaI18n.I18n.tr("apps.weather.ui.components.sections.weather_alerts.text.alert_count", "{count} alerts", { count: alerts.length })
                    : AstreaI18n.I18n.tr("apps.weather.ui.components.sections.weather_alerts.text.details", "Details")
                font.pixelSize: 12
                font.weight: 500
                textColor: UI.Theme.textSecondary
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
