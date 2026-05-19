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

    property bool loading: true
    property bool configLoaded: false
    property bool statusLoaded: false
    property bool applyingProfile: false
    property bool autoAppliedProfile: false
    property string errorMessage: ""
    property string saveMessage: ""
    property string _configBuf: ""
    property string _statusBuf: ""
    property int selectedProfile: 1
    property var runtimeStatus: ({
        powerprofilesctl: false,
        gamemode: false,
        gamemode_active: false,
        profile: "unknown"
    })
    property var perfConfig: ({
        profile: "balanced",
        auto_apply: true,
        prefer_gamemode: true,
        launch_boost: true,
        reduce_effects: false,
        limit_background_tasks: false,
        show_status_badges: true
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
            if (!root.loading && !statusProc.running && !applyProfileProc.running)
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
