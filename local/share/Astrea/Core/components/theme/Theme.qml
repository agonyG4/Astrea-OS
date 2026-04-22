pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: theme
    visible: false
    width: 0
    height: 0

    readonly property string configPath: (Quickshell.env("HOME") || "") + "/.config/AstreaOS/ui/theme.json"
    readonly property string colorSchemeApplyPath: (Quickshell.env("HOME") || "") + "/.local/share/Astrea/System/services/theme/apply_color_scheme.sh"
    readonly property string decorationApplyPath: (Quickshell.env("HOME") || "") + "/.local/share/Astrea/System/services/theme/apply_decoration_style.sh"
    property bool loaded: false

    // ── Persisted UI state ───────────────────────────────────────────────
    property int themeMode: 0
    property int shellStyle: 0
    property int iconStyle: 0
    property string iconTheme: "dark"
    property string accentHex: "#0a84ff"
    property int persistedShellStyle: 0

    function applyConfig(cfg) {
        if (!cfg)
            return

        var nextThemeMode = cfg.theme_mode === 1 ? 1 : 0
        if (typeof cfg.theme === "string")
            nextThemeMode = cfg.theme.toLowerCase() === "light" ? 1 : 0
        theme.themeMode = nextThemeMode
        var nextShellStyle = typeof cfg.shell_style === "number" ? cfg.shell_style : 1
        if (nextShellStyle < 0 || nextShellStyle > 2)
            nextShellStyle = 1
        theme.shellStyle = nextShellStyle
        theme.persistedShellStyle = nextShellStyle
        theme.iconStyle = typeof cfg.icon_style === "number" ? cfg.icon_style : 0
        theme.iconTheme = typeof cfg.icon_theme === "string" ? cfg.icon_theme : "dark"
        theme.accentHex = typeof cfg.accent === "string" && cfg.accent !== ""
            ? cfg.accent
            : "#0a84ff"
        theme.loaded = true
    }

    function save() {
        if (!loaded)
            return
        saveThemeProc.save()
    }

    Component.onCompleted: loadThemeProc.running = true

    // ── Icon style ─────────────────────────────────────────────────────────
    // 0 = clear (tinted), 1 = colored (native SVG color)
    // ── Icon theme ─────────────────────────────────────────────────────────
    // "" = default, "dark" = dark theme icons, "light" = light theme icons
    // ── Typography ─────────────────────────────────────────────────────────
    readonly property string fontFamily:   "Inter"
    readonly property string monoFontFamily: "JetBrains Mono"
    
    readonly property int fontSizeHero:    20
    readonly property int fontSizeHeader:  24
    readonly property int fontSizeIconLarge: 22
    readonly property int fontSizeAvatar:  20
    readonly property int fontSizeSubtitle:16
    readonly property int fontSizeTitle:   15
    readonly property int fontSizeLarge:   13
    readonly property int fontSizeNormal:  12
    readonly property int fontSizeSmall:   11
    readonly property int fontSizeTiny:    10
    readonly property int fontSizeMicro:   9

    readonly property int fontWeightLight:    Font.Light
    readonly property int fontWeightNormal:   Font.Normal
    readonly property int fontWeightMedium:   Font.Medium
    readonly property int fontWeightDemiBold: Font.Medium
    readonly property int fontWeightBold:     Font.Bold

    readonly property real trackingHeader:    0

    // ── Theme ─────────────────────────────────────────────────────────────
    readonly property color accent:        accentHex
    readonly property color textPrimary:   themeMode === 1 ? "#111111" : "#ffffff"
    readonly property color textSecondary: themeMode === 1 ? "#5f6368" : "#98989f"
    readonly property color cardBg: {
        if (shellStyle === 0 || shellStyle === 2)
            return themeMode === 1 ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.035)
        return themeMode === 1 ? Qt.rgba(0, 0, 0, 0.035) : Qt.rgba(1, 1, 1, 0.05)
    }
    readonly property color cardBorder: {
        if (shellStyle === 0 || shellStyle === 2)
            return themeMode === 1 ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.06)
        return themeMode === 1 ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.08)
    }
    readonly property color popupBg: {
        if (shellStyle === 0 || shellStyle === 2)
            return themeMode === 1 ? Qt.rgba(0.98, 0.98, 0.99, 0.92) : Qt.rgba(0.11, 0.11, 0.12, 0.92)
        return themeMode === 1 ? Qt.rgba(0.98, 0.98, 0.99, 1) : Qt.rgba(0.11, 0.11, 0.12, 1)
    }
    readonly property color windowBackground: {
        if (shellStyle === 0 || shellStyle === 2)
            return themeMode === 1 ? Qt.rgba(0.97, 0.97, 0.99, 0.24) : Qt.rgba(0.11, 0.11, 0.12, 0.24)
        return themeMode === 1 ? Qt.rgba(0.97, 0.97, 0.99, 1.0) : Qt.rgba(0.11, 0.11, 0.12, 1.0)
    }
    readonly property color windowBorder: {
        if (shellStyle === 0 || shellStyle === 2)
            return themeMode === 1 ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.06)
        return themeMode === 1 ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.08)
    }
    readonly property color windowWash: {
        if (shellStyle === 0 || shellStyle === 2)
            return themeMode === 1 ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.02)
        return themeMode === 1 ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.02)
    }
    readonly property color errorColor:    "#ff453a"
    readonly property color warningColor:  "#ff9f0a"
    readonly property color successColor:  "#30d158"

    Process {
        id: loadThemeProc
        command: ["bash", "-c",
            "FILE=\"$1\";" +
            "mkdir -p \"$(dirname \"$FILE\")\";" +
            "if [ ! -f \"$FILE\" ]; then " +
            "  printf '%s\n' '{' " +
            "    '  \"theme\": \"dark\",' " +
            "    '  \"theme_mode\": 0,' " +
            "    '  \"shell_style\": 0,' " +
            "    '  \"accent\": \"#0a84ff\",' " +
            "    '  \"icon_style\": 0,' " +
            "    '  \"icon_theme\": \"dark\"' " +
            "  '}' > \"$FILE\"; " +
            "fi; " +
            "if command -v jq >/dev/null 2>&1; then " +
            "  jq -c . \"$FILE\" 2>/dev/null; " +
            "else " +
            "  python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))' \"$FILE\" 2>/dev/null; " +
            "fi",
            "--", theme.configPath]
        property string outData: ""

        stdout: SplitParser {
            onRead: data => { loadThemeProc.outData += data }
        }

        onExited: {
            if (!outData) {
                theme.applyConfig({})
                theme.save()
                return
            }

            try {
                theme.applyConfig(JSON.parse(outData))
            } catch (e) {
                console.log("Error parsing theme.json:", e)
                theme.applyConfig({})
                theme.save()
            }
        }
    }

    Process {
        id: saveThemeProc
        property string jsonData: ""

        function save() {
            var shouldApplyDecoration = theme.shellStyle !== theme.persistedShellStyle
            var nextShellStyle = theme.shellStyle

            jsonData = JSON.stringify({
                theme: theme.themeMode === 1 ? "light" : "dark",
                theme_mode: theme.themeMode,
                shell_style: theme.shellStyle,
                accent: theme.accentHex,
                icon_style: theme.iconStyle,
                icon_theme: theme.iconTheme
            }, null, 4)

            command = ["bash", "-c",
                "mkdir -p \"$(dirname \"$1\")\"; cat <<'EOF' > \"$1\"\n" + jsonData + "\nEOF\n" +
                "if [ -x \"$3\" ]; then \"$3\"; fi\n" +
                "if [ \"$5\" = \"1\" ] && [ -x \"$4\" ]; then \"$4\" \"$2\"; fi\n",
                "--", theme.configPath, String(nextShellStyle), theme.colorSchemeApplyPath, theme.decorationApplyPath, shouldApplyDecoration ? "1" : "0"]
            theme.persistedShellStyle = nextShellStyle
            running = false
            running = true
        }
    }
}
