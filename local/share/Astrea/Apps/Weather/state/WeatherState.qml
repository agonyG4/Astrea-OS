import Quickshell.Io
import QtQuick 2.15

Item {
    id: root
    visible: false

    property var weatherData: null
    property bool loading: true
    property string errorMsg: ""
    property string weatherScript: "/home/agony/.local/share/Astrea/Core/bridge/apps/weather.py"

    function refresh() {
        loading = true
        errorMsg = ""
        weatherProc.running = true
    }

    Process {
        id: weatherProc
        command: ["/usr/bin/env", "python3", root.weatherScript, "get", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.weatherData = JSON.parse(this.text)
                    root.errorMsg = ""
                } catch(e) {
                    root.weatherData = null
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
                root.errorMsg = "Falha ao atualizar o clima"
            root.loading = false
        }
    }

    Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
