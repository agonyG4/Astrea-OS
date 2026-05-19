// IslandAnimations.qml
import QtQuick

QtObject {
    id: root

    readonly property int phaseIdle:    0
    readonly property int phaseHideOut: 1
    readonly property int phaseShowIn:  2

    property bool isNotch: island && island.islandConfig ? (island.islandConfig.style === "Notch") : false

    // ── Durations (ms) — Bubble (Otimizado) ───────────────────────────
    readonly property int bubbleContainerExpandDuration:   200
    readonly property int bubbleContainerCollapseDuration: 400
    readonly property int bubbleArtExpandDuration:         220
    readonly property int bubbleArtCollapseDuration:       250
    readonly property int bubbleContentFadeInDuration:     0
    readonly property int bubbleContentFadeOutDuration:    300
    readonly property int bubbleContentSlideInDuration:    150
    readonly property int bubbleContentSlideDuration:      0
    readonly property int bubbleContentSlideDistance:      22
    readonly property int bubbleRadiusDuration:            380

    // ── Durations (ms) — Notch ────────────────────────────────────────
    readonly property int notchContainerExpandDuration:   350
    readonly property int notchContainerCollapseDuration: 400
    readonly property int notchArtExpandDuration:         200
    readonly property int notchArtCollapseDuration:       450
    readonly property int notchContentFadeInDuration:     0
    readonly property int notchContentFadeOutDuration:    120
    readonly property int notchContentSlideInDuration:    250
    readonly property int notchContentSlideDuration:      300
    readonly property int notchContentSlideDistance:      12
    readonly property int notchRadiusDuration:            250

    // ── Variáveis Dinâmicas ───────────────────────────────────────────
    readonly property int containerExpandDuration:   isNotch ? notchContainerExpandDuration   : bubbleContainerExpandDuration
    readonly property int containerCollapseDuration: isNotch ? notchContainerCollapseDuration : bubbleContainerCollapseDuration
    readonly property int artExpandDuration:         isNotch ? notchArtExpandDuration         : bubbleArtExpandDuration
    readonly property int artCollapseDuration:       isNotch ? notchArtCollapseDuration       : bubbleArtCollapseDuration
    readonly property int contentFadeInDuration:     isNotch ? notchContentFadeInDuration     : bubbleContentFadeInDuration
    readonly property int contentFadeOutDuration:    isNotch ? notchContentFadeOutDuration    : bubbleContentFadeOutDuration
    readonly property int contentSlideInDuration:    isNotch ? notchContentSlideInDuration    : bubbleContentSlideInDuration
    readonly property int contentSlideDuration:      isNotch ? notchContentSlideDuration      : bubbleContentSlideDuration
    readonly property int contentSlideDistance:      isNotch ? notchContentSlideDistance      : bubbleContentSlideDistance
    readonly property int radiusDuration:            isNotch ? notchRadiusDuration            : bubbleRadiusDuration


    property int _lockedDirection: 1

    function triggerFlip() {
        if (!artFlip.running) {
            _lockedDirection = island.artFlipDirection
            artFlip.start()
        }
    }

    property SequentialAnimation artFlip: SequentialAnimation {

        // Fase 1 — esconde (0° → 90° ou -90°)
        NumberAnimation {
            target: island; property: "artFlipAngle"
            from: 0; to: 90 * root._lockedDirection
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
            from: 90 * root._lockedDirection; to: 0
            duration: 160
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.34, 1.56, 0.64, 1.0]
        }

        // Fim — processa fila
        ScriptAction {
            script: {
                island.artFlipPhase = root.phaseIdle
                island.artFlipDirection = 1
                root._lockedDirection = 1
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