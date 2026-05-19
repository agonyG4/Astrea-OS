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
    readonly property color warningColor: Theme.warningColor
    readonly property string heroArtPath: (Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")) + "/Assets/images/brand/astrea-logo.png"
    readonly property string stateJsonScript: (Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")) + "/Core/bridge/state_json.py"
    readonly property string installedVersion: "Astrea 1"
    readonly property string updateSize: root.selectedChannel === 0 ? "2.4 GB" : "2.6 GB"
    readonly property string updateName: root.selectedChannel === 0 ? "Astrea 1" : "Astrea 1 Beta"

    component ActionButton: Rectangle {
        property string label: ""
        property bool primary: false
        signal clicked()

        implicitHeight: 32
        implicitWidth: actionLabel.implicitWidth + 26
        radius: 10
        color: primary ? root.accent : Qt.rgba(1, 1, 1, 0.06)
        border.width: primary ? 0 : 1
        border.color: root.cardBorder
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: actionLabel
            anchors.centerIn: parent
            text: parent.label
            color: primary ? Theme.accentForeground : root.textPrimary
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    readonly property string configPath: (Quickshell.env("HOME") || "") + "/.config/AstreaOS/system/system.json"
    readonly property string defaultConfigJson: JSON.stringify({ "auto_updater": false, "channel": "stable" }, null, 4)
    readonly property var channelOptions: ["Stable", "Alpha"]
    readonly property var channelValues: ["stable", "alpha"]

    property bool loading: true
    property string errorMessage: ""
    property string saveMessage: ""
    property string _configBuf: ""
    property int selectedChannel: 0
    property var updateConfig: ({
        auto_updater: false,
        channel: "stable"
    })

    function channelIndexForValue(value) {
        const idx = root.channelValues.indexOf(value)
        return idx >= 0 ? idx : 0
    }

    function saveConfig(showMessage) {
        saveConfigProc.jsonData = JSON.stringify(root.updateConfig, null, 4)
        saveConfigProc.command = ["python3", root.stateJsonScript, "write", root.configPath, saveConfigProc.jsonData]
        saveConfigProc.showMessage = showMessage
        saveConfigProc.running = false
        saveConfigProc.running = true
    }

    function mutateConfig(mutator, showMessage) {
        var next = JSON.parse(JSON.stringify(root.updateConfig))
        mutator(next)
        root.updateConfig = next
        root.selectedChannel = root.channelIndexForValue(next.channel)
        saveConfig(showMessage)
    }

    Component.onCompleted: loadConfigProc.running = true

    Process {
        id: loadConfigProc
        command: ["python3", root.stateJsonScript, "read-or-init", root.configPath, root.defaultConfigJson]
        stdout: SplitParser {
            onRead: line => root._configBuf += line
        }
        onExited: {
            try {
                const cfg = JSON.parse(root._configBuf || "{}")
                root.updateConfig = Object.assign({}, root.updateConfig, cfg)
                root.selectedChannel = root.channelIndexForValue(root.updateConfig.channel)
            } catch (e) {
                root.errorMessage = "Erro lendo system.json: " + e
            }
            root._configBuf = ""
            root.loading = false
        }
    }

    Process {
        id: saveConfigProc
        property string jsonData: ""
        property bool showMessage: false
        command: []
        onExited: {
            if (showMessage)
                root.saveMessage = ""
        }
    }

    Timer {
        id: saveMessageTimer
        interval: 1800
        repeat: false
        onTriggered: root.saveMessage = ""
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
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.software_update.text.software_update"]) || "SOFTWARE UPDATE")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        Text {
            visible: root.errorMessage !== ""
            text: root.errorMessage
            color: root.errorMessage !== "" ? root.errorColor : root.successColor
            font.pixelSize: 12
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.bottomMargin: 18
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 24
            radius: 16
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder
            implicitHeight: heroCol.implicitHeight + 32

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 0
            }

            ColumnLayout {
                id: heroCol
                anchors.fill: parent
                anchors.margins: 18
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18

                    Rectangle {
                        implicitWidth: 92
                        implicitHeight: 92
                        radius: 24
                        color: Qt.rgba(1, 1, 1, 0.10)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.06)
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 14
                            source: "file://" + root.heroArtPath
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: root.updateName
                            color: root.textPrimary
                            font.pixelSize: 24
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: root.updateSize
                            color: root.textSecondary
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }

                        Text {
                            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.software_update.text.a_pagina_salva_as_preferaancias_de_update_agora"]) || "This page now saves update preferences and applies that behavior when the real updater is available.")
                            color: root.textSecondary
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }

                    RowLayout {
                        spacing: 8
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                        ActionButton {
                            label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.software_update.label.atualizar"]) || "Update")
                            primary: true
                        }

                        ActionButton {
                            label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.software_update.label.atualizar_a_noite"]) || "Update tonight")
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 28
            radius: 14
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder
            implicitHeight: updateCol.implicitHeight + 32

            ColumnLayout {
                id: updateCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 0

                SettingRow {
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.software_update.label.auto_updater"]) || "Auto updater")
                    sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.software_update.sublabel.salva_a_preferaancia_para_quando_o_updater_real"]) || "Saves the preference for when the real updater is connected.")
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder

                    ToggleSwitch {
                        checked: !!root.updateConfig.auto_updater
                        onToggled: root.mutateConfig(function(next) {
                            next.auto_updater = !next.auto_updater
                        }, true)
                    }
                }

                SettingRow {
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.software_update.label.release_channel"]) || "Release channel")
                    sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.software_update.sublabel.stable_prioriza_previsibilidade_alpha_recebe_nov"]) || "Stable prioritizes predictability; Alpha gets new features earlier.")
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder

                    SelectButton {
                        implicitWidth: 140
                        label: root.channelOptions[root.selectedChannel]
                        options: root.channelOptions
                        selectedIndex: root.selectedChannel
                        accent: root.accent
                        textPrimary: root.textPrimary
                        textSecondary: root.textSecondary
                        popupBg: root.popupBg
                        onSelected: index => {
                            root.selectedChannel = index
                            root.mutateConfig(function(next) {
                                next.channel = root.channelValues[index]
                            }, true)
                        }
                    }
                }

                SettingRow {
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.software_update.label.current_state"]) || "Current state")
                    sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.software_update.sublabel.sem_backend_conectado_no_momento_entao_nenhum_up"]) || "No backend is connected right now, so no update is actually downloaded or applied.")
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder
                    isLast: true

                    StatusBadge {
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.system.software_update.label.unavailable"]) || "Unavailable")
                        tone: Qt.rgba(root.warningColor.r, root.warningColor.g, root.warningColor.b, 0.28)
                    }
                }
            }
        }

    }
}
