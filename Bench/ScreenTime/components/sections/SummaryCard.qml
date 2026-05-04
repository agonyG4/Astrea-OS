import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../common" as Common
import "../.."

Rectangle {
    property var summaryData

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + 28
    radius: Theme.cardRadius
    color: Theme.cardBg
    opacity: 0.92
    border.color: "#3A3A40"
    border.width: 1

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Common.TextLabel {
                text: summaryData ? summaryData.selected_day : ""
                    font.pixelSize: Theme.fontSmall
                    font.weight: 600
                    textColor: Theme.textTertiary
                }

                Common.DisplayLabel {
                    text: summaryData && summaryData.day ? summaryData.day.duration : "0s"
                    font.pixelSize: Theme.fontXLarge
                    font.weight: 600
                    textColor: Theme.textPrimary
                }
            }

            Rectangle {
                Layout.preferredWidth: 10
                Layout.preferredHeight: 10
                radius: 5
                color: summaryData && summaryData.health && summaryData.health.running ? Theme.green : Theme.amber
            }
        }

        Common.Divider {}

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 6
            columnSpacing: 10

            StatItem {
                label: "Ativo"
                value: summaryData && summaryData.day ? summaryData.day.active_duration : "0s"
            }

            StatItem {
                label: "Sem foco"
                value: summaryData && summaryData.day ? summaryData.day.unknown_duration : "0s"
            }

            StatItem {
                label: "Total"
                value: summaryData && summaryData.totals ? summaryData.totals.duration : "0s"
            }
        }

        Common.TextLabel {
            Layout.fillWidth: true
            text: summaryData && summaryData.current ? "Agora: " + summaryData.current.app + " - " + summaryData.current.category : "Agora: unknown"
            elide: Text.ElideRight
            font.pixelSize: Theme.fontRegular
            textColor: Theme.textSecondary
        }
    }
}
