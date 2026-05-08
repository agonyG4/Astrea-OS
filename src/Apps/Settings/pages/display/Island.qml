import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../AstreaComponents"

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
    Process {
        id: loadConfigProc
        command: ["bash", "-c",
            "FILE=\"$1\"; LEGACY=\"$2\";" +
            "mkdir -p \"$(dirname \"$FILE\")\";" +
            "if [ ! -f \"$FILE\" ]; then " +
            "  if [ -f \"$LEGACY\" ]; then cp \"$LEGACY\" \"$FILE\"; " +
            "  else printf '%s\n' '{' '    \"enabled\": true,' '    \"always_on_top\": true,' '    \"music\": true,' '    \"show_gamemode_notify\": false,' '    \"style\": \"Notch\"' '}' > \"$FILE\"; " +
            "  fi; " +
            "fi;" +
            "cat \"$FILE\"",
            "--", root.configPath, root.legacyConfigPath]
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
            
            command = ["bash", "-c",
                "mkdir -p \"$(dirname \"$1\")\"; cat <<'EOF' > \"$1\"\n" + jsonData + "\nEOF\n",
                "--", root.configPath]
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
                text: "SYSTEM"
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
                        label: "Enable Island"
                        sublabel: "Start with system and display the Island"
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
                        label: "Always on Top"
                        sublabel: "Keep the Island above all windows"
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
                text: "ISLAND LOOK & FEEL"
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
                        label: "Style"
                        sublabel: "Overall visual shape of the Island"
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
                text: "FEATURES"
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
                        label: "Music"
                        sublabel: "Display now playing information"
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
                        label: "Gamemode Notify"
                        sublabel: "Show alerts when entering or exiting game mode"
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
