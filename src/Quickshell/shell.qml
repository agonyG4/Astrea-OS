//@ pragma UseQApplication
//@ pragma IconTheme WhiteSur-dark
import Quickshell
import Quickshell.Io
import QtQuick
import "./bar"
import "./island"
import "./notifications"
import "./spotlight"
import "./alttab"

ShellRoot {
    id: root

    readonly property string desktopIconsConfigPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/Astrea/desktop-icons/config.json"
    property bool desktopIconsEnabled: false

    MusicMonitor {
        id: musicMonitor
    }

    Process {
        id: desktopIconsConfigProc
        command: [
            "python3",
            "-c",
            "import json,pathlib,sys; p=pathlib.Path(sys.argv[1]); p.parent.mkdir(parents=True, exist_ok=True); cfg={'enabled': True};\nif p.exists():\n    cfg.update(json.loads(p.read_text(encoding='utf-8') or '{}'))\nelse:\n    p.write_text(json.dumps(cfg, indent=4) + '\\n', encoding='utf-8')\nprint(json.dumps(cfg))",
            root.desktopIconsConfigPath
        ]
        running: true
        stdout: StdioCollector { id: desktopIconsConfigStdout }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.desktopIconsEnabled = false
                return
            }

            try {
                var cfg = JSON.parse(desktopIconsConfigStdout.text || "{}")
                root.desktopIconsEnabled = cfg.enabled !== false
            } catch (error) {
                root.desktopIconsEnabled = false
            }
        }
    }

    Loader {
        active: root.desktopIconsEnabled
        source: active ? "./desktop/DesktopIcons.qml" : ""
    }

    // Bar — one per screen
    Variants {
        model: Quickshell.screens
        delegate: Bar {
            required property var modelData
            screen: modelData
            sharedMusicState: musicMonitor
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Island {
            required property var modelData
            screen: modelData
            sharedMusicState: musicMonitor
        }
    }

    Spotlight {}

    AltTab {}

    Notifications {}
}
