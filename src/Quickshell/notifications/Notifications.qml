import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "./core" as Core
import "./ui" as Ui

Scope {
    id: root

    property string statePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/Astrea/notifications/state.json"

    Core.NotificationStore {
        id: notificationStore
        statePath: root.statePath
    }

    Loader {
        active: notificationStore.count > 0
        asynchronous: true

        sourceComponent: PanelWindow {
            anchors {
                top: true
                right: true
            }

            implicitWidth: 402
            implicitHeight: Math.min(stack.implicitHeight + 68, 684)
            color: "transparent"
            visible: true

            WlrLayershell.namespace: "astrea-notifications"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusiveZone: -1

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
    }
}
