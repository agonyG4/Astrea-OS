import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root
    visible: false
    width: 0
    height: 0

    readonly property string astreaRoot: (Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")) + ""
    readonly property string configPath: (Quickshell.env("HOME") || "") + "/.config/AstreaOS/ui/components.json"
    readonly property string stateJsonScript: astreaRoot + "/Core/bridge/state_json.py"
    readonly property var defaults: ({
        desktop: true,
        topbar: true,
        island: true,
        spotlight: true,
        alttab: true,
        notifications: true
    })
    readonly property string defaultConfigJson: JSON.stringify(defaults, null, 4)

    property bool desktop: true
    property bool topbar: true
    property bool island: true
    property bool spotlight: true
    property bool alttab: true
    property bool notifications: true

    function isEnabled(key) {
        return root[key] !== false
    }

    function applyConfigText(text) {
        try {
            const cfg = Object.assign({}, root.defaults, JSON.parse(text || "{}"))
            root.desktop = cfg.desktop !== false
            root.topbar = cfg.topbar !== false
            root.island = cfg.island !== false
            root.spotlight = cfg.spotlight !== false
            root.alttab = cfg.alttab !== false
            root.notifications = cfg.notifications !== false
        } catch (error) {
            root.desktop = true
            root.topbar = true
            root.island = true
            root.spotlight = true
            root.alttab = true
            root.notifications = true
        }
    }

    Process {
        id: ensureConfig
        command: ["python3", root.stateJsonScript, "read-or-init", root.configPath, root.defaultConfigJson]
        running: true
        stdout: SplitParser {
            onRead: data => root.applyConfigText(data)
        }
        onExited: componentFile.reload()
    }

    FileView {
        id: componentFile
        path: root.configPath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyConfigText(text())
    }
}
