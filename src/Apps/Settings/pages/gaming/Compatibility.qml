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
    readonly property color cardBorder: Theme.cardBorder
    readonly property color accent: Theme.accent
    readonly property color popupBg: Theme.popupBg
    readonly property color errorColor: Theme.errorColor
    readonly property color successColor: Theme.successColor
    readonly property string astreaRoot: (Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")) + ""
    readonly property string helperPath: astreaRoot + "/System/scripts/astrea-gaming-settings"
    readonly property string homePath: Quickshell.env("HOME") || ""
    readonly property var runnerOptions: ["Proton", "Wine", "Auto"]
    readonly property var runnerValues: ["proton", "wine", "auto"]

    property bool loading: true
    property string message: ""
    property bool messageIsError: false
    property string buffer: ""
    property var compatibility: ({})

    function t(key, fallback, params) {
        return AstreaI18n.I18n.tr(key, fallback, params)
    }

    function runnerIndexFor(value) {
        const idx = root.runnerValues.indexOf(value || "proton")
        return idx >= 0 ? idx : 0
    }

    function updateConfig(key, value, showMessage) {
        var next = Object.assign({}, root.compatibility)
        next[key] = value
        root.compatibility = next
        root.save(showMessage)
    }

    function save(showMessage) {
        saveProc.showMessage = showMessage
        saveProc.command = [root.helperPath, "save-compatibility", JSON.stringify(root.compatibility)]
        saveProc.running = false
        saveProc.running = true
    }

    function loadPayload() {
        root.buffer = ""
        loadProc.running = false
        loadProc.running = true
    }

    Component.onCompleted: loadPayload()

    Process {
        id: loadProc
        command: [root.helperPath, "get"]
        stdout: SplitParser { onRead: line => root.buffer += line }
        onExited: code => {
            root.loading = false
            if (code !== 0) {
                root.message = root.t("apps.settings.pages.gaming.compatibility.error.load", "Could not load compatibility settings")
                root.messageIsError = true
                return
            }
            try {
                const payload = JSON.parse(root.buffer || "{}")
                root.compatibility = payload.compatibility || ({})
            } catch (e) {
                root.message = root.t("apps.settings.pages.gaming.compatibility.error.parse", "Could not parse settings: {error}", { error: e })
                root.messageIsError = true
            }
            root.buffer = ""
        }
    }

    Process {
        id: saveProc
        property bool showMessage: false
        property string saveBuffer: ""
        command: []
        stdout: SplitParser { onRead: line => saveProc.saveBuffer += line }
        onExited: code => {
            if (code !== 0) {
                root.message = root.t("apps.settings.pages.gaming.compatibility.error.save", "Could not save compatibility settings")
                root.messageIsError = true
                return
            }
            try {
                const payload = JSON.parse(saveProc.saveBuffer || "{}")
                if (payload.compatibility)
                    root.compatibility = payload.compatibility
            } catch (e) {}
            saveProc.saveBuffer = ""
            if (saveProc.showMessage) {
                root.message = root.t("apps.settings.pages.gaming.compatibility.status.saved", "Compatibility settings saved")
                root.messageIsError = false
                messageTimer.restart()
            }
        }
    }

    Timer {
        id: messageTimer
        interval: 2200
        repeat: false
        onTriggered: root.message = ""
    }

    component ActionButton: Rectangle {
        property string label: ""
        signal clicked()
        implicitHeight: 34
        implicitWidth: actionText.implicitWidth + 28
        radius: 8
        color: buttonArea.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: root.cardBorder
        Text {
            id: actionText
            anchors.centerIn: parent
            text: parent.label
            color: root.textPrimary
            font.pixelSize: 12
            font.weight: Font.Medium
        }
        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    component CompactField: TextField {
        property int fieldWidth: 170
        implicitWidth: fieldWidth
        implicitHeight: 34
        color: root.textPrimary
        font.pixelSize: 13
        selectByMouse: true
        background: Rectangle {
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
            border.color: parent.activeFocus ? root.accent : root.cardBorder
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
            text: root.t("apps.settings.pages.gaming.compatibility.text.compatibility", "COMPATIBILIDADE")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        Text {
            visible: root.message !== ""
            text: root.message
            color: root.messageIsError ? root.errorColor : root.successColor
            font.pixelSize: 12
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.bottomMargin: 18
        }

        FormCard {
            Layout.bottomMargin: 24
            SettingRow {
                label: root.t("apps.settings.pages.gaming.compatibility.label.runner", "Abrir .exe com")
                sublabel: root.t("apps.settings.pages.gaming.compatibility.sublabel.runner", "Proton usa o prefixo compartilhado do Astrea; Wine usa o mesmo prefixo para preservar saves.")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                SelectButton {
                    implicitWidth: 130
                    label: root.runnerOptions[root.runnerIndexFor(root.compatibility.runner)]
                    options: root.runnerOptions
                    selectedIndex: root.runnerIndexFor(root.compatibility.runner)
                    accent: root.accent
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    popupBg: root.popupBg
                    onSelected: index => root.updateConfig("runner", root.runnerValues[index], true)
                }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.compatibility.label.proton_profile", "Usar perfil Proton")
                sublabel: root.t("apps.settings.pages.gaming.compatibility.sublabel.proton_profile", "Reaproveita GameMode, MangoHud, Gamescope e flags da página Proton.")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: true
                ToggleSwitch {
                    checked: root.compatibility.use_proton_profile === undefined ? true : !!root.compatibility.use_proton_profile
                    onToggled: root.updateConfig("use_proton_profile", !(root.compatibility.use_proton_profile === undefined ? true : root.compatibility.use_proton_profile), true)
                }
            }
        }

        SectionHeader {
            text: root.t("apps.settings.pages.gaming.compatibility.text.runtime", "RUNTIME")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            Layout.bottomMargin: 24
            SettingRow {
                label: "GameMode"
                sublabel: root.compatibility.use_proton_profile ? "Controlled by the Proton page." : "Adds gamemoderun before the selected runner when available."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                enabled: !root.compatibility.use_proton_profile
                opacity: enabled ? 1 : 0.45
                ToggleSwitch { checked: !!root.compatibility.gamemode; onToggled: root.updateConfig("gamemode", !root.compatibility.gamemode, true) }
            }
            SettingRow {
                label: "MangoHud"
                sublabel: root.compatibility.use_proton_profile ? "Controlled by the Proton page." : "Uses --mangoapp automatically when Gamescope is enabled."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                enabled: !root.compatibility.use_proton_profile
                opacity: enabled ? 1 : 0.45
                ToggleSwitch { checked: !!root.compatibility.mangohud; onToggled: root.updateConfig("mangohud", !root.compatibility.mangohud, true) }
            }
            SettingRow {
                label: "Gamescope"
                sublabel: root.compatibility.use_proton_profile ? "Controlled by the Proton page." : "Uses the Gamescope tuning from the Proton page."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                enabled: !root.compatibility.use_proton_profile
                opacity: enabled ? 1 : 0.45
                isLast: true
                ToggleSwitch { checked: !!root.compatibility.gamescope; onToggled: root.updateConfig("gamescope", !root.compatibility.gamescope, true) }
            }
        }

        SectionHeader {
            text: "ADVANCED"
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            Layout.bottomMargin: 24
            SettingRow {
                label: "Custom environment"
                sublabel: "Space-separated KEY=VALUE pairs used only when Proton profile is off."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                enabled: !root.compatibility.use_proton_profile
                opacity: enabled ? 1 : 0.45
                CompactField {
                    fieldWidth: 260
                    text: root.compatibility.extra_env || ""
                    placeholderText: "PROTON_LOG=1"
                    placeholderTextColor: root.textSecondary
                    onEditingFinished: root.updateConfig("extra_env", text, true)
                }
            }
            SettingRow {
                label: "Custom prefix"
                sublabel: "Command prefix inserted before Wine/Proton when Proton profile is off."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                enabled: !root.compatibility.use_proton_profile
                opacity: enabled ? 1 : 0.45
                isLast: true
                CompactField {
                    fieldWidth: 260
                    text: root.compatibility.extra_prefix || ""
                    placeholderText: "env DXVK_LOG_LEVEL=none"
                    placeholderTextColor: root.textSecondary
                    onEditingFinished: root.updateConfig("extra_prefix", text, true)
                }
            }
        }

        SectionHeader {
            text: "PATHS"
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            SettingRow {
                label: "Prefix"
                sublabel: root.homePath + "/.local/share/AstreaOS/windows-prefixes/shared/proton/pfx"
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
            }
            SettingRow {
                label: "Logs"
                sublabel: root.homePath + "/.local/state/AstreaOS/windows-prefixes/logs"
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: true
                ActionButton {
                    label: "Save"
                    onClicked: root.save(true)
                }
            }
        }
    }
}
