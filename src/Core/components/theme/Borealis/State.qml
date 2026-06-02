pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: state
    visible: false
    width: 0
    height: 0

    readonly property string configPath: (Quickshell.env("HOME") || "") + "/.config/AstreaOS/ui/theme.json"
    readonly property string colorSchemeApplyPath: (Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")) + "/System/services/theme/apply_color_scheme.sh"
    readonly property string decorationApplyPath: (Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")) + "/System/services/theme/apply_decoration_style.sh"
    property bool loaded: false

    property int themeMode: 0
    property int shellStyle: 0
    property int iconStyle: 0
    property string iconTheme: "dark"
    property string accentHex: "#0a84ff"
    property int audioOsdStyle: 0
    property int persistedShellStyle: 0

    function applyConfig(cfg) {
        if (!cfg)
            return

        var nextThemeMode = cfg.theme_mode === 1 ? 1 : 0
        if (typeof cfg.theme === "string")
            nextThemeMode = cfg.theme.toLowerCase() === "light" ? 1 : 0
        state.themeMode = nextThemeMode

        var nextShellStyle = typeof cfg.shell_style === "number" ? cfg.shell_style : 1
        if (nextShellStyle < 0 || nextShellStyle > 2)
            nextShellStyle = 1
        state.shellStyle = nextShellStyle
        state.persistedShellStyle = nextShellStyle

        state.iconStyle = typeof cfg.icon_style === "number" ? cfg.icon_style : 0
        state.iconTheme = typeof cfg.icon_theme === "string" ? cfg.icon_theme : "dark"
        state.accentHex = typeof cfg.accent === "string" && cfg.accent !== ""
            ? cfg.accent
            : "#0a84ff"

        var nextAudioOsdStyle = typeof cfg.audio_osd_style === "number" ? cfg.audio_osd_style : 0
        if (nextAudioOsdStyle < 0 || nextAudioOsdStyle > 1)
            nextAudioOsdStyle = 0
        state.audioOsdStyle = nextAudioOsdStyle
        state.loaded = true
    }

    function save() {
        if (!loaded)
            return
        saveThemeProc.save()
    }

    Component.onCompleted: loadThemeProc.running = true

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
            "    '  \"icon_theme\": \"dark\",' " +
            "    '  \"audio_osd_style\": 0' " +
            "  '}' > \"$FILE\"; " +
            "fi; " +
            "if command -v jq >/dev/null 2>&1; then " +
            "  jq -c . \"$FILE\" 2>/dev/null; " +
            "else " +
            "  python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))' \"$FILE\" 2>/dev/null; " +
            "fi",
            "--", state.configPath]
        property string outData: ""

        stdout: SplitParser {
            onRead: data => { loadThemeProc.outData += data }
        }

        onExited: {
            if (!outData) {
                state.applyConfig({})
                state.save()
                return
            }

            try {
                state.applyConfig(JSON.parse(outData))
            } catch (e) {
                console.log("Error parsing theme.json:", e)
                state.applyConfig({})
                state.save()
            }
        }
    }

    Process {
        id: saveThemeProc
        property string jsonData: ""

        function save() {
            var shouldApplyDecoration = state.shellStyle !== state.persistedShellStyle
            var nextShellStyle = state.shellStyle

            jsonData = JSON.stringify({
                theme: state.themeMode === 1 ? "light" : "dark",
                theme_mode: state.themeMode,
                shell_style: state.shellStyle,
                accent: state.accentHex,
                icon_style: state.iconStyle,
                icon_theme: state.iconTheme,
                audio_osd_style: state.audioOsdStyle
            }, null, 4)

            command = ["bash", "-c",
                "mkdir -p \"$(dirname \"$1\")\"; cat <<'EOF' > \"$1\"\n" + jsonData + "\nEOF\n" +
                "if [ -x \"$3\" ]; then \"$3\"; fi\n" +
                "if [ \"$5\" = \"1\" ] && [ -x \"$4\" ]; then \"$4\" \"$2\"; fi\n",
                "--", state.configPath, String(nextShellStyle), state.colorSchemeApplyPath, state.decorationApplyPath, shouldApplyDecoration ? "1" : "0"]
            state.persistedShellStyle = nextShellStyle
            running = false
            running = true
        }
    }
}
