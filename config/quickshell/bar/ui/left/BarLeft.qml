import QtQuick
import QtQuick.Effects
import "../components/system"
import "../.."

Item {
    id: root

    property var astreaPopupRef: null

    height:  36
    width:   leftRow.implicitWidth + 20
    opacity: 0

    HoverHandler { id: rootHover }

    Component.onCompleted: appearAnim.start()

    // ─── Animação de entrada ──────────────────────────────────────
    NumberAnimation {
        id: appearAnim
        target: root; property: "opacity"
        from: 0; to: 1
        duration: 400; easing.type: Easing.OutCubic
    }

    // ─── Glass background ─────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge - 2
        color:  "transparent"

        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.background }
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: "transparent"
            border { width: 1; color: Theme.border }
        }
    }

    // ─── Hover glow ───────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge - 2
        color:  "transparent"
        border { width: 1; color: rootHover.hovered ? Theme.barBorderHover : Theme.border }
        Behavior on border.color { ColorAnimation { duration: 200 } }
    }

    // ─── Conteúdo ─────────────────────────────────────────────────
    Row {
        id: leftRow
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 28; height: 28
            radius: Theme.radiusMedium
            color:  logoArea.containsMouse ? Theme.separator : "transparent"

            Image {
                anchors.centerIn: parent
                source:   "../../assets/astrea.png"
                width: 18; height: 18
                fillMode: Image.PreserveAspectFit
                opacity:  0.80
            }

            MouseArea {
                id: logoArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: if (astreaPopupRef) astreaPopupRef.shown = !astreaPopupRef.shown
            }
        }

        Workspaces { anchors.verticalCenter: parent.verticalCenter }
    }
}