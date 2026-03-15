import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import "../../.."

PanelWindow {
    id: root

    property bool shown: false

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
        anchors { left: parent.left; top: parent.top; leftMargin: 8; topMargin: 54 }
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
                onClicked: { root.shown = false; shellSettings.running = true }
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
    Process { id: shellAbout;     command: ["quickshell", "-p", Quickshell.env("HOME") + "/.local/Astrea/about.qml"] }
    Process { id: shellSettings;  command: ["quickshell", "-p", Quickshell.env("HOME") + "/.local/Astrea/Settings/main.qml"] }
    Process { id: shellForceQuit; command: ["bash", "-c", "hyprctl kill"] }
    Process { id: shellLock;      command: ["hyprlock"] }
    Process { id: shellPower;     command: ["wlogout"] }

    // ─── Componentes ──────────────────────────────────────────────
    component MenuSeparator: Rectangle {
        width: parent.width - 16
        height: 1
        color: Theme.separator
        anchors.horizontalCenter: parent.horizontalCenter
    }

    component MenuItem: Rectangle {
        id: itemRoot
        property string icon: ""
        property string text: ""
        signal clicked()

        width: parent.width; height: 36
        radius: Theme.radiusMedium
        color:  mouse.containsMouse ? Theme.separator : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }

        Row {
            anchors { fill: parent; leftMargin: 12 }
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:  itemRoot.icon
                color: mouse.containsMouse ? Theme.iconActive : Theme.iconMain
                font.pixelSize: Theme.fontSizeIcon
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:  itemRoot.text
                color: mouse.containsMouse ? Theme.textActive : Qt.rgba(1, 1, 1, 0.8)
                font { pixelSize: Theme.fontSizeBody; weight: Font.Medium }
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked: itemRoot.clicked()
        }
    }
}