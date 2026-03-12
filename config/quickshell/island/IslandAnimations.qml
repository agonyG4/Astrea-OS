import QtQuick

QtObject {
    function hide() { artFlip.start() }

    property SequentialAnimation artFlip: SequentialAnimation {
        id: artFlip

        NumberAnimation {
            target: island; property: "artFlipAngle"
            from: 0; to: 90
            duration: 110; easing.type: Easing.InQuad
        }
        ScriptAction {
            script: {
                island.artSource        = island.pendingArtSource
                island.pendingArtSource = ""
                island.artFlipPhase     = 2
            }
        }
        NumberAnimation {
            target: island; property: "artFlipAngle"
            from: 90; to: 0
            duration: 140; easing.type: Easing.OutQuad
        }
        ScriptAction {
            script: {
                island.artFlipPhase = 0
                if (island.pendingArtSource !== "") {
                    island.artFlipPhase = 1
                    artFlip.start()
                }
            }
        }
    }
}