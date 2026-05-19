import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../AstreaComponents"
import "../../AstreaI18n" as AstreaI18n

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
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.screensaver.text.screensaver"]) || "SCREENSAVER")
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
                    text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.screensaver.text.screensaver_page_placeholder"]) || "Screensaver page placeholder")
                    color: root.textPrimary
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                Text {
                    text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.paper.screensaver.text.this_route_existed_in_navigation_but_not_on_disk"]) || "This route existed in navigation but not on disk. It now has a safe landing page while the feature is implemented.")
                    color: root.textSecondary
                    wrapMode: Text.Wrap
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
        }
    }
}
