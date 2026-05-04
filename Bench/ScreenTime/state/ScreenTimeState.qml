import Quickshell.Io
import QtQuick 2.15

Item {
    id: root
    visible: false

    property var screenData: null
    property bool loading: true
    property string errorMsg: ""
    property string scriptPath: "/home/agony/GitHub/Bench/ScreenTime/screentime.py"

    function refresh() {
        if (snapshotProc.running)
            return
        loading = screenData === null
        errorMsg = ""
        snapshotProc.running = true
    }

    Process {
        id: snapshotProc
        command: ["/usr/bin/env", "python3", root.scriptPath, "snapshot", "--json", "--limit", "14"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.screenData = JSON.parse(this.text)
                    root.errorMsg = ""
                } catch(e) {
                    root.errorMsg = "Erro ao parsear JSON"
                }
                root.loading = false
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0)
                    root.errorMsg = this.text.trim()
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0 && root.errorMsg === "")
                root.errorMsg = "Falha ao carregar ScreenTime"
            root.loading = false
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
