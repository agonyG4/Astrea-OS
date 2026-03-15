import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import "components"

ApplicationWindow {
    id: window
    visible: true
    width: 950
    height: 650
    minimumWidth: 950
    minimumHeight: 650
    maximumWidth: 950
    maximumHeight: 650
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    onClosing: Qt.quit()
    background: Rectangle { color: "transparent" }

    // ── Theme ─────────────────────────────────────────────────────────────
    readonly property color accent:        "#0a84ff"
    readonly property color textPrimary:   "#ffffff"
    readonly property color textSecondary: "#98989f"

    // ── Navigation state ──────────────────────────────────────────────────
    property int selectedIndex: 0

    readonly property var pages: [
        "pages/system.qml",
        "pages/visual.qml",
        "pages/apps.qml",
        "pages/perfomance.qml",
        "pages/wifi.qml",
        "pages/bluetooth.qml"
    ]

    function navigateTo(index) {
        if (index === selectedIndex) return
        selectedIndex = index
    }

    Component.onCompleted: pageLoader.setSource(pages[selectedIndex])
    onSelectedIndexChanged: pageLoader.setSource(pages[selectedIndex])

    // ── Nav model — ícones Nerd Font (JetBrainsMono Nerd Font) ────────────
    ListModel {
        id: navModel
        ListElement { label: "System";      sym: "\uf303" } // nf-linux-archlinux (ou troca por \uf17c linux)
        ListElement { label: "Visual";      sym: "\uf1fc" } // nf-fa-paint_brush
        ListElement { label: "Apps";        sym: "\uf00a" } // nf-fa-th (grid 3x3)
        ListElement { label: "Performance"; sym: "\uf201" } // nf-fa-line_chart
        ListElement { label: "Wi-Fi";       sym: "\uf1eb" } // nf-fa-wifi
        ListElement { label: "Bluetooth";   sym: "\uf294" } // nf-fa-bluetooth_b
    }

    // ── Drop shadow ───────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: 15
        color: "transparent"
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled:        true
            shadowColor:          Qt.rgba(0, 0, 0, 0.6)
            shadowBlur:           1.0
            shadowVerticalOffset: 8
        }
    }

    // ── Main container ────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Qt.rgba(0.11, 0.11, 0.12, 0.55)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)
        clip: true

        // Drag handle
        MouseArea {
            id: dragArea
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 40
            cursorShape: Qt.SizeAllCursor
            property point pressOffset
            onPressed:         (mouse) => { pressOffset = Qt.point(mouse.globalX - window.x, mouse.globalY - window.y) }
            onPositionChanged: (mouse) => { if (pressed) { window.x = mouse.globalX - pressOffset.x; window.y = mouse.globalY - pressOffset.y } }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Sidebar {
                id: sidebar
                Layout.preferredWidth: 200
                Layout.fillHeight: true
                model:         navModel
                selectedIndex: window.selectedIndex
                onSelectIndex: (i) => window.navigateTo(i)
            }

            // ── Content area ──────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Loader {
                    id: pageLoader
                    anchors.fill: parent

                    onStatusChanged: {
                        if (status === Loader.Ready)
                            fadeIn.start()
                    }

                    NumberAnimation {
                        id: fadeIn
                        target:   pageLoader
                        property: "opacity"
                        from:     0
                        to:       1
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}