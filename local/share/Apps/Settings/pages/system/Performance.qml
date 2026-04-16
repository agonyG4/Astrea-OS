import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../components"

ScrollPage {
    id: root

    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color cardBg: Theme.cardBg
    readonly property color cardBorder: Theme.cardBorder
    readonly property color accent: Theme.accent
    readonly property color popupBg: Theme.popupBg
    readonly property color errorColor: Theme.errorColor
    readonly property color warningColor: Theme.warningColor
    readonly property color successColor: Theme.successColor

    readonly property string configPath: (Quickshell.env("HOME") || "") + "/.config/AstreaOS/system/performance.json"
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
        launch_boost: false,
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
        saveConfigProc.jsonData = JSON.stringify(root.perfConfig, null, 4)
        saveConfigProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname \"$1\")\"; cat <<'EOF' > \"$1\"\n" + saveConfigProc.jsonData + "\nEOF\n",
            "--", root.configPath]
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
        applyProfileProc.command = ["powerprofilesctl", "set", root.profileValues[root.selectedProfile]]
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
        command: ["bash", "-c",
            "FILE=\"$1\";" +
            "mkdir -p \"$(dirname \"$FILE\")\";" +
            "if [ ! -f \"$FILE\" ]; then " +
            "  printf '%s\n' '{' " +
            "    '  \"profile\": \"balanced\",' " +
            "    '  \"auto_apply\": true,' " +
            "    '  \"prefer_gamemode\": true,' " +
            "    '  \"launch_boost\": false,' " +
            "    '  \"reduce_effects\": false,' " +
            "    '  \"limit_background_tasks\": false,' " +
            "    '  \"show_status_badges\": true' " +
            "  '}' > \"$FILE\"; " +
            "fi; " +
            "cat \"$FILE\"",
            "--", root.configPath]
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
        command: ["bash", "-lc",
            "PPD=0; GMD=0; GMA=0; PROFILE='unknown'; " +
            "if command -v powerprofilesctl >/dev/null 2>&1; then " +
            "  PPD=1; PROFILE=$(powerprofilesctl get 2>/dev/null || printf 'unknown'); " +
            "fi; " +
            "if command -v gamemoded >/dev/null 2>&1; then " +
            "  GMD=1; " +
            "  gamemoded -s >/dev/null 2>&1 && GMA=1 || true; " +
            "fi; " +
            "printf '{\"powerprofilesctl\":%s,\"gamemode\":%s,\"gamemode_active\":%s,\"profile\":\"%s\"}' \"$PPD\" \"$GMD\" \"$GMA\" \"$PROFILE\""]
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

    component ToggleSwitch: Rectangle {
        id: toggle
        width: 36
        height: 20
        radius: 10
        implicitWidth: 36
        implicitHeight: 20
        property bool checked: false
        signal toggled()
        color: checked ? root.accent : Qt.rgba(1, 1, 1, 0.18)
        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            width: 14
            height: 14
            radius: 7
            color: "#ffffff"
            anchors.verticalCenter: parent.verticalCenter
            x: toggle.checked ? parent.width - width - 3 : 3
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled()
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
            text: "PERFORMANCE"
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
            text: "POWER PROFILE"
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
                    label: "Preferred profile"
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
            text: "SYSTEM BEHAVIOR"
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
                    label: "Gamemode"
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
