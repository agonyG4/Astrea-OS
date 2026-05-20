import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../AstreaComponents"
import "../../AstreaI18n" as AstreaI18n

ScrollPage {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
    readonly property string configPath: stateHome + "/Astrea/desktop-icons/config.json"
    readonly property string desktopIconsStatePath: stateHome + "/Astrea/desktop-icons/state.json"
    readonly property string appIndexScript: home + "/.local/share/Astrea/Quickshell/desktop/app_index.py"
    readonly property string desktopPath: home + "/Área de trabalho"

    property bool desktopIconsEnabled: true
    property bool desktopIconsHidden: false
    property string iconPreset: "medium"
    property string sortMode: "name"
    property bool configLoaded: false
    property bool stateLoaded: false
    property string statusText: ""
    property string configBuffer: ""
    property string stateBuffer: ""
    readonly property var iconPresetOptions: ["Small", "Medium", "Large"]
    readonly property var sortModeOptions: ["Name", "Type", "Path"]

    function indexForValue(options, value) {
        const needle = String(value || "").toLowerCase()
        for (let i = 0; i < options.length; i++) {
            if (String(options[i]).toLowerCase() === needle)
                return i
        }
        return 0
    }

    function presetSubtitle() {
        if (iconPreset === "small")
            return "Compact grid with smaller app icons"
        if (iconPreset === "large")
            return "Larger desktop icons and wider spacing"
        return "Balanced desktop icon size"
    }

    function sortSubtitle() {
        if (sortMode === "kind")
            return "Groups shortcuts by app type when available"
        if (sortMode === "path")
            return "Orders shortcuts by desktop file path"
        return "Alphabetical by app name"
    }

    function saveConfig(restartShell) {
        const payload = JSON.stringify({ "enabled": root.desktopIconsEnabled }, null, 4)
        saveConfigProc.command = [
            "python3",
            root.appIndexScript,
            "--save-config",
            root.configPath,
            payload
        ]
        saveConfigProc.restartShell = restartShell
        saveConfigProc.running = false
        saveConfigProc.running = true
    }

    function saveDesktopState(restartShell, clearPositions) {
        saveStateProc.restartShell = restartShell
        saveStateProc.command = [
            "python3",
            root.appIndexScript,
            "--update-layout-state",
            root.desktopIconsStatePath,
            root.sortMode,
            root.iconPreset,
            root.desktopIconsHidden ? "1" : "0",
            clearPositions ? "1" : "0"
        ]
        saveStateProc.running = false
        saveStateProc.running = true
    }

    function reloadDesktopApps() {
        refreshAppsProc.running = false
        refreshAppsProc.running = true
    }

    Component.onCompleted: {
        loadConfigProc.running = true
        loadStateProc.running = true
    }

    Process {
        id: loadConfigProc
        command: [
            "python3",
            root.appIndexScript,
            "--load-config",
            root.configPath
        ]
        stdout: SplitParser {
            onRead: line => root.configBuffer += line
        }
        onExited: {
            try {
                const cfg = JSON.parse(root.configBuffer || "{}")
                root.desktopIconsEnabled = cfg.enabled !== false
            } catch (error) {
                root.statusText = "Could not read Desktop Icons settings"
            }
            root.configBuffer = ""
            root.configLoaded = true
        }
    }

    Process {
        id: saveConfigProc
        property bool restartShell: false
        command: []
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.statusText = "Could not save Desktop Icons settings"
                return
            }

            root.statusText = saveConfigProc.restartShell ? "Restarting shell..." : "Saved"
            if (saveConfigProc.restartShell)
                restartShellProc.restartShell()
        }
    }

    Process {
        id: loadStateProc
        command: [
            "python3",
            root.appIndexScript,
            "--load-layout-state",
            root.desktopIconsStatePath
        ]
        stdout: SplitParser {
            onRead: line => root.stateBuffer += line
        }
        onExited: {
            try {
                const state = JSON.parse(root.stateBuffer || "{}")
                root.desktopIconsHidden = state.iconsHidden === true
                root.iconPreset = ["small", "medium", "large"].indexOf(state.iconPreset) >= 0 ? state.iconPreset : "medium"
                root.sortMode = ["name", "kind", "path"].indexOf(state.sortMode) >= 0 ? state.sortMode : "name"
            } catch (error) {
                root.statusText = "Could not read Desktop layout settings"
            }
            root.stateBuffer = ""
            root.stateLoaded = true
        }
    }

    Process {
        id: saveStateProc
        property bool restartShell: true
        command: []
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.statusText = "Could not save Desktop layout settings"
                return
            }
            root.statusText = saveStateProc.restartShell ? "Applying desktop layout..." : "Saved"
            if (saveStateProc.restartShell && root.desktopIconsEnabled)
                restartShellProc.restartShell()
        }
    }

    Process {
        id: refreshAppsProc
        command: ["python3", root.appIndexScript, "--json", "--write"]
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.statusText = "Could not refresh Desktop app list"
                return
            }
            root.statusText = "Desktop app list refreshed"
            if (root.desktopIconsEnabled)
                restartShellProc.restartShell()
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
                "/^$/{if (path ~ /\\/\\.local\\/share\\/Astrea\\/Quickshell(\\/shell\\.qml)?$/) {print pid \"\\t\" path; exit}} " +
                "END{if (path ~ /\\/\\.local\\/share\\/Astrea\\/Quickshell(\\/shell\\.qml)?$/) print pid \"\\t\" path}' );" +
                "MAIN_PID=${MAIN_ENTRY%%$'\\t'*}; " +
                "MAIN_PATH=${MAIN_ENTRY#*$'\\t'}; " +
                "CONFIG_TARGET=${MAIN_PATH:-$HOME/.local/share/Astrea/Quickshell}; " +
                "if [ -n \"$MAIN_PID\" ] && [ \"$MAIN_PID\" != \"$MAIN_ENTRY\" ]; then " +
                "  setsid -f bash -lc 'sleep 0.3; exec quickshell -d -p \"$1\" >/tmp/astrea-quickshell-restart.log 2>&1' _ \"$CONFIG_TARGET\"; " +
                "  kill \"$MAIN_PID\" 2>/dev/null || true; " +
                "else " +
                "  setsid -f quickshell -d -p \"$CONFIG_TARGET\" >/tmp/astrea-quickshell-restart.log 2>&1; " +
                "fi"]
            running = false
            running = true
        }
        onExited: root.statusText = "Shell restarted"
    }

    ColumnLayout {
        width: parent.width
        spacing: 0

        SectionHeader {
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.desktop.text.desktop"]) || "DESKTOP")
            Layout.bottomMargin: 12
            textSecondary: Theme.textSecondary
        }

        FormCard {
            Layout.bottomMargin: 18

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.desktop.label.desktop_icons"]) || "Desktop Icons")
                sublabel: root.desktopIconsEnabled ? "Loaded by the main shell" : "Not loaded by the main shell"
                textPrimary: Theme.textPrimary
                textSecondary: Theme.textSecondary
                cardBorder: Theme.cardBorder
                isLast: false

                ToggleSwitch {
                    checked: root.desktopIconsEnabled
                    enabled: root.configLoaded
                    onToggled: {
                        root.desktopIconsEnabled = !root.desktopIconsEnabled
                        root.saveConfig(true)
                    }
                }
            }

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.desktop.label.show_icons"]) || "Show Icons")
                sublabel: root.desktopIconsHidden ? "Desktop shortcuts are hidden" : "Desktop shortcuts are visible"
                textPrimary: Theme.textPrimary
                textSecondary: Theme.textSecondary
                cardBorder: Theme.cardBorder
                visible: root.desktopIconsEnabled

                ToggleSwitch {
                    checked: !root.desktopIconsHidden
                    enabled: root.stateLoaded
                    onToggled: {
                        root.desktopIconsHidden = !root.desktopIconsHidden
                        root.saveDesktopState(true, false)
                    }
                }
            }

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.desktop.label.icon_size"]) || "Icon Size")
                sublabel: root.presetSubtitle()
                textPrimary: Theme.textPrimary
                textSecondary: Theme.textSecondary
                cardBorder: Theme.cardBorder
                visible: root.desktopIconsEnabled && !root.desktopIconsHidden

                SelectButton {
                    implicitWidth: 150
                    label: root.iconPresetOptions[root.indexForValue(root.iconPresetOptions, root.iconPreset)]
                    options: root.iconPresetOptions
                    selectedIndex: root.indexForValue(root.iconPresetOptions, root.iconPreset)
                    onSelected: index => {
                        root.iconPreset = String(root.iconPresetOptions[index]).toLowerCase()
                        root.saveDesktopState(true, true)
                    }
                }
            }

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.desktop.label.sort_icons"]) || "Sort Icons")
                sublabel: root.sortSubtitle()
                textPrimary: Theme.textPrimary
                textSecondary: Theme.textSecondary
                cardBorder: Theme.cardBorder
                visible: root.desktopIconsEnabled && !root.desktopIconsHidden

                SelectButton {
                    implicitWidth: 150
                    label: root.sortMode === "kind" ? "Type" : (root.sortMode === "path" ? "Path" : "Name")
                    options: root.sortModeOptions
                    selectedIndex: root.sortMode === "kind" ? 1 : (root.sortMode === "path" ? 2 : 0)
                    onSelected: index => {
                        root.sortMode = index === 1 ? "kind" : (index === 2 ? "path" : "name")
                        root.saveDesktopState(true, true)
                    }
                }
            }

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.desktop.label.reorganize_grid"]) || "Reorganize Grid")
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.desktop.sublabel.clears_manual_desktop_icon_positions"]) || "Clears manual desktop icon positions")
                textPrimary: Theme.textPrimary
                textSecondary: Theme.textSecondary
                cardBorder: Theme.cardBorder
                visible: root.desktopIconsEnabled && !root.desktopIconsHidden
                isLast: false

                SelectButton {
                    implicitWidth: 150
                    isButton: true
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.desktop.label.reorganize"]) || "Reorganize")
                    onSelected: {
                        root.saveDesktopState(true, true)
                    }
                }
            }

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.desktop.label.refresh_apps"]) || "Refresh Apps")
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.desktop.sublabel.rebuilds_the_desktop_shortcut_index"]) || "Rebuilds the desktop shortcut index")
                textPrimary: Theme.textPrimary
                textSecondary: Theme.textSecondary
                cardBorder: Theme.cardBorder
                isLast: true

                SelectButton {
                    implicitWidth: 150
                    isButton: true
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.desktop.label.refresh"]) || "Refresh")
                    onSelected: root.reloadDesktopApps()
                }
            }
        }

        Text {
            visible: root.statusText !== ""
            text: root.statusText
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        Text {
            Layout.topMargin: 18
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.display.desktop.text.icons_are_read_from"]) || "Icons are read from ") + root.desktopPath
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }
}
