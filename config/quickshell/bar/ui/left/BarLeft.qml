import QtQuick
import QtQuick.Effects
import "../components"
import "../.."

Item {
    id: root

    property var astreaPopupRef: null

    // ─── Layout ───────────────────────────────────────────────────
    height: 36
    width:  leftRow.implicitWidth + 20

    HoverHandler { id: rootHover }

    // ─── Glass background ─────────────────────────────────────────
    Rectangle {
        id: glassBase
        anchors.fill: parent
        radius: Theme.radiusLarge - 2 // proportional adjustment
        color: "transparent"

        // Camada de cor principal
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.background
        }

        // Borda sutil
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Theme.border
        }
    }
    // ─── Animação de entrada ──────────────────────────────────────
    opacity: 0
    Component.onCompleted: appearAnim.start()

    SequentialAnimation {
        id: appearAnim
        NumberAnimation {
            target: root
            property: "opacity"
            from: 0; to: 1
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    // ─── Conteúdo ─────────────────────────────────────────────────
    Row {
        id: leftRow
        anchors.centerIn: parent
        spacing: 8

        // Logo
        Rectangle {
            width: 28
            height: 28
            radius: Theme.radiusMedium
            anchors.verticalCenter: parent.verticalCenter
            color: logoArea.containsMouse ? Theme.separator : "transparent"

            // Glow no hover
            layer.enabled: false
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor:   Qt.rgba(0.4, 0.6, 1.0, 0.4)
                shadowBlur:    0.9
                shadowVerticalOffset: 0
                shadowHorizontalOffset: 0
            }

            Image {
                source: "../../assets/astrea.png"
                width: 18; height: 18
                anchors.centerIn: parent
                fillMode: Image.PreserveAspectFit
                opacity: 0.80
            }

            MouseArea {
                id: logoArea
                anchors.fill: parent
                hoverEnabled: true

                onClicked: {
                    if (astreaPopupRef) {
                        astreaPopupRef.shown = !astreaPopupRef.shown
                    }
                }
            }


        }

        Workspaces { anchors.verticalCenter: parent.verticalCenter }
    }

    // ─── Hover glow (borda) ───────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: glassBase.radius
        color: "transparent"
        border.width: 1
        border.color: rootHover.hovered ? Theme.barBorderHover : Theme.border

        Behavior on border.color { ColorAnimation { duration: 200 } }
    }
}