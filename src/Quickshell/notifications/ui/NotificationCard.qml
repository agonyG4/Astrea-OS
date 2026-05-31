import QtQuick
import QtQuick.Layouts
import "../../bar"
import "../../AstreaI18n" as AstreaI18n

Rectangle {
    id: card

    required property int notificationId
    required property string appName
    required property string appIcon
    required property string summary
    required property string body
    required property int urgency
    required property string createdAt

    property real slideOffset: 0
    property bool dismissing: false
    property bool held: false
    property bool autoDismissEnabled: true

    signal closeRequested(int notificationId)

    Layout.fillWidth: true
    implicitHeight: Math.max(92, content.implicitHeight + 28)
    radius: 22
    color: urgency >= 2 ? Qt.rgba(0.22, 0.06, 0.045, 0.92) : Theme.background
    border.color: urgency >= 2 ? Qt.rgba(1.0, 0.38, 0.24, 0.42) : Theme.border
    border.width: 1
    opacity: Math.max(0.18, 1 - (slideOffset / width) * 0.86)
    scale: held ? 1.015 : 1.0
    z: held ? 10 : 0

    transform: Translate {
        x: card.slideOffset
    }

    function dismiss() {
        if (dismissing)
            return

        dismissing = true
        settleAnimation.stop()
        dismissAnimation.to = card.width + 42
        dismissAnimation.start()
    }

    function resetAutoDismiss() {
        if (!autoDismissEnabled)
            return
        autoDismissTimer.stop()
        autoDismissTimer.start()
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }

    NumberAnimation {
        id: dismissAnimation
        target: card
        property: "slideOffset"
        duration: 280
        easing.type: Easing.InOutCubic
        onStopped: {
            if (card.dismissing)
                card.closeRequested(card.notificationId)
        }
    }

    NumberAnimation {
        id: settleAnimation
        target: card
        property: "slideOffset"
        to: 0
        duration: 240
        easing.type: Easing.OutBack
    }

    Timer {
        id: autoDismissTimer
        interval: 5000
        running: card.autoDismissEnabled
        repeat: false
        onTriggered: card.dismiss()
    }

    MouseArea {
        id: swipeArea

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor

        property real startX: 0

        onPressed: function(mouse) {
            card.held = true
            startX = mouse.x
            autoDismissTimer.stop()
            settleAnimation.stop()
            dismissAnimation.stop()
        }

        onPositionChanged: function(mouse) {
            if (!pressed || card.dismissing)
                return

            card.slideOffset = Math.max(0, mouse.x - startX)
        }

        onReleased: {
            card.held = false
            if (card.slideOffset > Math.min(130, card.width * 0.34))
                card.dismiss()
            else {
                settleAnimation.start()
                card.resetAutoDismiss()
            }
        }

        onCanceled: {
            card.held = false
            settleAnimation.start()
            card.resetAutoDismiss()
        }
    }

    RowLayout {
        id: content

        anchors {
            fill: parent
            margins: 14
        }
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            Layout.alignment: Qt.AlignTop
            radius: 14
            color: Theme.surface
            border.color: Theme.separator

            Text {
                anchors.centerIn: parent
                text: appIcon.length > 0 ? appIcon.slice(0, 1).toUpperCase() : appName.slice(0, 1).toUpperCase()
                color: Theme.textActive
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: appName
                    color: Theme.textSecondary
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    text: createdAt
                    color: Theme.textDim
                    font.pixelSize: 11
                }
            }

            Text {
                Layout.fillWidth: true
                text: summary
                color: Theme.textActive
                font.pixelSize: 15
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: body.length > 0
                text: body
                color: Theme.textSecondary
                font.pixelSize: 13
                lineHeight: 1.08
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignTop
            radius: 12
            color: closeArea.containsMouse ? Theme.separator : "transparent"

            Text {
                anchors.centerIn: parent
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.notifications.ui.notification_card.text.x"]) || "x")
                color: Theme.textSecondary
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.closeRequested(card.notificationId)
            }
        }
    }
}
