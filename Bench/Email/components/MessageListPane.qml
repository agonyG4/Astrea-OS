import QtQuick
import QtQuick.Layouts
import "../AstreaComponents" as Astrea

Rectangle {
    id: pane

    property var messagesModel
    property string selectedFolder: "Inbox"
    property string selectedMessageId: ""
    property string searchText: ""
    property string messageFilter: "all"
    property string emptyIcon: "\uf002"
    property string emptyTitle: "No messages here"
    property string emptyAction: "Clear filters"
    property int unreadCount: 0
    property int starredCount: 0
    property bool canLoadMore: false
    property bool loadingMore: false
    property string resultLabel: ""
    property color selectedBg: Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.16)
    property color selectedBorder: Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.34)
    property color softSurface: Astrea.Theme.cardBg
    property color hoverSurface: Qt.rgba(1, 1, 1, 0.060)
    signal filterRequested(string filter)
    signal messageRequested(string messageId)
    signal clearFiltersRequested()
    signal loadMoreRequested()

    radius: Astrea.Theme.cardRadius
    color: Astrea.Theme.cardBg
    border.width: 1
    border.color: Astrea.Theme.cardBorder
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Astrea.Theme.spacingMedium
        spacing: Astrea.Theme.spacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Astrea.Theme.spacing

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Astrea.TextLabel {
                    text: pane.selectedFolder === "All" ? "All Mail" : pane.selectedFolder
                    textColor: Astrea.Theme.textPrimary
                    font.pixelSize: Astrea.Theme.fontSizeTitle
                    font.weight: Astrea.Theme.fontWeightDemiBold
                }

                Astrea.TextLabel {
                    Layout.fillWidth: true
                    text: pane.unreadCount + " unread"
                    textColor: Astrea.Theme.textSecondary
                    font.pixelSize: Astrea.Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
            }

            CountPill {
                label: pane.unreadCount
                visible: pane.unreadCount > 0
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Astrea.Theme.spacingSmall

            FilterChip {
                label: "All"
                selected: pane.messageFilter === "all"
                selectedBg: pane.selectedBg
                selectedBorder: pane.selectedBorder
                softSurface: pane.softSurface
                hoverSurface: pane.hoverSurface
                onClicked: pane.filterRequested("all")
            }

            FilterChip {
                label: "Unread"
                count: pane.unreadCount
                selected: pane.messageFilter === "unread"
                selectedBg: pane.selectedBg
                selectedBorder: pane.selectedBorder
                softSurface: pane.softSurface
                hoverSurface: pane.hoverSurface
                onClicked: pane.filterRequested("unread")
            }

            FilterChip {
                label: "Starred"
                count: pane.starredCount
                selected: pane.messageFilter === "starred"
                selectedBg: pane.selectedBg
                selectedBorder: pane.selectedBorder
                softSurface: pane.softSurface
                hoverSurface: pane.hoverSurface
                onClicked: pane.filterRequested("starred")
            }

            Item { Layout.fillWidth: true }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: messageList
                anchors.fill: parent
                visible: pane.messagesModel && pane.messagesModel.count > 0
                clip: true
                spacing: Astrea.Theme.spacingSmall
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 640
                reuseItems: true
                model: pane.messagesModel

                delegate: MailRow {
                    width: messageList.width
                    messageId: model.messageId
                    fromName: model.fromName
                    subject: model.subject
                    preview: model.preview
                    timestamp: model.timestamp
                    tag: model.tag
                    starred: model.starred
                    isRead: model.isRead
                    selected: model.messageId === pane.selectedMessageId
                    selectedBg: pane.selectedBg
                    selectedBorder: pane.selectedBorder
                    hoverSurface: pane.hoverSurface
                    onClicked: pane.messageRequested(model.messageId)
                }
            }

            Item {
                anchors.fill: parent
                visible: pane.messagesModel && pane.messagesModel.count === 0

                Column {
                    anchors.centerIn: parent
                    spacing: Astrea.Theme.spacingSmall

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: pane.emptyIcon
                        color: Astrea.Theme.textTertiary
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 28
                    }

                    Astrea.TextLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(parent.parent.width - 48, 240)
                        horizontalAlignment: Text.AlignHCenter
                        text: pane.searchText !== "" ? "No messages match your search" : pane.emptyTitle
                        textColor: Astrea.Theme.textSecondary
                        font.pixelSize: Astrea.Theme.fontSizeNormal
                        wrapMode: Text.WordWrap
                    }

                    Astrea.Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: pane.searchText !== "" || pane.messageFilter !== "all"
                        text: pane.emptyAction
                        flat: true
                        onClicked: pane.clearFiltersRequested()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Astrea.Theme.spacing
            visible: pane.canLoadMore || pane.resultLabel !== ""

            Astrea.TextLabel {
                Layout.fillWidth: true
                text: pane.resultLabel
                textColor: Astrea.Theme.textTertiary
                font.pixelSize: Astrea.Theme.fontSizeSmall
                elide: Text.ElideRight
            }

            Astrea.Button {
                visible: pane.canLoadMore
                text: pane.loadingMore ? "Loading" : "Load more"
                iconText: pane.loadingMore ? "\uf021" : "\uf063"
                iconFontFamily: "JetBrainsMono Nerd Font"
                flat: true
                enabled: !pane.loadingMore
                onClicked: pane.loadMoreRequested()
            }
        }
    }
}
