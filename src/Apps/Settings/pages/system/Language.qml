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
    readonly property color successColor: Theme.successColor

    readonly property string stateJsonScript: (Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")) + "/Core/bridge/state_json.py"
    readonly property string configPath: (Quickshell.env("HOME") || "") + "/.config/AstreaOS/system/settings.json"
    readonly property string defaultConfigJson: JSON.stringify({ "language": "en_US" }, null, 4)
    readonly property var languageValues: ["en_US", "pt_BR"]
    readonly property var languageOptions: [
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["settings.language.option.en_us"]) || "English (US)",
        (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["settings.language.option.pt_br"]) || "Portuguese (Brazil)"
    ]

    property bool loading: true
    property string errorMessage: ""
    property string saveMessage: ""
    property string _configBuf: ""
    property int selectedLanguage: 0
    property var settingsConfig: ({ language: "en_US" })

    function t(key, fallback) {
        return (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages[key]) || fallback
    }

    function indexForLanguage(value) {
        var normalized = (value || "en_US").replace("-", "_")
        var idx = root.languageValues.indexOf(normalized)
        return idx >= 0 ? idx : 0
    }

    function setLanguage(index) {
        if (index < 0 || index >= root.languageValues.length)
            return
        root.selectedLanguage = index
        var next = JSON.parse(JSON.stringify(root.settingsConfig || {}))
        next.language = root.languageValues[index]
        root.settingsConfig = next
        saveConfigProc.jsonData = JSON.stringify(next, null, 4)
        saveConfigProc.command = ["python3", root.stateJsonScript, "write", root.configPath, saveConfigProc.jsonData]
        saveConfigProc.running = false
        saveConfigProc.running = true
    }

    Component.onCompleted: loadConfigProc.running = true

    Process {
        id: loadConfigProc
        command: ["python3", root.stateJsonScript, "read-or-init", root.configPath, root.defaultConfigJson]
        stdout: SplitParser {
            onRead: line => root._configBuf += line
        }
        onExited: code => {
            if (code !== 0) {
                root.errorMessage = root.t("settings.language.error.load", "Could not read language settings.")
            } else {
                try {
                    var cfg = JSON.parse(root._configBuf || "{}")
                    root.settingsConfig = Object.assign({}, root.settingsConfig, cfg)
                    root.selectedLanguage = root.indexForLanguage(root.settingsConfig.language || AstreaI18n.I18n.language)
                } catch (e) {
                    root.errorMessage = root.t("settings.language.error.parse", "Could not parse language settings: ") + e
                }
            }
            root._configBuf = ""
            root.loading = false
        }
    }

    Process {
        id: saveConfigProc
        property string jsonData: ""
        command: []
        onExited: code => {
            if (code === 0) {
                root.saveMessage = root.t("settings.language.saved", "Language updated.")
                AstreaI18n.I18n.reload()
                saveMessageTimer.restart()
            } else {
                root.errorMessage = root.t("settings.language.error.save", "Could not save language settings.")
            }
        }
    }

    Timer {
        id: saveMessageTimer
        interval: 1800
        repeat: false
        onTriggered: root.saveMessage = ""
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
            text: root.t("settings.language.header", "LANGUAGE")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        Text {
            visible: root.errorMessage !== ""
            text: root.errorMessage
            color: root.errorColor
            font.pixelSize: 12
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.bottomMargin: 12
        }

        Text {
            visible: root.saveMessage !== ""
            text: root.saveMessage
            color: root.successColor
            font.pixelSize: 12
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.bottomMargin: 12
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 28
            radius: 12
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder
            implicitHeight: languageCol.implicitHeight

            ColumnLayout {
                id: languageCol
                anchors { left: parent.left; right: parent.right }
                spacing: 0

                SettingRow {
                    label: root.t("settings.language.row.language", "Language")
                    sublabel: root.t("settings.language.row.language.description", "Choose the language used by AstreaOS apps and shell.")
                    isLast: true
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder

                    SelectButton {
                        implicitWidth: 190
                        label: root.languageOptions[root.selectedLanguage]
                        options: root.languageOptions
                        selectedIndex: root.selectedLanguage
                        accent: root.accent
                        textPrimary: root.textPrimary
                        textSecondary: root.textSecondary
                        popupBg: root.popupBg
                        onSelected: index => root.setLanguage(index)
                    }
                }
            }
        }
    }
}
