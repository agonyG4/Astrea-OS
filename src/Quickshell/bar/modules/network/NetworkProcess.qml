import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    readonly property string statusPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/Astrea/status/network.json"
    property bool   connected: false
    property string type:      "none"
    property string ssid:      ""
    property string download:  "0 B/s"
    property string upload:    "0 B/s"

    function refresh() {
        statusRefreshProc.running = false
        statusRefreshProc.running = true
    }

    function applyStatus(text) {
        try {
            var payload = JSON.parse(text || "{}")
            root.connected = payload.connected === true
            root.type = payload.type || "none"
            root.ssid = payload.ssid || ""
            root.download = payload.download || "0 B/s"
            root.upload = payload.upload || "0 B/s"
        } catch (error) {
        }
    }

    property var statusFile: FileView {
        path: root.statusPath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyStatus(text())
    }

    property var statusRefreshProc: Process {
        command: ["systemctl", "--user", "kill", "-s", "SIGUSR1", "astrea-status.service"]
        running: false
        onExited: exitCode => {
            if (exitCode === 0)
                statusFile.reload()
            else {
                statusStartProc.running = false
                statusStartProc.running = true
            }
        }
    }

    property var statusStartProc: Process {
        command: ["systemctl", "--user", "start", "astrea-status.service"]
        running: false
        onExited: statusFile.reload()
    }

    Component.onCompleted: root.refresh()
}
