import QtQuick
import "../bar" as Bar

Item {
    id: hungry

    required property bool isGamemodeNotify
    required property bool isMouseOver
    required property bool hasDroppedImages
    required property bool hasMusic
    required property bool compactDragActive
    required property var  droppedImages
    required property real currentRadius
    required property var procs

    readonly property bool containsDrag: fileDropArea.containsDrag

    // ── Drop area ─────────────────────────────────────────────────
    DropArea {
        id: fileDropArea
        anchors.fill: parent
        onDropped: drop => {
            if (!drop?.urls?.length) return
            procs.addDroppedFiles(drop.urls)
            drop.acceptProposedAction()
        }
    }

    // ── Drop indicator ────────────────────────────────────────────
    Item {
        anchors.fill: parent
        visible: opacity > 0
        opacity: containsDrag && !isGamemodeNotify ? 1 : 0
        z: 20
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.centerIn: parent
            width: 44; height: 44; radius: 22
            color: "#33000000"
            border.color: "#66ffffff"
            border.width: 1.5

            Text {
                anchors.centerIn: parent
                text: "+"
                font.family: Bar.Theme.fontFamilyDisplay
                font.pixelSize: 24
                font.weight: Font.Light
                color: "white"
                opacity: 0.9
                antialiasing: true
                renderType: Text.NativeRendering
            }

            SequentialAnimation on scale {
                running: hungry.containsDrag
                loops: Animation.Infinite
                NumberAnimation { to: 1.1; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
            }
        }
    }
}
