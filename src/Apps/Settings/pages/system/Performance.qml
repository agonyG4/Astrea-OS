import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../AstreaComponents"
import "../../AstreaI18n" as AstreaI18n

ScrollPage {
    id: root
    maxWidth: 900

    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color cardBg: Theme.cardBg
    readonly property color cardBorder: Theme.cardBorder
    readonly property color accent: Theme.accent
    readonly property color popupBg: Theme.popupBg
    readonly property color errorColor: Theme.errorColor
    readonly property color warningColor: Theme.warningColor
    readonly property color successColor: Theme.successColor

    readonly property string astreaRoot: (Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")) + ""
    readonly property string performanceCli: astreaRoot + "/System/scripts/astrea-performance"
    readonly property var profileOptions: ["Economy", "Balanced", "Performance"]
    readonly property var profileValues: ["power-saver", "balanced", "performance"]
    readonly property var recommendedSchedulerIds: ["bpfland", "lavd", "flash", "p2dq"]
    readonly property var fallbackScxCatalog: [
        ({ id: "bpfland", label: "Bpfland", best_for: "Gaming, desktop, multimedia", description: "General interactive scheduler with cache-aware task placement. Best default for this desktop." }),
        ({ id: "lavd", label: "LAVD", best_for: "Gaming, latency-sensitive work", description: "Latency-aware virtual deadline scheduler. Strong choice for games and real-time-ish desktop work." }),
        ({ id: "flash", label: "Flash", best_for: "Desktop responsiveness", description: "Snappy general-purpose scheduler for mixed desktop load." }),
        ({ id: "p2dq", label: "P2DQ", best_for: "Throughput with selectable modes", description: "Parallel queue scheduler with profiles for gaming, latency, power saving, and server workloads." })
    ]
    readonly property var fallbackScxModes: [
        ({ id: "auto", label: "Auto", description: "Uses the scheduler's default policy." }),
        ({ id: "gaming", label: "Gaming", description: "Prioritizes frame pacing and interactive response during games." }),
        ({ id: "lowlatency", label: "Low latency", description: "Favours quick wakeups for audio, capture, and latency-sensitive work." }),
        ({ id: "powersave", label: "Power save", description: "Reduces power draw, heat, and fan noise." }),
        ({ id: "server", label: "Server", description: "Favours throughput and steady parallel work." })
    ]

    property bool loading: true
    property bool configLoaded: false
    property bool statusLoaded: false
    property bool applyingProfile: false
    property bool applyingScheduler: false
    property bool schedulerSelectionDirty: false
    property bool showAdvancedSchedulers: false
    property bool autoAppliedProfile: false
    property string errorMessage: ""
    property string saveMessage: ""
    property string _configBuf: ""
    property string _statusBuf: ""
    property string _schedulerBuf: ""
    property int selectedProfile: 1
    property int selectedScheduler: 0
    property int selectedScxMode: 1
    property var runtimeStatus: ({
        powerprofilesctl: false,
        gamemode: false,
        gamemode_active: false,
        profile: "unknown",
        scx: ({ scxctl: false, service: "unknown", current: ({ active: false }), supported: [], catalog: [], modes: [], error: "" })
    })
    property var perfConfig: ({
        profile: "balanced",
        auto_apply: true,
        prefer_gamemode: true,
        launch_boost: true,
        reduce_effects: false,
        limit_background_tasks: false,
        show_status_badges: true,
        scx_scheduler: "bpfland",
        scx_mode: "gaming"
    })

    function syncLoading() {
        root.loading = !(root.configLoaded && root.statusLoaded)
    }

    function profileIndexForValue(value) {
        const idx = root.profileValues.indexOf(value)
        return idx >= 0 ? idx : 1
    }

    function profileLabelForValue(value) {
        const idx = profileIndexForValue(value)
        return root.profileOptions[idx]
    }

    function scxData() {
        return root.runtimeStatus.scx || ({})
    }

    function schedulerCatalog() {
        const scx = root.scxData()
        return scx.catalog && scx.catalog.length ? scx.catalog : root.fallbackScxCatalog
    }

    function schedulerModes() {
        const scx = root.scxData()
        return scx.modes && scx.modes.length ? scx.modes : root.fallbackScxModes
    }

    function schedulerOptions() {
        const list = root.schedulerCatalog()
        var result = []
        for (var i = 0; i < list.length; i++)
            result.push(list[i].label || list[i].id)
        return result
    }

    function schedulerModeOptions() {
        const list = root.schedulerModes()
        var result = []
        for (var i = 0; i < list.length; i++)
            result.push(list[i].label || list[i].id)
        return result
    }

    function schedulerIndexFor(id) {
        const list = root.schedulerCatalog()
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id)
                return i
        }
        return 0
    }

    function modeIndexFor(id) {
        const list = root.schedulerModes()
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id)
                return i
        }
        return Math.min(1, list.length - 1)
    }

    function schedulerById(id) {
        const list = root.schedulerCatalog()
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id)
                return list[i]
        }
        return null
    }

    function recommendedSchedulers() {
        const list = []
        for (var i = 0; i < root.recommendedSchedulerIds.length; i++) {
            const item = root.schedulerById(root.recommendedSchedulerIds[i])
            if (item)
                list.push(item)
        }
        return list
    }

    function advancedSchedulers() {
        const result = []
        const list = root.schedulerCatalog()
        for (var i = 0; i < list.length; i++) {
            if (root.recommendedSchedulerIds.indexOf(list[i].id) < 0)
                result.push(list[i])
        }
        return result
    }

    function schedulerSubtitle(item) {
        if (!item)
            return ""
        const best = item.best_for ? "Best for: " + item.best_for : ""
        if (item.description && best)
            return item.description + "\n" + best
        return item.description || best
    }

    function modeSubtitle(item) {
        if (!item)
            return ""
        return item.description || ""
    }

    function schedulerSelected(id) {
        return root.selectedSchedulerInfo().id === id
    }

    function modeSelected(id) {
        return root.selectedModeInfo().id === id
    }

    function selectScheduler(id) {
        const idx = root.schedulerIndexFor(id)
        if (idx < 0)
            return
        root.selectedScheduler = idx
        root.schedulerSelectionDirty = true
    }

    function selectMode(id) {
        const idx = root.modeIndexFor(id)
        if (idx < 0)
            return
        root.selectedScxMode = idx
        root.schedulerSelectionDirty = true
    }

    function applySchedulerSublabel() {
        if (!root.scxData().scxctl)
            return "Install or enable sched-ext tools to switch schedulers here"
        const info = root.selectedSchedulerInfo()
        const mode = root.selectedModeInfo()
        if (root.schedulerSelectionDirty)
            return "Selected: " + info.label + " / " + mode.label + ". Apply to switch the live system."
        return "Current preference: " + info.label + " / " + mode.label
    }

    function selectedSchedulerInfo() {
        const list = root.schedulerCatalog()
        return list[Math.max(0, Math.min(root.selectedScheduler, list.length - 1))] || ({ id: "bpfland", label: "Bpfland", best_for: "Desktop", description: "" })
    }

    function selectedModeInfo() {
        const list = root.schedulerModes()
        return list[Math.max(0, Math.min(root.selectedScxMode, list.length - 1))] || ({ id: "gaming", label: "Gaming", description: "" })
    }

    function syncSchedulerSelectionFromConfig() {
        root.selectedScheduler = root.schedulerIndexFor(root.perfConfig.scx_scheduler || "bpfland")
        root.selectedScxMode = root.modeIndexFor(root.perfConfig.scx_mode || "gaming")
        if (root.recommendedSchedulerIds.indexOf(root.selectedSchedulerInfo().id) < 0)
            root.showAdvancedSchedulers = true
        root.schedulerSelectionDirty = false
    }

    function scxCurrentSummary() {
        const scx = root.scxData()
        const current = scx.current || ({})
        if (current.active)
            return (current.scheduler_label || current.scheduler || "sched-ext") + " / " + (current.mode_label || current.mode || "mode")
        if (!scx.scxctl)
            return "scxctl unavailable"
        if (scx.error)
            return "sched-ext error"
        return "Kernel default scheduler"
    }

    function scxServiceSummary() {
        const scx = root.scxData()
        const supported = scx.supported || []
        const supportText = supported.length ? "Detected: " + supported.join(", ") : "No sched-ext scheduler detected yet"
        const service = String(scx.service || "unknown")
        const serviceText = service.length > 48 ? "unavailable" : service
        const errorText = scx.error ? ". " + scx.error : ""
        return "Service: " + serviceText + ". " + supportText + errorText
    }

    function scxServiceTone() {
        const service = (root.scxData().service || "").toLowerCase()
        if (service === "active")
            return root.successColor
        if (root.scxData().scxctl)
            return root.warningColor
        return root.errorColor
    }

    function normalizeRuntimeProfile(value) {
        if (value === "power-saver")
            return "Economy"
        if (value === "performance")
            return "Performance"
        if (value === "balanced")
            return "Balanced"
        return "Unknown"
    }

    function saveConfig(showMessage) {
        saveConfigProc.jsonData = JSON.stringify(root.perfConfig)
        saveConfigProc.command = [root.performanceCli, "save", saveConfigProc.jsonData]
        saveConfigProc.showMessage = showMessage
        saveConfigProc.running = false
        saveConfigProc.running = true
    }

    function mutateConfig(mutator, showMessage) {
        var next = JSON.parse(JSON.stringify(root.perfConfig))
        mutator(next)
        root.perfConfig = next
        root.selectedProfile = profileIndexForValue(next.profile)
        saveConfig(showMessage)
    }

    function refreshStatus() {
        if (statusProc.running)
            return
        root._statusBuf = ""
        statusProc.running = true
    }

    function applySelectedProfile() {
        if (!root.runtimeStatus.powerprofilesctl || applyProfileProc.running)
            return
        root.errorMessage = ""
        applyProfileProc.command = [root.performanceCli, "set", root.profileValues[root.selectedProfile]]
        root.applyingProfile = true
        applyProfileProc.running = false
        applyProfileProc.running = true
    }

    function applySelectedScheduler() {
        if (!root.scxData().scxctl || applySchedulerProc.running)
            return
        const scheduler = root.selectedSchedulerInfo().id
        const mode = root.selectedModeInfo().id
        root.errorMessage = ""
        root._schedulerBuf = ""
        root.applyingScheduler = true
        applySchedulerProc.command = [root.performanceCli, "set-scheduler", scheduler, mode]
        applySchedulerProc.running = false
        applySchedulerProc.running = true
    }

    function maybeAutoApplyProfile() {
        if (root.autoAppliedProfile || !root.configLoaded || !root.statusLoaded)
            return
        root.autoAppliedProfile = true

        if (!root.runtimeStatus.powerprofilesctl)
            return

        const desired = root.profileValues[root.selectedProfile]
        if (root.runtimeStatus.profile === desired)
            return

        root.applySelectedProfile()
    }

    Component.onCompleted: {
        loadConfigProc.running = true
        refreshStatus()
    }

    Process {
        id: loadConfigProc
        command: [root.performanceCli, "get"]
        stdout: SplitParser {
            onRead: line => root._configBuf += line
        }
        onExited: {
            try {
                const cfg = JSON.parse(root._configBuf || "{}")
                root.perfConfig = Object.assign({}, root.perfConfig, cfg)
                root.perfConfig.auto_apply = true
                root.selectedProfile = root.profileIndexForValue(root.perfConfig.profile)
                root.syncSchedulerSelectionFromConfig()
            } catch (e) {
                root.errorMessage = "Erro lendo performance.json: " + e
            }
            root._configBuf = ""
            root.configLoaded = true
            root.syncLoading()
            root.maybeAutoApplyProfile()
        }
    }

    Process {
        id: statusProc
        command: [root.performanceCli, "status"]
        stdout: SplitParser {
            onRead: line => root._statusBuf += line
        }
        onExited: {
            try {
                root.runtimeStatus = JSON.parse(root._statusBuf || "{}")
                if (root.configLoaded && !root.schedulerSelectionDirty)
                    root.syncSchedulerSelectionFromConfig()
            } catch (e) {
                root.errorMessage = "Erro lendo estado de performance: " + e
            }
            root._statusBuf = ""
            root.statusLoaded = true
            root.syncLoading()
            root.maybeAutoApplyProfile()
        }
    }

    Process {
        id: saveConfigProc
        property string jsonData: ""
        property bool showMessage: false
        command: []
        onExited: {
            if (showMessage) {
                root.saveMessage = "Preferência salva"
                saveMessageTimer.restart()
            }
        }
    }

    Process {
        id: applyProfileProc
        command: []
        running: false
        onExited: code => {
            root.applyingProfile = false
            if (code !== 0) {
                root.errorMessage = "Não foi possível aplicar o perfil agora"
                return
            }
            root.perfConfig.profile = root.profileValues[root.selectedProfile]
            root.perfConfig.auto_apply = true
            root.saveConfig(false)
            root.refreshStatus()
        }
    }

    Process {
        id: applySchedulerProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: line => root._schedulerBuf += line
        }
        onExited: code => {
            root.applyingScheduler = false
            if (code !== 0) {
                root.errorMessage = "Não foi possível aplicar o sched-ext agora"
                return
            }
            const info = root.selectedSchedulerInfo()
            const mode = root.selectedModeInfo()
            root.perfConfig.scx_scheduler = info.id
            root.perfConfig.scx_mode = mode.id
            root.schedulerSelectionDirty = false
            root.saveMessage = "Scheduler aplicado: " + info.label + " / " + mode.label
            saveMessageTimer.restart()
            root.refreshStatus()
        }
    }

    Timer {
        id: saveMessageTimer
        interval: 1800
        repeat: false
        onTriggered: root.saveMessage = ""
    }

    Timer {
        interval: 7000
        repeat: true
        running: true
        onTriggered: {
            if (!root.loading && !statusProc.running && !applyProfileProc.running && !applySchedulerProc.running)
                root.refreshStatus()
        }
    }

    component StatusBadge: Rectangle {
        property string label: ""
        property color tone: Qt.rgba(1, 1, 1, 0.14)
        radius: 9
        color: tone
        implicitHeight: 24
        implicitWidth: badgeText.implicitWidth + 18

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: parent.label
            color: "#ffffff"
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }

    component ActionButton: Rectangle {
        property string label: ""
        property bool actionEnabled: true
        signal clicked()

        implicitHeight: 34
        implicitWidth: actionText.implicitWidth + 26
        radius: 10
        color: actionEnabled ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.03)
        border.width: 1
        border.color: actionEnabled ? root.cardBorder : Qt.rgba(1, 1, 1, 0.04)
        opacity: actionEnabled ? 1 : 0.55

        Text {
            id: actionText
            anchors.centerIn: parent
            text: parent.label
            color: root.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        MouseArea {
            anchors.fill: parent
            enabled: parent.actionEnabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: parent.clicked()
        }
    }

    component ChoiceDot: Rectangle {
        property bool checked: false

        implicitWidth: 22
        implicitHeight: 22
        radius: 11
        color: checked ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : Qt.rgba(1, 1, 1, 0.035)
        border.width: 1
        border.color: checked ? root.accent : root.cardBorder

        Rectangle {
            anchors.centerIn: parent
            visible: parent.checked
            width: 9
            height: 9
            radius: 5
            color: root.accent
        }
    }

    Item {
        Layout.alignment: Qt.AlignHCenter
        visible: root.loading
        width: 48
        height: 48
        BusyIndicator {
            anchors.fill: parent
            running: root.loading
        }
    }

    ColumnLayout {
        width: parent.width
        spacing: 0
        visible: !root.loading

        SectionHeader {
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.performance.text.performance"]) || "PERFORMANCE")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        Text {
            visible: root.saveMessage !== "" || root.errorMessage !== ""
            text: root.errorMessage !== "" ? root.errorMessage : root.saveMessage
            color: root.errorMessage !== "" ? root.errorColor : root.successColor
            font.pixelSize: 12
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.bottomMargin: 18
        }

        SectionHeader {
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.performance.text.power_profile"]) || "POWER PROFILE")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 24
            radius: 12
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder
            implicitHeight: powerCol.implicitHeight

            ColumnLayout {
                id: powerCol
                anchors { left: parent.left; right: parent.right }
                spacing: 0

                SettingRow {
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.performance.label.preferred_profile"]) || "Preferred profile")
                    sublabel: root.runtimeStatus.powerprofilesctl
                        ? "O Astrea aplica este perfil automaticamente quando detectar diferença"
                        : "O Astrea salva este perfil e aplica automaticamente quando o daemon estiver disponível"
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder

                    SelectButton {
                        implicitWidth: 160
                        label: root.profileOptions[root.selectedProfile]
                        options: root.profileOptions
                        selectedIndex: root.selectedProfile
                        accent: root.accent
                        textPrimary: root.textPrimary
                        textSecondary: root.textSecondary
                        popupBg: root.popupBg
                        onSelected: index => {
                            root.selectedProfile = index
                            root.mutateConfig(function(next) {
                                next.profile = root.profileValues[index]
                            }, true)
                        }
                    }
                    isLast: true
                }
            }
        }

        SectionHeader {
            text: "SCHED-EXT"
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            Layout.bottomMargin: 14
            SettingRow {
                label: "Active scheduler"
                sublabel: root.scxServiceSummary()
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder

                StatusBadge {
                    label: root.scxCurrentSummary()
                    tone: Qt.rgba(root.scxServiceTone().r, root.scxServiceTone().g, root.scxServiceTone().b, 0.22)
                }
            }
            SettingRow {
                label: "Apply sched-ext profile"
                sublabel: root.applySchedulerSublabel()
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: true

                ActionButton {
                    label: root.applyingScheduler ? "Applying..." : (root.schedulerSelectionDirty ? "Apply" : "Applied")
                    actionEnabled: root.scxData().scxctl && root.schedulerSelectionDirty && !root.applyingScheduler
                    onClicked: root.applySelectedScheduler()
                }
            }
        }

        Text {
            text: "RECOMMENDED SCHEDULERS"
            color: root.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.bottomMargin: 8
        }

        FormCard {
            Layout.bottomMargin: 14
            Repeater {
                model: root.recommendedSchedulers()
                delegate: SettingRow {
                    required property int index
                    required property var modelData

                    label: modelData.label || modelData.id
                    sublabel: root.schedulerSubtitle(modelData)
                    clickable: true
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder
                    isLast: index === root.recommendedSchedulers().length - 1
                    onClicked: root.selectScheduler(modelData.id)

                    ChoiceDot {
                        checked: root.schedulerSelected(modelData.id)
                    }
                }
            }
        }

        FormCard {
            Layout.bottomMargin: root.showAdvancedSchedulers ? 14 : 24
            SettingRow {
                label: root.showAdvancedSchedulers ? "Hide advanced schedulers" : "Show advanced schedulers"
                sublabel: "Experimental or workload-specific schedulers. Useful for testing, not the first place to start."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                clickable: true
                isLast: true
                onClicked: root.showAdvancedSchedulers = !root.showAdvancedSchedulers

                ActionButton {
                    label: root.showAdvancedSchedulers ? "Hide" : "Show"
                    onClicked: root.showAdvancedSchedulers = !root.showAdvancedSchedulers
                }
            }
        }

        FormCard {
            visible: root.showAdvancedSchedulers
            Layout.bottomMargin: 24
            Repeater {
                model: root.advancedSchedulers()
                delegate: SettingRow {
                    required property int index
                    required property var modelData

                    label: modelData.label || modelData.id
                    sublabel: root.schedulerSubtitle(modelData)
                    clickable: true
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder
                    isLast: index === root.advancedSchedulers().length - 1
                    onClicked: root.selectScheduler(modelData.id)

                    ChoiceDot {
                        checked: root.schedulerSelected(modelData.id)
                    }
                }
            }
        }

        Text {
            text: "SCHEDULER MODE"
            color: root.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.bottomMargin: 8
        }

        FormCard {
            Layout.bottomMargin: 24
            Repeater {
                model: root.schedulerModes()
                delegate: SettingRow {
                    required property int index
                    required property var modelData

                    label: modelData.label || modelData.id
                    sublabel: root.modeSubtitle(modelData)
                    clickable: true
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder
                    isLast: index === root.schedulerModes().length - 1
                    onClicked: root.selectMode(modelData.id)

                    ChoiceDot {
                        checked: root.modeSelected(modelData.id)
                    }
                }
            }
        }

        SectionHeader {
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.performance.text.system_behavior"]) || "SYSTEM BEHAVIOR")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 28
            radius: 12
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder
            implicitHeight: behaviorCol.implicitHeight

            ColumnLayout {
                id: behaviorCol
                anchors { left: parent.left; right: parent.right }
                spacing: 0

                SettingRow {
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.performance.label.gamemode"]) || "Gamemode")
                    sublabel: root.runtimeStatus.gamemode
                        ? "Permite que o Astrea trate o GameMode como prioridade quando ele estiver disponível"
                        : "Gamemode não detectado; a preferência fica salva para depois"
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder
                    isLast: true

                    ToggleSwitch {
                        checked: !!root.perfConfig.prefer_gamemode
                        onToggled: root.mutateConfig(function(next) {
                            next.prefer_gamemode = !next.prefer_gamemode
                            next.auto_apply = true
                        }, true)
                    }
                }
            }
        }
    }
}
