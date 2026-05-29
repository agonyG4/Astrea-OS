import QtQuick
import "./modes" as Modes
import "./modes/gamemode" as Gamemode
import "./modes/idle" as Idle
import "./modes/music" as Music

Item {
    id: root

    property bool isGamemodeNotify: false
    property bool isMouseOver: false
    property real flipScale: 1

    anchors.fill: parent

    Modes.ModeContainer {
        id: idleContainer
        active: island.activeMode === "idle"

        Idle.IdleMode {
            anchors.fill: parent
            active: idleContainer.active
        }
    }

    Modes.ModeContainer {
        id: musicContainer
        active: island.activeMode === "music"
        fadeInDuration: 110
        fadeOutDuration: 180

        Music.MusicMode {
            anchors.fill: parent
            active: musicContainer.active
            expanded: root.isMouseOver
            compactActive: island.showCompactMusic
            flipScale: root.flipScale
        }
    }

    Modes.ModeContainer {
        id: gamemodeContainer
        active: island.activeMode === "gamemodeNotify"
        fadeInDuration: 120
        fadeOutDuration: 200

        Gamemode.GamemodeMode {
            anchors.fill: parent
            active: gamemodeContainer.active
        }
    }
}
