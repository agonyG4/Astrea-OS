import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"

ScrollPage {
    id: root

    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color cardBg: Theme.cardBg
    readonly property color cardBorder: Theme.cardBorder

    ColumnLayout {
        width: parent.width
        spacing: 0

        SectionHeader {
            text: "PERFORMANCE"
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder
            implicitHeight: content.implicitHeight + 32

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                Text {
                    text: "Performance page placeholder"
                    color: root.textPrimary
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                Text {
                    text: "The route now resolves cleanly, and you can plug performance metrics here without changing the sidebar structure again."
                    color: root.textSecondary
                    wrapMode: Text.Wrap
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
        }
    }
}
