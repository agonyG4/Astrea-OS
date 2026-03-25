// IslandAnimations.qml
import QtQuick

QtObject {
    id: root

    readonly property int phaseIdle:    0
    readonly property int phaseHideOut: 1
    readonly property int phaseShowIn:  2

    function triggerFlip() {
        if (!artFlip.running)
            artFlip.start()
    }

    property SequentialAnimation artFlip: SequentialAnimation {

        // Fase 1 — esconde (0° → 90°)
        NumberAnimation {
            target: island; property: "artFlipAngle"
            from: 0; to: 90
            duration: 110
            easing.type: Easing.InCubic
        }

        // Troca no ponto cego
        ScriptAction {
            script: {
                island.artSource        = island.pendingArtSource
                island.pendingArtSource = ""
                island.artFlipPhase     = root.phaseShowIn
            }
        }

        // Fase 2 — revela (90° → 0°) com spring
        NumberAnimation {
            target: island; property: "artFlipAngle"
            from: 90; to: 0
            duration: 160
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.34, 1.56, 0.64, 1.0]
        }

        // Fim — processa fila
        ScriptAction {
            script: {
                island.artFlipPhase = root.phaseIdle
                if (island.pendingArtSource !== "" &&
                    island.pendingArtSource !== island.artSource) {
                    Qt.callLater(function() {
                        island.artFlipPhase = root.phaseHideOut
                        artFlip.restart()
                    })
                }
            }
        }
    }
}