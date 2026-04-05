import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import "../../.."

PanelWindow {
    id: root

    property bool shown: false
    property real anchorX: screen.width - 60 // fallback

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

    // ─── Fundo: clique fora fecha ─────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: root.shown = false
        z: 0
    }

    // ─── Card ─────────────────────────────────────────────────────
    Item {
        id: card
        anchors.top:       parent.top
        anchors.topMargin: 54
        x:      Math.max(8, Math.min(parent.width - width - 8, root.anchorX - width / 2))
        width:  180
        height: cardBg.height
        z: 1

        opacity: 0
        SequentialAnimation {
            id: appearAnim
            NumberAnimation {
                target: card
                property: "opacity"
                from: 0; to: 1
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        // ─── Glass background ──────────────────────────────────
        Rectangle {
            id: cardBg
            width:  parent.width
            height: innerCol.implicitHeight + 24
            radius: Theme.radiusMedium
            color:  "transparent"

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.background
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Theme.border
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled:          true
                shadowColor:            Qt.rgba(0, 0, 0, 0.4)
                shadowBlur:             0.7
                shadowVerticalOffset:   4
                shadowHorizontalOffset: 0
            }
        }

        // ─── Conteúdo ──────────────────────────────────────────
        Column {
            id: innerCol
            anchors {
                top:    cardBg.top
                left:   cardBg.left
                right:  cardBg.right
                margins:   12
                topMargin: 12
            }
            spacing: 8

            // ── Menu Items ─────────────────────────────────────────
            Rectangle {
                width: parent.width; height: 32; radius: Theme.radiusSmall
                color: m1.containsMouse ? Theme.separator : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "Ação Menor 1"; color: Theme.textActive; font.pixelSize: Theme.fontSizeBody }
                MouseArea { id: m1; anchors.fill: parent; hoverEnabled: true; onClicked: root.shown = false }
            }
            Rectangle {
                width: parent.width; height: 32; radius: Theme.radiusSmall
                color: m2.containsMouse ? Theme.separator : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "Configurações"; color: Theme.textActive; font.pixelSize: Theme.fontSizeBody }
                MouseArea { id: m2; anchors.fill: parent; hoverEnabled: true; onClicked: root.shown = false }
            }
        }
    }
}
