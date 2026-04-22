import QtQuick
import QtQuick.Effects
import "../components/system"
import "../.."

Item {
    id: root

    property var astreaPopupRef: null
    readonly property string quickshellAssetRoot: "file:///home/agony/.local/share/Astrea/Assets/ui/quickshell/bar/"

    height:  36
    width:   leftRow.implicitWidth + 20
    opacity: 0

    function updateAstreaAnchor() {
        if (!root.astreaPopupRef) return
        const point = logoButton.mapToItem(null, logoButton.width / 2, logoButton.height / 2)
        root.astreaPopupRef.anchorX = point.x
    }

    HoverHandler { id: rootHover }

    Component.onCompleted: {
        updateAstreaAnchor()
        appearAnim.start()
    }
    onXChanged: updateAstreaAnchor()
    onWidthChanged: updateAstreaAnchor()
    onAstreaPopupRefChanged: updateAstreaAnchor()

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

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.background
        }
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: "transparent"
            border { width: 1; color: Theme.border }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge - 2
        color: "transparent"
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
            id: logoButton
            anchors.verticalCenter: parent.verticalCenter
            width: 28; height: 28
            radius: Theme.radiusMedium
            color:  logoArea.containsMouse ? Theme.separator : "transparent"

            Image {
                anchors.centerIn: parent
                source:   root.quickshellAssetRoot + "astrea.png"
                width: 18; height: 18
                fillMode: Image.PreserveAspectFit
                opacity:  0.80
            }

            MouseArea {
                id: logoArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (!astreaPopupRef) return
                    const point = logoButton.mapToItem(null, logoButton.width / 2, logoButton.height / 2)
                    astreaPopupRef.toggleAt(point.x)
                }
            }
        }

        Workspaces { anchors.verticalCenter: parent.verticalCenter }
    }
}
