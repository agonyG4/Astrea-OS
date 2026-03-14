import QtQuick

QtObject {
    id: root

    // Fases da animação — sem magic numbers
    readonly property int phaseIdle:    0
    readonly property int phaseHideOut: 1
    readonly property int phaseShowIn:  2

    function triggerFlip() {
        if (!artFlip.running) artFlip.start()
        // se já tá rodando, a checagem no ScriptAction final relança
    }

    property SequentialAnimation artFlip: SequentialAnimation {

        // Fase 1 — esconde (0° → 90°)
        NumberAnimation {
            target: island; property: "artFlipAngle"
            from: 0; to: 90
            duration: 110; easing.type: Easing.InQuad
        }

        // Troca a fonte no ponto cego da animação
        ScriptAction {
            script: {
                island.artSource        = island.pendingArtSource
                island.pendingArtSource = ""
                island.artFlipPhase     = root.phaseShowIn
            }
        }

        // Fase 2 — revela (90° → 0°)
        NumberAnimation {
            target: island; property: "artFlipAngle"
            from: 90; to: 0
            duration: 140; easing.type: Easing.OutQuad
        }

        // Fim — verifica se chegou outra arte durante a animação
        ScriptAction {
            script: {
                island.artFlipPhase = root.phaseIdle
                // Nova arte enfileirada enquanto animava? Relança.
                if (island.pendingArtSource !== "" &&
                    island.pendingArtSource !== island.artSource) {
                    island.artFlipPhase = root.phaseHideOut
                    artFlip.restart()   // restart é mais limpo que start() aqui
                }
            }
        }
    }
}