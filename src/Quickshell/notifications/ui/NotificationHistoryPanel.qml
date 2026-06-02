import QtQuick
import Quickshell
import "../../bar"
import "../../bar/ui/components/system/popups"
import "../core" as Core

TopbarPopup {
    id: panel

    property string statePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/Astrea/notifications/state.json"
    readonly property int visibleLimit: 5
    readonly property int shownCount: Math.min(notificationStore.historyCount, visibleLimit)
    readonly property int hiddenCount: Math.max(0, notificationStore.historyCount - shownCount)
    readonly property int notificationCardHeight: 92
    readonly property int notificationSpacing: 10
    readonly property real contentWidth: panel.popupWidth - panel.cardPadding * 2
    readonly property int maxListHeight: visibleLimit * notificationCardHeight + Math.max(0, visibleLimit - 1) * notificationSpacing

    popupWidth: 384
    topOffset: 58
    cardPadding: 0
    cardRadius: 0
    contentSpacing: notificationSpacing
    backgroundColor: "transparent"
    borderColor: "transparent"
    animateScale: true
    hiddenScale: 0.985
    floatingAccessoryGap: Theme.spacing
    floatingAccessoryRightMargin: 2
    floatingAccessory: Component {
        Rectangle {
            id: clearAllButton

            implicitWidth: notificationStore.historyCount > 0 ? clearAllRow.implicitWidth + 22 : 0
            implicitHeight: notificationStore.historyCount > 0 ? 30 : 0
            radius: height / 2
            visible: notificationStore.historyCount > 0
            color: clearAllArea.containsMouse ? Theme.surface : Theme.background
            border.width: 1
            border.color: Theme.border

            Behavior on color { ColorAnimation { duration: Theme.animationHover } }
            Behavior on border.color { ColorAnimation { duration: Theme.animationHover } }

            Row {
                id: clearAllRow
                anchors.centerIn: parent
                spacing: Theme.spacingSmall

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰆴"
                    color: Theme.shellIconMain
                    font { family: Theme.iconFontFamily; pixelSize: Theme.fontSizeSmall }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Limpar tudo"
                    color: Theme.shellTextActive
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeCaption; weight: Font.DemiBold }
                }
            }

            MouseArea {
                id: clearAllArea
                anchors.fill: parent
                enabled: notificationStore.historyCount > 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: notificationStore.clearHistory()
            }
        }
    }

    Core.NotificationStore {
        id: notificationStore
        statePath: panel.statePath
    }

    Item {
        width: panel.contentWidth
        height: notificationStore.historyCount > 0 ? historyList.height : 92

        ListView {
            id: historyList
            width: parent.width
            height: notificationStore.historyCount > 0
                ? Math.min(contentHeight, panel.maxListHeight)
                : 0
            visible: notificationStore.historyCount > 0
            clip: true
            spacing: panel.notificationSpacing
            model: notificationStore.historyModel
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            delegate: Item {
                id: historyDelegate

                required property int index
                required property int notificationId
                required property string appName
                required property string appIcon
                required property string summary
                required property string body
                required property int urgency
                required property string createdAt

                width: historyList.width
                height: Math.max(panel.notificationCardHeight, notificationCard.implicitHeight)

                NotificationCard {
                    id: notificationCard
                    width: parent.width
                    height: implicitHeight
                    notificationId: historyDelegate.notificationId
                    appName: historyDelegate.appName
                    appIcon: historyDelegate.appIcon
                    summary: historyDelegate.summary
                    body: historyDelegate.body
                    urgency: historyDelegate.urgency
                    createdAt: historyDelegate.createdAt
                    autoDismissEnabled: false
                    onCloseRequested: notificationId => notificationStore.clearHistoryItem(notificationId)
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: 92
            radius: 22
            visible: notificationStore.historyCount === 0
            color: Theme.background
            border.width: 1
            border.color: Theme.border

            Column {
                anchors.centerIn: parent
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Notificacoes"
                    color: Theme.textActive
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Sem notificacoes"
                    color: Theme.textSecondary
                    font.pixelSize: 13
                }
            }
        }
    }

    Rectangle {
        width: Math.max(0, moreText.implicitWidth + 28)
        height: 30
        anchors.horizontalCenter: parent.horizontalCenter
        radius: 15
        visible: panel.hiddenCount > 0
        color: Theme.background
        border.width: 1
        border.color: Theme.border

        Text {
            id: moreText
            anchors.centerIn: parent
            text: panel.hiddenCount + " notificacoes a mais"
            color: Theme.shellTextSecondary
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeCaption; weight: Font.Medium }
        }
    }
}
