import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../common" as Common
import "../.."

Rectangle {
    property string title: ""
    property var rows: []
    property real totalSeconds: 0
    property color accentColor: Theme.accent

    Layout.fillWidth: true
    implicitHeight: listContent.implicitHeight + 24
    radius: Theme.cardRadius
    color: Theme.cardBg
    opacity: 0.92
    border.color: "#3A3A40"
    border.width: 1

    ColumnLayout {
        id: listContent
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            Common.TextLabel {
                Layout.fillWidth: true
                text: title
                font.pixelSize: Theme.fontSmall
                font.weight: 700
                textColor: Theme.textTertiary
            }

            Common.TextLabel {
                text: rows ? rows.length : 0
                font.pixelSize: Theme.fontSmall
                textColor: Theme.textTertiary
            }
        }

        Common.Divider {}

        Repeater {
            model: rows || []

            delegate: ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Common.TextLabel {
                        Layout.fillWidth: true
                        text: modelData.label || modelData.id
                        font.pixelSize: Theme.fontRegular
                        font.weight: 500
                        textColor: Theme.textPrimary
                        elide: Text.ElideRight
                    }

                    Common.TextLabel {
                        text: modelData.duration
                        font.pixelSize: Theme.fontRegular
                        font.weight: 600
                        textColor: Theme.textSecondary
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 5
                    radius: 3
                    color: Theme.track

                    Rectangle {
                        width: parent.width * Math.min(1, (modelData.seconds || 0) / Math.max(1, totalSeconds))
                        height: parent.height
                        radius: parent.radius
                        color: accentColor
                    }
                }
            }
        }

        Common.TextLabel {
            Layout.fillWidth: true
            visible: !rows || rows.length === 0
            text: "Sem dados ainda"
            font.pixelSize: Theme.fontRegular
            textColor: Theme.textTertiary
        }
    }
}
