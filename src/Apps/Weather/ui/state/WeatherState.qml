import Quickshell.Io
import QtQuick 2.15

Item {
    id: root
    visible: false

    property var weatherData: null
    property bool loading: true
    property string errorMsg: ""
    property string weatherCli: "/home/agony/.local/share/Astrea/Apps/Weather/backend/target/release/weather-cli"
    property bool alertNotificationsEnabled: true
    property bool settingsLoaded: false

    Component.onCompleted: settingsLoadProc.running = true

    function refresh() {
        loading = true
        errorMsg = ""
        weatherProc.running = true
    }

    function setAlertNotificationsEnabled(enabled) {
        alertNotificationsEnabled = enabled
        settingsSaveProc.command = [
            "/usr/bin/env",
            root.weatherCli,
            "settings",
            enabled ? "true" : "false"
        ]
        settingsSaveProc.running = true
    }

    Process {
        id: weatherProc
        command: ["/usr/bin/env", root.weatherCli, "get", "--json"]
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

    Process {
        id: settingsLoadProc
        command: ["/usr/bin/env", root.weatherCli, "settings"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text)
                    root.alertNotificationsEnabled = data.notifications_enabled !== false
                } catch(e) {
                    root.alertNotificationsEnabled = true
                }
                root.settingsLoaded = true
                root.refresh()
            }
        }
        stderr: StdioCollector {}
        onExited: exitCode => {
            if (!root.settingsLoaded) {
                root.settingsLoaded = true
                root.refresh()
            }
        }
    }

    Process {
        id: settingsSaveProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }
}
