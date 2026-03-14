import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import "../.."

PanelWindow {
    id: root

    property bool shown: false

    color: "transparent"

    anchors.top:    true
    anchors.bottom: true
    anchors.left:   true
    anchors.right:  true

    WlrLayershell.namespace:     "topbar-popup"
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    visible: root.shown

    onShownChanged: {
        if (shown) {
            appearAnim.start()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.shown = false
        z: 0
    }

    Item {
        id: card
        anchors.left:       parent.left
        anchors.top:        parent.top
        anchors.leftMargin: 8
        anchors.topMargin:  54
        width:  200
        height: cardBg.height
        z: 1

        opacity: 0
        scale: 0.95

        SequentialAnimation {
            id: appearAnim
            ParallelAnimation {
                NumberAnimation {
                    target: card
                    property: "opacity"
                    from: 0; to: 1
                    duration: 200
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: card
                    property: "scale"
                    from: 0.95; to: 1.0
                    duration: 250
                    easing.type: Easing.OutBack
                }
            }
        }

        Rectangle {
            id: cardBg
            width:  parent.width
            height: menuColumn.implicitHeight + 24
            radius: Theme.radiusLarge
            color:  Theme.background

            border.width: 1
            border.color: Theme.border

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor:   Qt.rgba(0, 0, 0, 0.4)
                shadowBlur:    0.8
                shadowVerticalOffset: 4
            }
        }

        Column {
            id: menuColumn
            anchors {
                top: cardBg.top; left: cardBg.left; right: cardBg.right
                margins: 12; topMargin: 16
            }
            spacing: 4

            MenuItem {
                icon: "󰍉"
                text: "Search"
                onClicked: { root.shown = false; shellLauncher.running = true }
            }

            Rectangle {
                width: parent.width - 16
                height: 1
                color: Theme.separator
                anchors.horizontalCenter: parent.horizontalCenter
            }

            MenuItem {
                icon: "󰋖"
                text: "About this PC"
                onClicked: { 
                    root.shown = false; 
                    shellAbout.running = false
                    Qt.callLater(() => { shellAbout.running = true })
                }
            }

            MenuItem {
                icon: "󰍜"
                text: "Settings"
                onClicked: { root.shown = false; shellSettings.running = true }
            }

            Rectangle {
                width: parent.width - 16
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
                anchors.horizontalCenter: parent.horizontalCenter
            }

            MenuItem {
                icon: "󰅙"
                text: "Force Quit"
                onClicked: { root.shown = false; shellForceQuit.running = true }
            }

            MenuItem {
                icon: "󰷛"
                text: "Lockscreen"
                onClicked: { root.shown = false; shellLock.running = true }
            }

            MenuItem {
                icon: "󰐥"
                text: "Power"
                onClicked: { root.shown = false; shellPower.running = true }
            }
        }
    }

    Process {
        id: shellLauncher
        command: ["rofi", "-show", "drun"]
    }

    Process {
        id: shellAbout
        command: ["quickshell", "-p", "/opt/Astrea/about.qml"]
    }

    Process {
        id: shellSettings
        command: ["systemsettings"] // Common settings command for KDE/Plasma, change as needed
    }

    Process {
        id: shellForceQuit
        command: ["bash", "-c", "hyprctl kill"]
    }

    Process {
        id: shellLock
        command: ["hyprlock"]
    }

    Process {
        id: shellPower
        command: ["wlogout"]
    }

    // --- Inner Component for Menu Items ---
    component MenuItem: Rectangle {
        property string icon: ""
        property string text: ""
        property bool isLast: false
        signal clicked()

        id: itemRoot
        width: parent.width
        height: 36
        radius: Theme.radiusMedium
        color: mouse.containsMouse ? Theme.separator : "transparent"
        
        Behavior on color { ColorAnimation { duration: 150 } }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            spacing: 12

            Text {
                text: itemRoot.icon
                font.pixelSize: Theme.fontSizeIcon
                color: mouse.containsMouse ? Theme.iconActive : Theme.iconMain
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                text: itemRoot.text
                font.pixelSize: Theme.fontSizeBody
                font.weight: Font.Medium
                color: mouse.containsMouse ? Theme.textActive : Qt.rgba(1, 1, 1, 0.8)
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: itemRoot.clicked()
        }
    }
}
