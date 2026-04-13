import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import "../../.."

PanelWindow {
    id: root

    property bool shown: false
    property real anchorX: 22

    color:   "transparent"
    visible: root.shown

    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace:     "topbar-popup"
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    onShownChanged: if (shown) appearAnim.start()

    MouseArea { anchors.fill: parent; onClicked: root.shown = false; z: 0 }

    // ─── Card ─────────────────────────────────────────────────────
    Item {
        id: card
        anchors.top: parent.top
        anchors.topMargin: 54
        x: Math.max(8, Math.min(parent.width - width - 8, root.anchorX - width / 2))
        width:   200
        height:  cardBg.height
        opacity: 0
        scale:   0.95
        z:       1

        SequentialAnimation {
            id: appearAnim
            ParallelAnimation {
                NumberAnimation {
                    target: card; property: "opacity"
                    from: 0; to: 1
                    duration: 200; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: card; property: "scale"
                    from: 0.95; to: 1.0
                    duration: 250; easing.type: Easing.OutBack
                }
            }
        }

        Rectangle {
            id: cardBg
            width:  parent.width
            height: menuColumn.implicitHeight + 24
            radius: Theme.radiusLarge
            color:  Theme.background
            border { width: 1; color: Theme.border }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled:        true
                shadowColor:          Qt.rgba(0, 0, 0, 0.4)
                shadowBlur:           0.8
                shadowVerticalOffset: 4
            }
        }

        Column {
            id: menuColumn
            anchors { top: cardBg.top; left: cardBg.left; right: cardBg.right; margins: 12; topMargin: 16 }
            spacing: 4

            MenuItem {
                icon: "󰍉"; text: "Search"
                onClicked: { root.shown = false; shellLauncher.running = true }
            }

            MenuSeparator {}

            MenuItem {
                icon: "󰋖"; text: "About this PC"
                onClicked: {
                    root.shown = false
                    shellAbout.running = false
                    Qt.callLater(() => { shellAbout.running = true })
                }
            }
            MenuItem {
                icon: "󰍜"; text: "Settings"
                onClicked: {
                    root.shown = false
                    shellSettings.running = false
                    Qt.callLater(() => { shellSettings.running = true })
                }
            }

            MenuSeparator {}

            MenuItem {
                icon: "󰅙"; text: "Force Quit"
                onClicked: { root.shown = false; shellForceQuit.running = true }
            }
            MenuItem {
                icon: "󰷛"; text: "Lockscreen"
                onClicked: { root.shown = false; shellLock.running = true }
            }
            MenuItem {
                icon: "󰐥"; text: "Power"
                onClicked: { root.shown = false; shellPower.running = true }
            }
        }
    }

    // ─── Processos ────────────────────────────────────────────────
    Process { id: shellLauncher;  command: ["rofi", "-show", "drun"] }
    Process { id: shellAbout;    command: ["quickshell", "-p", Quickshell.env("HOME") + "/.local/share/Astrea/Apps/about.qml"] }
    Process { id: shellSettings; command: ["quickshell", "-p", Quickshell.env("HOME") + "/.local/share/Astrea/Apps/Settings/main.qml"] }
    Process { id: shellForceQuit; command: ["bash", "-c", "hyprctl kill"] }
    Process { id: shellLock; command: ["quickshell", "-p", Quickshell.env("HOME") + "/.local/share/Astrea/Features/Paper/app/lockscreen/lockscreen.qml"] }
    Process { id: shellPower;     command: ["bash", "-c", "shutdown now"] }
}
