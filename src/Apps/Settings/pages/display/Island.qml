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
    property color accent: Theme.accent
    property color textPrimary: Theme.textPrimary
    property color textSecondary: Theme.textSecondary
    property color cardBg: Theme.cardBg
    property color cardBorder: Theme.cardBorder
    property color popupBg: Theme.popupBg

    // ── State ─────────────────────────────────────────────────────────────
    property bool islandEnabled:     true
    property int selectedStyle:      1 // 0 = Notch, 1 = Bubble (default)
    property bool musicEnabled:      true
    property bool gamemodeEnabled:   true
    property bool alwaysOnTop:       true
    property bool restartShellPending: false
    property var islandConfig:       ({})

    readonly property var styleOptions: ["Notch", "Bubble"]

    // ── Configuration Setup ───────────────────────────────────────────────
    readonly property string configPath: Quickshell.env("HOME") + "/.local/state/Astrea/island/island.json"
    readonly property string legacyConfigPath: Quickshell.env("HOME") + "/.config/quickshell/island/config/island.json"
    readonly property string stateJsonScript: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Core/bridge/state_json.py"
    readonly property string defaultConfigJson: JSON.stringify({
        "enabled": true,
        "always_on_top": true,
        "music": true,
        "show_gamemode_notify": false,
        "style": "Notch"
    }, null, 4)

    Process {
        id: loadConfigProc
        command: ["python3", root.stateJsonScript, "read-or-init", root.configPath, root.defaultConfigJson, root.legacyConfigPath]
        property string outData: ""
        
        stdout: SplitParser {
            onRead: (l) => { loadConfigProc.outData += l }
        }
        
        onExited: {
            if (outData) {
                try {
                    let cfg = JSON.parse(outData)
                    islandConfig = cfg
                    
                    root.islandEnabled = cfg.enabled !== false
                    root.musicEnabled = !!cfg.music
                    root.gamemodeEnabled = !!cfg.show_gamemode_notify
                    root.alwaysOnTop = cfg.always_on_top !== false
                    if (cfg.style === "Notch") {
                        root.selectedStyle = 0
                    } else {
                        root.selectedStyle = 1
                    }
                } catch(e) {
                    console.log("Error parsing island.json")
                }
            }
        }
    }

    Process {
        id: saveConfigProc
        property string jsonData: ""
        function save() {
            let nCfg = Object.assign({}, root.islandConfig)
            nCfg.enabled = root.islandEnabled
            nCfg.music = root.musicEnabled
            nCfg.show_gamemode_notify = root.gamemodeEnabled
            nCfg.always_on_top = root.alwaysOnTop
            nCfg.style = root.styleOptions[root.selectedStyle]
            
            jsonData = JSON.stringify(nCfg, null, 4)
            
            command = ["python3", root.stateJsonScript, "write", root.configPath, jsonData]
            running = false
            running = true
        }

        onExited: {
            if (root.restartShellPending) {
                root.restartShellPending = false
                restartShellProc.restartShell()
            }
        }
    }

    Process {
        id: restartShellProc
        function restartShell() {
            command = ["bash", "-lc",
                "MAIN_ENTRY=$(quickshell list --all 2>/dev/null | awk '" +
                "/^Instance /{pid=\"\"; path=\"\"} " +
                "/^  Process ID: /{pid=$3} " +
                "/^  Config path: /{sub(/^  Config path: /, \"\"); path=$0} " +
                "/^$/{if (path ~ /\\/(\\.config\\/quickshell\\/shell\\.qml|\\.local\\/share\\/Astrea\\/Quickshell(\\/shell\\.qml)?)$/) {print pid \"\\t\" path; exit}} " +
                "END{if (path ~ /\\/(\\.config\\/quickshell\\/shell\\.qml|\\.local\\/share\\/Astrea\\/Quickshell(\\/shell\\.qml)?)$/) print pid \"\\t\" path}' );" +
                "MAIN_PID=${MAIN_ENTRY%%$'\\t'*}; " +
                "MAIN_PATH=${MAIN_ENTRY#*$'\\t'}; " +
                "if [ -z \"$MAIN_PATH\" ] || [ \"$MAIN_PATH\" = \"$MAIN_ENTRY\" ]; then " +
                "  if [ -f \"$HOME/.config/quickshell/shell.qml\" ]; then CONFIG_TARGET=\"$HOME/.config/quickshell\"; " +
                "  else CONFIG_TARGET=\"$HOME/.local/share/Astrea/Quickshell\"; fi; " +
                "else CONFIG_TARGET=\"$MAIN_PATH\"; fi; " +
                "if [ -n \"$MAIN_PID\" ] && [ \"$MAIN_PID\" != \"$MAIN_ENTRY\" ]; then " +
                "  setsid -f bash -lc 'sleep 0.3; exec quickshell -d -p \"$1\" >/tmp/astrea-quickshell-restart.log 2>&1' _ \"$CONFIG_TARGET\"; " +
                "  kill \"$MAIN_PID\" 2>/dev/null || true; " +
                "else " +
                "  setsid -f quickshell -d -p \"$CONFIG_TARGET\" >/tmp/astrea-quickshell-restart.log 2>&1; " +
                "fi"]
            running = false
            running = true
        }
    }

    Component.onCompleted: {
        loadConfigProc.running = true
    }

    // ── Layout ────────────────────────────────────────────────────────────
    ScrollView {
        anchors.fill: parent
        anchors.margins: 28
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 0

            SectionHeader { 
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.island.text.system"]) || "SYSTEM")
                Layout.bottomMargin: 12 
                textSecondary: root.textSecondary
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 28
                radius: 12
                color: root.cardBg
                border.width: 1
                border.color: root.cardBorder
                implicitHeight: sysCol.implicitHeight

                ColumnLayout {
                    id: sysCol
                    anchors { left: parent.left; right: parent.right }
                    spacing: 0

                    SettingRow {
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.island.label.enable_island"]) || "Enable Island")
                        sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.island.sublabel.start_with_system_and_display_the_island"]) || "Start with system and display the Island")
                        textPrimary: root.textPrimary; textSecondary: root.textSecondary; cardBorder: root.cardBorder
                        ToggleSwitch {
                            checked: root.islandEnabled
                            onToggled: { 
                                root.islandEnabled = !root.islandEnabled
                                saveConfigProc.save()
                            }
                        }
                    }

                    SettingRow {
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.island.label.always_on_top"]) || "Always on Top")
                        sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.island.sublabel.keep_the_island_above_all_windows"]) || "Keep the Island above all windows")
                        textPrimary: root.textPrimary; textSecondary: root.textSecondary; cardBorder: root.cardBorder
                        isLast: true
                        ToggleSwitch {
                            checked: root.alwaysOnTop
                            onToggled: { 
                                root.alwaysOnTop = !root.alwaysOnTop
                                root.restartShellPending = true
                                saveConfigProc.save()
                            }
                        }
                    }
                }
            }

            SectionHeader { 
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.island.text.island_look_feel"]) || "ISLAND LOOK & FEEL")
                Layout.bottomMargin: 12 
                textSecondary: root.textSecondary
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 28
                radius: 12
                color: root.cardBg
                border.width: 1
                border.color: root.cardBorder
                implicitHeight: islandCol.implicitHeight

                ColumnLayout {
                    id: islandCol
                    anchors { left: parent.left; right: parent.right }
                    spacing: 0

                    SettingRow {
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.island.label.style"]) || "Style")
                        sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.island.sublabel.overall_visual_shape_of_the_island"]) || "Overall visual shape of the Island")
                        textPrimary: root.textPrimary; textSecondary: root.textSecondary; cardBorder: root.cardBorder
                        isLast: true
                        SelectButton {
                            implicitWidth: 140
                            label: root.styleOptions[root.selectedStyle]
                            options: root.styleOptions
                            selectedIndex: root.selectedStyle
                            onSelected: (i) => {
                                root.selectedStyle = i
                                saveConfigProc.save()
                            }
                            accent: root.accent; textPrimary: root.textPrimary; textSecondary: root.textSecondary; popupBg: root.popupBg
                        }
                    }
                }
            }
            
            SectionHeader { 
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.island.text.features"]) || "FEATURES")
                Layout.bottomMargin: 12 
                textSecondary: root.textSecondary
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 28
                radius: 12
                color: root.cardBg
                border.width: 1
                border.color: root.cardBorder
                implicitHeight: featCol.implicitHeight

                ColumnLayout {
                    id: featCol
                    anchors { left: parent.left; right: parent.right }
                    spacing: 0

                    SettingRow {
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.island.label.music"]) || "Music")
                        sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.island.sublabel.display_now_playing_information"]) || "Display now playing information")
                        textPrimary: root.textPrimary; textSecondary: root.textSecondary; cardBorder: root.cardBorder
                        ToggleSwitch {
                            checked: root.musicEnabled
                            onToggled: { 
                                root.musicEnabled = !root.musicEnabled
                                saveConfigProc.save()
                            }
                        }
                    }

                    SettingRow {
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.island.label.gamemode_notify"]) || "Gamemode Notify")
                        sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.island.sublabel.show_alerts_when_entering_or_exiting_game_mode"]) || "Show alerts when entering or exiting game mode")
                        textPrimary: root.textPrimary; textSecondary: root.textSecondary; cardBorder: root.cardBorder
                        isLast: true
                        ToggleSwitch {
                            checked: root.gamemodeEnabled
                            onToggled: { 
                                root.gamemodeEnabled = !root.gamemodeEnabled
                                saveConfigProc.save()
                            }
                        }
                    }
                }
            }
        }
    }
}
