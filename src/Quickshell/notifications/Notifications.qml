import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../bar"

PanelWindow {
    id: root

    anchors {
        top: true
        right: true
    }

    implicitWidth: 402
    implicitHeight: Math.min(stack.implicitHeight + 68, 684)
    color: "transparent"
    visible: notificationModel.count > 0

    WlrLayershell.namespace: "astrea-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1

    property string statePath: Qt.resolvedUrl("state.json").toString().replace("file://", "")

    function modelIndexFor(notificationId) {
        for (let index = 0; index < notificationModel.count; index++) {
            if (notificationModel.get(index).notificationId === notificationId)
                return index
        }
        return -1
    }

    function normalizedNotification(item) {
        return {
            notificationId: item.id || 0,
            appName: item.appName || "Application",
            appIcon: item.appIcon || "",
            summary: item.summary || "Notification",
            body: item.body || "",
            urgency: item.urgency || 1,
            createdAt: item.createdAt || ""
        }
    }

    function syncNotifications(items) {
        const seen = {}

        for (const item of items) {
            const notification = normalizedNotification(item)
            seen[notification.notificationId] = true

            const index = modelIndexFor(notification.notificationId)
            if (index >= 0)
                notificationModel.set(index, notification)
            else
                notificationModel.append(notification)
        }

        for (let index = notificationModel.count - 1; index >= 0; index--) {
            const currentId = notificationModel.get(index).notificationId
            if (!seen[currentId])
                notificationModel.remove(index)
        }
    }

    function closeNotification(notificationId) {
        closeProc.command = [
            "gdbus",
            "call",
            "--session",
            "--dest", "org.freedesktop.Notifications",
            "--object-path", "/org/freedesktop/Notifications",
            "--method", "org.freedesktop.Notifications.CloseNotification",
            String(notificationId)
        ]
        closeProc.running = false
        closeProc.running = true
    }

    function loadState() {
        try {
            const payload = JSON.parse(stateFile.text())
            root.syncNotifications(payload.notifications || [])
        } catch (error) {
        }
    }

    Component.onCompleted: loadState()

    Process {
        id: closeProc
        command: []
        running: false
    }

    Timer {
        id: stateReloadDebounce
        interval: 150
        repeat: false
        onTriggered: stateFile.reload()
    }

    FileView {
        id: stateFile
        path: root.statePath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: stateReloadDebounce.restart()
        onLoaded: root.loadState()
    }

    ColumnLayout {
        id: stack
        anchors {
            top: parent.top
            right: parent.right
            left: parent.left
            topMargin: 64
            rightMargin: 18
        }
        spacing: 10

        Repeater {
            model: ListModel {
                id: notificationModel
            }

            delegate: Rectangle {
                id: card

                property real slideOffset: 0
                property bool dismissing: false
                property bool held: false

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
                            root.closeNotification(notificationId)
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
                    running: true
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
                            text: "x"
                            color: Theme.textSecondary
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeNotification(notificationId)
                        }
                    }
                }
            }
        }
    }
}
