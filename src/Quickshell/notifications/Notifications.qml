import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "./core" as Core
import "./ui" as Ui

PanelWindow {
    id: root

    anchors {
        top: true
        right: true
    }

    implicitWidth: 402
    implicitHeight: Math.min(stack.implicitHeight + 68, 684)
    color: "transparent"
    visible: notificationStore.count > 0

    WlrLayershell.namespace: "astrea-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1

    property string statePath: Qt.resolvedUrl("state.json").toString().replace("file://", "")

    Core.NotificationStore {
        id: notificationStore
        statePath: root.statePath
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
            model: notificationStore.model

            delegate: Ui.NotificationCard {
                onCloseRequested: notificationId => notificationStore.closeNotification(notificationId)
            }
        }
    }
}
