import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    readonly property string configPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/Astrea/desktop-icons/config.json"
    property bool enabled: false
    property bool gameModeActive: false

    Process {
        id: configProcess
        command: [
            "python3",
            "-c",
            "import json,pathlib,sys; p=pathlib.Path(sys.argv[1]); p.parent.mkdir(parents=True, exist_ok=True); cfg={'enabled': True};\nif p.exists():\n    cfg.update(json.loads(p.read_text(encoding='utf-8') or '{}'))\nelse:\n    p.write_text(json.dumps(cfg, indent=4) + '\\n', encoding='utf-8')\nprint(json.dumps(cfg))",
            root.configPath
        ]
        running: true
        stdout: StdioCollector { id: configStdout }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.enabled = false
                return
            }

            try {
                var cfg = JSON.parse(configStdout.text || "{}")
                root.enabled = cfg.enabled !== false
            } catch (error) {
                root.enabled = false
            }
        }
    }

    Loader {
        active: root.enabled
        source: active ? Qt.resolvedUrl("DesktopIcons.qml") : ""
        onLoaded: if (item) item.performancePaused = Qt.binding(function() { return root.gameModeActive })
    }
}
