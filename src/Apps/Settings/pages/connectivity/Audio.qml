import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../AstreaComponents"
import "../../AstreaI18n" as AstreaI18n

Item {
    id: root

    // ── Theme ─────────────────────────────────────────────────────────────
    readonly property color accent: Theme.accent
    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color cardBg: Theme.cardBg
    readonly property color cardBorder: Theme.cardBorder
    readonly property color popupBg: Theme.popupBg
    readonly property color errorColor: Theme.errorColor
    readonly property color warningColor: Theme.warningColor
    readonly property color successColor: Theme.successColor

    readonly property string _script:
        (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Core/bridge/system/audio.py"
    readonly property string spatialSinkName: "effect_input.virtual-surround-7.1-astrea"

    // ── State ─────────────────────────────────────────────────────────────
    property bool   loading:      true
    property bool   showLoading:  false
    property string errorMsg:     ""
    property var    sinks:        []
    property var    outputsState: ({ all: [], visible: [], hidden: [], hidden_names: [] })
    property var    apps:         []
    property var    spatial:      ({ available: false, enabled: false, sink: spatialSinkName, target_sink: "" })
    property var    wp:           ({ sample_rate: 48000, buffer_size: 1024 })
    property var    mutedMap:     ({})
    property var    volumeMap:    ({})
    property bool   wpPending:    false
    property bool   wpRestarting: false
    property bool   spatialPending: false
    property int    _emptyAppsRefreshes: 0
    property string _appsSignature: ""
    property int    editRate:     0
    property int    editBuffer:   0

    readonly property var rateOptions:   [44100, 48000, 88200, 96000, 192000]
    readonly property var bufferOptions: [32, 64, 128, 256, 512, 1024, 2048]
    readonly property bool spatialAvailable: root.spatial.available === true
    readonly property bool spatialActive: root.spatial.enabled === true
    readonly property bool spatialCanDisable: root.spatialFallbackSinkName().length > 0
    readonly property string spatialTargetSinkName: root.spatial.target_sink || root.spatialFallbackSinkName()
    readonly property var outputSinks: root.outputsState.visible || []
    readonly property var hiddenOutputSinks: root.outputsState.hidden || []

    onLoadingChanged: {
        if (loading) {
            loadingTextDelay.restart()
        } else {
            loadingTextDelay.stop()
            showLoading = false
        }
    }

    Timer {
        id: loadingTextDelay
        interval: 220
        repeat: false
        onTriggered: root.showLoading = root.loading
    }

    // ── Processos ─────────────────────────────────────────────────────────
    property string _buf: ""
    property bool _fetchAgain: false

    function appsSignature(items) {
        let parts = []
        for (let item of items || []) {
            parts.push([
                item.index,
                item.name || "",
                item.icon || "",
                Math.round((item.volume || 0) * 1000),
                item.muted ? 1 : 0
            ].join(":"))
        }
        return parts.join("|")
    }

    function appIndexes(app) {
        if (app && app.indexes && app.indexes.length > 0)
            return app.indexes
        return app && app.index !== undefined ? [app.index] : []
    }

    function applyAppsSnapshot(items) {
        const next = items || []
        if (next.length === 0 && root.apps.length > 0) {
            root._emptyAppsRefreshes += 1
            if (root._emptyAppsRefreshes < 2)
                return
        } else {
            root._emptyAppsRefreshes = 0
        }

        const sig = root.appsSignature(next)
        if (sig === root._appsSignature)
            return

        root._appsSignature = sig
        root.apps = next
    }

    function refreshAudioInfo() {
        if (fetchProc.running) {
            root._fetchAgain = true
            return
        }
        root._buf = ""
        root.errorMsg = ""
        fetchProc.running = true
    }

    Process {
        id: fetchProc
        command: ["python3", root._script, "info"]
        running: false
        stdout: SplitParser { onRead: (l) => root._buf += l }
        onExited: (code) => {
            root.loading = false
            if (code === 0) {
                try {
                    const d = JSON.parse(root._buf)
                    root.sinks = d.sinks ?? []
                    root.outputsState = d.outputs_state ?? { all: d.outputs ?? [], visible: d.outputs ?? [], hidden: d.hidden_output_items ?? [], hidden_names: d.hidden_outputs ?? [] }
                    root.spatial = d.spatial ?? { available: false, enabled: false, sink: root.spatialSinkName, target_sink: "" }
                    root.wp = d.wp ?? { sample_rate: 48000, buffer_size: 1024 }
                    root.editRate = root.wp.sample_rate
                    root.editBuffer = root.wp.buffer_size
                    root._buf = ""
                } catch(e) {
                    root.errorMsg = "Parse error: " + e
                }
            } else if (code !== 15 && code !== 143) {
                root.errorMsg = "Script failed (exit " + code + ")"
            }
            root._buf = ""
            if (root._fetchAgain) {
                root._fetchAgain = false
                Qt.callLater(root.refreshAudioInfo)
            }
        }
    }

    property bool _sliderActive: false

    Process { id: volProc;   running: false; command: [] }
    Process { id: muteProc;  running: false; command: [] }

    Process {
        id: applyProc
        running: false; command: []
        onExited: (code) => {
            root.spatialPending = false
            if (code === 0 && root.wpPending) {
                root.wpPending    = false
                root.wpRestarting = true
                restartProc.running = true
            } else if (code === 0) {
                root.refreshAudioInfo()
            }
        }
    }

    Process {
        id: restartProc
        command: ["systemctl", "--user", "restart", "wireplumber"]
        running: false
        onExited: () => {
            root.wpRestarting = false
            root.loading = true
            Qt.callLater(root.refreshAudioInfo)
        }
    }

    function _apply(cfg) {
        if ("volume" in cfg && "app_indexes" in cfg) {
            applyProc.command = ["python3", root._script, "apply", JSON.stringify(cfg)]
            applyProc.running = false
            Qt.callLater(() => applyProc.running = true)
        } else if ("muted" in cfg && "app_indexes" in cfg) {
            applyProc.command = ["python3", root._script, "apply", JSON.stringify(cfg)]
            applyProc.running = false
            Qt.callLater(() => applyProc.running = true)
        } else if ("volume" in cfg && "app_index" in cfg) {
            volProc.command = ["pactl", "set-sink-input-volume", String(cfg.app_index), Math.round(cfg.volume * 100) + "%"]
            volProc.running = false; volProc.running = true
        } else if ("muted" in cfg && "app_index" in cfg) {
            muteProc.command = ["pactl", "set-sink-input-mute", String(cfg.app_index), cfg.muted ? "1" : "0"]
            muteProc.running = false; muteProc.running = true
        } else {
            applyProc.command = ["python3", root._script, "apply", JSON.stringify(cfg)]
            applyProc.running = false
            Qt.callLater(() => applyProc.running = true)
        }
    }

    function _setSpatialOptimistic(enabled, target) {
        var next = Object.assign({}, root.spatial)
        next.enabled = enabled
        next.target_sink = target || next.target_sink || root.spatialFallbackSinkName()
        root.spatial = next
    }

    function spatialFallbackSinkName() {
        for (let sink of root.outputSinks) {
            if (sink && sink.default)
                return sink.name
        }
        for (let sink of root.outputSinks) {
            if (sink)
                return sink.name
        }
        return ""
    }

    function toggleSpatialAudio() {
        if (!root.spatialAvailable || root.spatialPending)
            return
        if (root.spatialActive) {
            const fallback = root.spatialTargetSinkName || root.spatialFallbackSinkName()
            if (fallback.length > 0) {
                root.spatialPending = true
                root._setSpatialOptimistic(false, fallback)
                applyProc.command = ["pactl", "set-default-sink", fallback]
                applyProc.running = false
                applyProc.running = true
            }
        } else {
            const target = root.spatialTargetSinkName || root.spatialFallbackSinkName()
            if (target.length > 0) {
                const currentTarget = root.spatial.target_sink || ""
                root.spatialPending = true
                root._setSpatialOptimistic(true, target)
                if (target === currentTarget) {
                    applyProc.command = ["pactl", "set-default-sink", root.spatialSinkName]
                    applyProc.running = false
                    applyProc.running = true
                } else {
                    root._apply({ spatial_enabled: true, target_sink: target })
                }
            }
        }
    }

    property var outputMenuSink: ({})
    property bool hiddenOutputsExpanded: false

    function openOutputMenu(sink, x, y) {
        root.outputMenuSink = sink || {}
        outputMenu.openAt(x, y)
    }

    function setOutputAsDefault(name) {
        if (!name)
            return
        root._apply({ set_default_sink: name })
    }

    function hideOutput(name) {
        if (!name)
            return
        root.hiddenOutputsExpanded = true
        root._apply({ hide_output: name })
    }

    function showOutput(name) {
        if (!name)
            return
        root._apply({ show_output: name })
    }

    property string _appsBuf: ""
    property bool _fetchAppsAgain: false

    function refreshApps() {
        if (fetchAppsProc.running) {
            root._fetchAppsAgain = true
            return
        }
        root._appsBuf = ""
        fetchAppsProc.running = true
    }

    Process {
        id: fetchAppsProc
        command: ["python3", root._script, "apps"]
        running: false
        stdout: SplitParser { onRead: (l) => root._appsBuf += l }
        onExited: (code) => {
            if (code === 0) {
                try {
                    const d = JSON.parse(root._appsBuf)
                    if (!root._sliderActive)
                        root.applyAppsSnapshot(d.apps ?? [])
                } catch(e) {}
            }
            root._appsBuf = ""
            if (root._fetchAppsAgain) {
                root._fetchAppsAgain = false
                Qt.callLater(root.refreshApps)
            }
        }
    }

    Timer {
        interval: 2000; repeat: true; running: true
        onTriggered: {
            if (!root.loading && !root.wpRestarting) {
                root.refreshApps()
            }
        }
    }

    Component.onCompleted: {
        root.refreshAudioInfo()
        root.refreshApps()
    }

    Timer {
        interval: 2000; repeat: true; running: true
        onTriggered: {
            if (!root.loading && !root._sliderActive && !root.wpRestarting) {
                root.refreshAudioInfo()
            }
        }
    }

    // ── Loading / Error ───────────────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        visible: root.showLoading
        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.audio.text.loading_audio_infoa"]) || "Loading audio info…")
        color: root.textSecondary; font.pixelSize: Theme.fontSizeNormal
    }
    Text {
        anchors.centerIn: parent
        visible: !root.loading && root.errorMsg !== ""
        text: "⚠  " + root.errorMsg
        color: root.errorColor; font.pixelSize: Theme.fontSizeNormal
        wrapMode: Text.WordWrap; width: parent.width - 48
        horizontalAlignment: Text.AlignHCenter
    }

    // ── Layout ────────────────────────────────────────────────────────────
    ScrollPage {
        id: mainFlick
        anchors.fill: parent
        contentMargins: 28
        visible: !root.loading && root.errorMsg === ""

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 0

            // ── Spatial Audio ─────────────────────────────────────────────
            SectionHeader { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.audio.text.spatial_audio"]) || "SPATIAL AUDIO"); Layout.bottomMargin: 12 }

            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 24
                radius: 12; color: root.cardBg
                border.width: 1; border.color: root.cardBorder
                implicitHeight: spatialCol.implicitHeight

                ColumnLayout {
                    id: spatialCol
                    anchors { left: parent.left; right: parent.right }
                    spacing: 0

                    SettingRow {
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.audio.label.astrea_spatial_audio"]) || "Astrea Spatial Audio")
                        sublabel: root.spatialActive
                            ? "Spatial processing is enabled"
                            : (root.spatialAvailable ? "Spatial processing is disabled" : "Spatial output is not loaded")
                        isLast: true
                        clickable: root.spatialAvailable && (!root.spatialActive || root.spatialCanDisable)
                        onClicked: root.toggleSpatialAudio()

                        ToggleSwitch {
                            checked: root.spatialActive
                            enabled: root.spatialAvailable && (!root.spatialActive || root.spatialCanDisable)
                            opacity: enabled ? 1 : 0.45
                            onToggled: root.toggleSpatialAudio()
                        }
                    }
                }
            }

            // ── Output Device ─────────────────────────────────────────────
            SectionHeader { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.audio.text.output_device"]) || "OUTPUT DEVICE"); Layout.bottomMargin: 12 }

            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 24
                radius: 12; color: root.cardBg
                border.width: 1; border.color: root.cardBorder
                implicitHeight: deviceCol.implicitHeight

                ColumnLayout {
                    id: deviceCol
                    anchors { left: parent.left; right: parent.right }
                    spacing: 0

                    Repeater {
                        model: root.outputSinks
                        delegate: SettingRow {
                            id: outputRow
                            required property var modelData
                            required property int index
                            label:    modelData.description || modelData.name
                            readonly property bool isSpatialTarget: modelData.spatial_target === true
                            readonly property bool isDefaultOutput: modelData.default === true
                            readonly property bool isEffectiveDefault: modelData.effective_default === true
                            sublabel: isSpatialTarget ? "Spatial Audio: On" : (isDefaultOutput ? "Default" : "")
                            isLast:   index === root.outputSinks.length - 1 && root.hiddenOutputSinks.length === 0
                            clickable: true
                            controlBlocksRowClick: false
                            onClicked: root.setOutputAsDefault(modelData.name)
                            onRightClicked: (x, y) => {
                                const pt = outputRow.mapToItem(outputMenu, x, y)
                                root.openOutputMenu(modelData, pt.x + 6, pt.y + 6)
                            }

                            Rectangle {
                                width: 20; height: 20; radius: 10
                                color: isEffectiveDefault ? root.accent : Qt.rgba(1, 1, 1, 0.035)
                                border.width: 1
                                border.color: isEffectiveDefault ? root.accent : Qt.rgba(1,1,1,0.24)
                                Behavior on color { ColorAnimation { duration: 130 } }
                                Behavior on border.color { ColorAnimation { duration: 130 } }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 6; height: 6; radius: 3; color: "#fff"
                                    visible: isEffectiveDefault
                                }
                            }
                        }
                    }

                    SettingRow {
                        visible: root.hiddenOutputSinks.length > 0
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.audio.label.hidden_output_devices"]) || "Hidden output devices")
                        sublabel: root.hiddenOutputSinks.length === 1
                            ? "1 device hidden"
                            : root.hiddenOutputSinks.length + " devices hidden"
                        isLast: !root.hiddenOutputsExpanded
                        clickable: true
                        controlBlocksRowClick: false
                        onClicked: root.hiddenOutputsExpanded = !root.hiddenOutputsExpanded

                        Text {
                            text: root.hiddenOutputsExpanded ? "Hide list" : "Show list"
                            color: root.accent
                            font.pixelSize: Theme.fontSizeNormal
                            font.weight: Font.Medium
                        }
                    }

                    Repeater {
                        model: root.hiddenOutputsExpanded ? root.hiddenOutputSinks : []
                        delegate: SettingRow {
                            required property var modelData
                            required property int index
                            label: modelData.description || modelData.name
                            sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.audio.sublabel.hidden"]) || "Hidden")
                            isLast: index === root.hiddenOutputSinks.length - 1
                            clickable: true
                            controlBlocksRowClick: false
                            onClicked: root.showOutput(modelData.name)

                            Text {
                                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.audio.text.show"]) || "Show")
                                color: root.accent
                                font.pixelSize: Theme.fontSizeNormal
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }

            // ── Volume por app ────────────────────────────────────────────
            SectionHeader { text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.audio.text.application_volume"]) || "APPLICATION VOLUME"); Layout.bottomMargin: 12 }

            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 24
                radius: 12; color: root.cardBg
                border.width: 1; border.color: root.cardBorder
                implicitHeight: root.apps.length === 0 ? 64 : appsCol.implicitHeight

                Text {
                    anchors.centerIn: parent
                    visible: root.apps.length === 0
                    text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.audio.text.no_active_audio_streams"]) || "No active audio streams")
                    color: root.textSecondary; font.pixelSize: Theme.fontSizeNormal
                }

                ColumnLayout {
                    id: appsCol
                    anchors { left: parent.left; right: parent.right }
                    spacing: 0
                    visible: root.apps.length > 0

                    Repeater {
                        model: root.apps
                        delegate: Item {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: 56

                            function capitalizeName(name) {
                                return name.replace(/\b\w/g, c => c.toUpperCase())
                            }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                spacing: 10

                                // ── Ícone do app ──────────────────────────
                                Rectangle {
                                    id: iconRect
                                    width: 28; height: 28; radius: 7
                                    property bool isMuted: (modelData.index in root.mutedMap)
                                        ? root.mutedMap[modelData.index]
                                        : modelData.muted
                                    color: isMuted ? Qt.rgba(1,0.27,0.23,0.2) : Qt.rgba(1,1,1,0.06)
                                    border.width: 1
                                    border.color: isMuted ? Qt.rgba(1,0.27,0.23,0.4) : root.cardBorder
                                    Behavior on color       { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    AppIcon {
                                        id: appIcon
                                        anchors.centerIn: parent
                                        appData: modelData
                                        iconSize: 22
                                        iconRadius: 6
                                        iconPadding: 2
                                        sourcePixelSize: 96
                                        fallbackRadius: 6
                                        fallbackColor: Qt.rgba(1, 1, 1, 0.08)
                                        fallbackBorderColor: "transparent"
                                        fallbackTextColor: root.textSecondary
                                        fallbackFontFamily: ""
                                        fallbackFontSize: 10
                                        opacity: iconRect.isMuted ? 0.35 : 1.0
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const idx = modelData.index
                                            const indexes = root.appIndexes(modelData)
                                            const current = (idx in root.mutedMap) ? root.mutedMap[idx] : modelData.muted
                                            const m = !current
                                            root.mutedMap = Object.assign({}, root.mutedMap, { [idx]: m })
                                            if (indexes.length > 1)
                                                root._apply({ app_indexes: indexes, muted: m })
                                            else
                                                root._apply({ app_index: idx, muted: m })
                                        }
                                    }
                                }

                                // ── Nome do app ───────────────────────────
                                Text {
                                    Layout.preferredWidth: 100
                                    text: capitalizeName(modelData.name)
                                    property bool isMuted: (modelData.index in root.mutedMap)
                                        ? root.mutedMap[modelData.index]
                                        : modelData.muted
                                    color: isMuted ? root.textSecondary : root.textPrimary
                                    font.pixelSize: Theme.fontSizeNormal; elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                // ── Slider ────────────────────────────────
                                Item {
                                    id: sliderItem
                                    Layout.fillWidth: true
                                    implicitHeight: 28
                                    property real maxVal: 1.5
                                    property real sliderValue: (root.volumeMap[modelData.index] !== undefined) ? root.volumeMap[modelData.index] : (modelData.volume || 0.0)
                                    property bool animatePosition: false

                                    Timer {
                                        interval: 180
                                        running: true
                                        repeat: false
                                        onTriggered: sliderItem.animatePosition = true
                                    }

                                    Binding {
                                        target: sliderItem
                                        property: "sliderValue"
                                        value: (modelData.index in root.volumeMap)
                                            ? root.volumeMap[modelData.index]
                                            : modelData.volume
                                        when: !root._sliderActive
                                        restoreMode: Binding.RestoreNone
                                    }

                                    // track
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width; height: 4; radius: 2
                                        color: Qt.rgba(1,1,1,0.1)
                                        Rectangle {
                                            width: Math.min(1, sliderItem.sliderValue / sliderItem.maxVal) * parent.width
                                            height: parent.height; radius: 2
                                            color: sliderItem.sliderValue > 1.0 ? root.warningColor : root.accent
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    // thumb
                                    Rectangle {
                                        x: Math.min(1, sliderItem.sliderValue / sliderItem.maxVal) * (parent.width - width)
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 14; height: 14; radius: 7
                                        color: "#ffffff"
                                        Behavior on x { enabled: sliderItem.animatePosition && !dragMa.drag.active; NumberAnimation { duration: 80 } }
                                    }

                                    MouseArea {
                                        id: dragMa
                                        anchors.fill: parent
                                        drag.target: null
                                        preventStealing: true
                                        cursorShape: Qt.PointingHandCursor
                                        onPressed: (mouse) => {
                                            root._sliderActive = true
                                            const ratio = Math.max(0, Math.min(1, mouse.x / sliderItem.width))
                                            sliderItem.sliderValue = ratio * sliderItem.maxVal
                                            const indexes = root.appIndexes(modelData)
                                            if (indexes.length > 1)
                                                root._apply({ app_indexes: indexes, volume: sliderItem.sliderValue })
                                            else
                                                root._apply({ app_index: modelData.index, volume: sliderItem.sliderValue })
                                        }
                                        onPositionChanged: (mouse) => {
                                            if (!pressed) return
                                            const ratio = Math.max(0, Math.min(1, mouse.x / sliderItem.width))
                                            sliderItem.sliderValue = ratio * sliderItem.maxVal
                                            const indexes = root.appIndexes(modelData)
                                            if (indexes.length > 1)
                                                root._apply({ app_indexes: indexes, volume: sliderItem.sliderValue })
                                            else
                                                root._apply({ app_index: modelData.index, volume: sliderItem.sliderValue })
                                        }
                                        onReleased: {
                                            const map = Object.assign({}, root.volumeMap)
                                            map[modelData.index] = sliderItem.sliderValue
                                            root.volumeMap = map
                                            root._sliderActive = false
                                        }
                                    }
                                }

                                // ── Percentual ────────────────────────────
                                Text {
                                    Layout.preferredWidth: 36
                                    text: Math.round(sliderItem.sliderValue * 100) + "%"
                                    color: sliderItem.sliderValue > 1.0 ? root.warningColor : root.textSecondary
                                    font.pixelSize: 11; horizontalAlignment: Text.AlignRight
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }

                            Rectangle {
                                visible: index < root.apps.length - 1
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 16 }
                                height: 1; color: root.cardBorder
                            }
                        }
                    }
                }
            }

            Item { implicitHeight: 8 }
        }
    }

    ContextMenu {
        id: outputMenu
        anchors.fill: parent
        menuWidth: 220
        panelColor: root.popupBg
        borderColor: root.cardBorder

        ContextMenuAction {
            label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.audio.label.set_as_default"]) || "Set as default")
            actionEnabled: !(root.outputMenuSink.effective_default === true)
            onTriggered: {
                outputMenu.closeMenu()
                root.setOutputAsDefault(root.outputMenuSink.name || "")
            }
        }

        ContextMenuAction {
            label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.audio.label.rename"]) || "Rename")
            onTriggered: {
                const sink = root.outputMenuSink || {}
                outputMenu.closeMenu()
                renamePopup.openRename(sink.name || "", sink.description || sink.name || "")
            }
        }

        ContextMenuDivider {}

        ContextMenuAction {
            label: root.outputMenuSink.hidden === true ? "Show" : "Hide"
            actionEnabled: !(root.outputMenuSink.effective_default === true && root.outputMenuSink.hidden !== true)
            onTriggered: {
                outputMenu.closeMenu()
                if (root.outputMenuSink.hidden === true)
                    root.showOutput(root.outputMenuSink.name || "")
                else
                    root.hideOutput(root.outputMenuSink.name || "")
            }
        }
    }

    Popup {
        id: renamePopup
        anchors.centerIn: parent
        width: 320; height: 160
        modal: true; focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            color: root.popupBg
            border.color: root.cardBorder; border.width: 1
            radius: 12
        }

        property string currentName: ""
        property string targetSink: ""

        function openRename(sinkId, curName) {
            targetSink = sinkId
            currentName = curName
            nameInput.text = curName
            nameInput.selectAll()
            open()
            nameInput.forceActiveFocus()
        }

        ColumnLayout {
            anchors { fill: parent; margins: 20 }
            spacing: 16
            
            Text {
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.audio.text.rename_audio_output"]) || "Rename Audio Output")
                color: root.textPrimary
                font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium
            }
            
            TextField {
                id: nameInput
                Layout.fillWidth: true
                color: root.textPrimary; font.pixelSize: Theme.fontSizeNormal
                padding: 8
                background: Rectangle {
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.color: nameInput.activeFocus ? root.accent : Qt.rgba(1, 1, 1, 0.1)
                    radius: 6; border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }
                onAccepted: renamePopup.apply()
            }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Item { Layout.fillWidth: true }
                
                Rectangle {
                    implicitWidth: 70; implicitHeight: 32; radius: 6
                    color: cancelMa.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
                    border.width: 1; border.color: root.cardBorder
                    Text { anchors.centerIn: parent; text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.audio.text.cancel"]) || "Cancel"); color: root.textSecondary; font.pixelSize: Theme.fontSizeNormal }
                    MouseArea {
                        id: cancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: renamePopup.close()
                    }
                }
                
                Rectangle {
                    implicitWidth: 70; implicitHeight: 32; radius: 6
                    color: saveMa.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent
                    Text { anchors.centerIn: parent; text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.audio.text.save"]) || "Save"); color: "#fff"; font.pixelSize: Theme.fontSizeNormal; font.weight: Font.Medium }
                    MouseArea {
                        id: saveMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: renamePopup.apply()
                    }
                }
            }
        }
        function apply() {
            root._apply({ rename: nameInput.text, name: targetSink })
            close()
        }
    }
}
