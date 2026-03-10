import QtQuick
import QtQuick.Effects
import "../components"

Item {
    id: root

    // ─── Layout ───────────────────────────────────────────────────
    height: 36
    width:  leftRow.implicitWidth + 20

    // ─── Glass background ─────────────────────────────────────────
    Rectangle {
        id: glassBase
        anchors.fill: parent
        radius: 14
        color: "transparent"

        // Camada de cor principal
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(0.08, 0.09, 0.12, 0.55)
        }

        // Borda sutil
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.13)
        }

        // Reflexo interno no topo (efeito vidro)
        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 1
                leftMargin: 4
                rightMargin: 4
            }
            height: parent.height * 0.45
            radius: parent.radius
            color: Qt.rgba(1, 1, 1, 0.045)
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
            radius: 8
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"

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
                source: "file:///home/agony/.config/quickshell/bar/assets/astrea.png"
                width: 18; height: 18
                anchors.centerIn: parent
                fillMode: Image.PreserveAspectFit
                opacity: 0.80
            }

            MouseArea {
                id: logoArea
                anchors.fill: parent
                hoverEnabled: true

                onClicked: { /* Ação de clique se houver */ }
            }


        }

        Workspaces { anchors.verticalCenter: parent.verticalCenter }
    }

    // ─── Hover glow (borda) ───────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        onPressed: (e) => e.accepted = false

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, parent.parent.containsMouse ? 0.28 : 0.13)

            Behavior on border.color { ColorAnimation { duration: 200 } }
        }
    }
}