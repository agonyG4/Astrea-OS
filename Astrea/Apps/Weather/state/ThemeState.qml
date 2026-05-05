import Quickshell.Io
import QtQuick 2.15
import ".."

Item {
    id: root
    visible: false

    property string themeFile: "/home/agony/.config/AstreaOS/ui/theme.json"
    property string themeSignalFile: "/home/agony/.config/AstreaOS/state/theme.changed"
    property bool isDark: false
    property string lastPayload: ""

    property color bgColor: isDark ? "#1A1A1A" : Theme.textPrimary
    property color surfaceColor: isDark ? "#232323" : "#FFFFFF"
    property color elevatedSurfaceColor: isDark ? "#2A2A2A" : "#F2F2F7"
    property color primaryColor: isDark ? Theme.textPrimary : Theme.bg
    property color midColor: isDark ? "#D1D1D6" : "#2C2C2E"
    property color secondaryColor: isDark ? "#A1A1A6" : "#6E6E73"
    property color tertiaryColor: isDark ? "#7C7C80" : "#8E8E93"
    property color borderColor: isDark ? "#343434" : "#D9D9DE"
    property color subtleBorderColor: isDark ? "#2A2A2A" : "#E5E5EA"
    property color selectedColor: isDark ? "#2F3E55" : "#DCEBFF"
    property color accentColor: isDark ? "#4D8DFF" : Theme.accent
    property color errorColor: isDark ? "#FF453A" : "#FF3B30"

    property var colors: ({})

    function refreshColors() {
        colors = {
            bg: bgColor,
            surface: surfaceColor,
            elevatedSurface: elevatedSurfaceColor,
            primary: primaryColor,
            mid: midColor,
            secondary: secondaryColor,
            tertiary: tertiaryColor,
            border: borderColor,
            subtleBorder: subtleBorderColor,
            selected: selectedColor,
            accent: accentColor,
            error: errorColor
        }
    }

    function applyThemePayload(data) {
        try {
            var config = JSON.parse(data.trim())
            if (typeof config.theme === "string")
                root.isDark = config.theme.toLowerCase() !== "light"
            else
                root.isDark = config.theme_mode !== 1
        } catch (e) {
            var value = data.trim().toLowerCase()
            root.isDark = value !== "light" && value !== "1"
        }
        refreshColors()
    }

    function refreshTheme() {
        if (themeReadProc.running)
            return
        themeReadProc.running = true
    }

    Component.onCompleted: {
        refreshColors()
        refreshTheme()
    }
    onIsDarkChanged: refreshColors()

    Process {
        id: themeReadProc
        command: ["bash", "-c",
            "FILE=\"$1\"; SIGNAL=\"$2\";" +
            "mkdir -p \"$(dirname \"$FILE\")\";" +
            "mkdir -p \"$(dirname \"$SIGNAL\")\";" +
            "if [ ! -f \"$FILE\" ]; then " +
            "  printf '%s\n' '{' '  \"theme\": \"dark\",' '  \"theme_mode\": 0' '}' > \"$FILE\"; " +
            "fi; " +
            "touch \"$SIGNAL\"; " +
            "if command -v jq >/dev/null 2>&1; then jq -c . \"$FILE\" 2>/dev/null; else python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))' \"$FILE\" 2>/dev/null; fi",
            "--", root.themeFile, root.themeSignalFile]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var payload = this.text.trim()
                if (payload !== "" && payload !== root.lastPayload) {
                    root.lastPayload = payload
                    root.applyThemePayload(payload)
                }
            }
        }
    }

    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: root.refreshTheme()
    }
}
