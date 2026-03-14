import QtQuick
import Qt5Compat.GraphicalEffects
import "../bar"
Rectangle {
    id: islandContent
    readonly property bool isGamemodeNotify: island.showGamemodeNotify
    readonly property bool isMouseOver: mouseArea.containsMouse
    readonly property real flipScale:  Math.abs(Math.cos(island.artFlipAngle * Math.PI / 180))
    
    width: {
        if (isGamemodeNotify) return 100
        if (!island.hasMusic) return island.isExpanded ? 140 : 120
        return island.isExpanded ? 360 : 180
    }
    height: {
        if (isGamemodeNotify) return 100
        if (!island.hasMusic) return island.isExpanded ? 38 : 34
        return island.isExpanded ? 160 : 34
    }
    property real currentRadius: (island.isExpanded || isGamemodeNotify) ? 32 : 17
    radius: currentRadius
    color: "transparent"
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 8
    clip: true
    Behavior on width         { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
    Behavior on height        { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
    Behavior on currentRadius { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
    Rectangle {
        anchors.fill: parent
        radius: parent.currentRadius
        color: Theme.islandBackground
    }
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
    }
    // ── Modo compacto ─────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        visible: opacity > 0
        opacity: (!islandContent.isGamemodeNotify && island.hasMusic && !islandContent.isMouseOver) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Rectangle {
            width: 20; height: 20; radius: 10
            color: Theme.islandBackground
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            Item {
                anchors.fill: parent
                transform: Scale {
                    origin.x: 10; origin.y: 10
                    xScale: islandContent.flipScale
                }
                Image {
                    anchors.fill: parent
                    source: island.artSource
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle { width: 20; height: 20; radius: 10 }
                    }
                }
            }
        }
        Row {
            spacing: 3; width: 30
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            Repeater {
                model: 6
                Item {
                    width: 3; height: 20
                    Rectangle {
                        width: 3
                        height: Math.min(island.cavaMaxHeightCompact, Math.max(island.cavaMinHeight, (island.cavaBars[index] / 100) * 18))
                        radius: 2; anchors.centerIn: parent
                        color: island.dominantCol
                        Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutSine } }
                        Behavior on color  { ColorAnimation  { duration: 800 } }
                    }
                }
            }
        }
    }
    // ── Modo Gamemode ────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        visible: opacity > 0
        opacity: islandContent.isGamemodeNotify ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        
        Text {
            anchors.centerIn: parent
            text: "🎮"
            font.pixelSize: 48
            
            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 1500
                loops: Animation.Infinite
                running: islandContent.isGamemodeNotify
            }
        }
    }

    // ── Modo expandido ────────────────────────────────────────────────
    MusicView { id: musicView }
}