import Quickshell.Io
import QtQuick 2.15

Item {
    id: root
    visible: false

    property var weatherData: null
    property bool loading: true
    property string errorMsg: ""
    property string weatherScript: "/home/agony/.local/share/Astrea/Core/bridge/apps/weather.py"
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
            "python3",
            root.weatherScript,
            "notifications-setting",
            enabled ? "true" : "false"
        ]
        settingsSaveProc.running = true
    }

    function notifyAlerts(data) {
        if (!settingsLoaded || !alertNotificationsEnabled || !data || !data.alerts || data.alerts.length === 0)
            return
        if (alertNotifyProc.running)
            return

        alertNotifyProc.command = [
            "/usr/bin/env",
            "python3",
            root.weatherScript,
            "notify-alerts",
            "--city",
            data.city || "",
            JSON.stringify(data.alerts)
        ]
        alertNotifyProc.running = true
    }

    Process {
        id: weatherProc
        command: ["/usr/bin/env", "python3", root.weatherScript, "get", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.weatherData = JSON.parse(this.text)
                    root.errorMsg = ""
                    root.notifyAlerts(root.weatherData)
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
        id: alertNotifyProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: settingsLoadProc
        command: ["/usr/bin/env", "python3", root.weatherScript, "notifications-setting"]
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

    Timer {
        interval: 1800000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
