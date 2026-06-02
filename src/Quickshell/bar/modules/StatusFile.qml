import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property string statusPath: ""
    property bool performancePaused: false
    property bool startOnRefreshFailure: true
    property bool refreshOnCompleted: true
    property string signalName: "SIGUSR1"

    signal loaded(string text)

    function refresh() {
        if (performancePaused) {
            reload()
            return
        }
        statusRefreshProc.running = false
        statusRefreshProc.running = true
    }

    function reload() {
        statusFile.reload()
    }

    onPerformancePausedChanged: {
        if (performancePaused) {
            statusRefreshProc.running = false
            statusStartProc.running = false
            statusFile.reload()
        } else {
            refresh()
        }
    }

    property var statusFile: FileView {
        path: root.statusPath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.loaded(text())
    }

    property var statusRefreshProc: Process {
        command: ["systemctl", "--user", "kill", "-s", root.signalName, "astrea-status.service"]
        running: false
        onExited: exitCode => {
            if (exitCode === 0 || !root.startOnRefreshFailure) {
                statusFile.reload()
            } else if (!root.performancePaused) {
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

    Component.onCompleted: {
        if (root.refreshOnCompleted)
            root.refresh()
    }
}
