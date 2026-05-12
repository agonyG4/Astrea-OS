import Quickshell
import Quickshell.Io
import QtQuick 2.15

Item {
    id: root
    visible: false

    property var weatherData: null
    property bool loading: true
    property string errorMsg: ""
    property bool backendMissing: false
    readonly property string astreaRoot: Quickshell.env("HOME") + "/.local/share/Astrea"
    property string weatherCli: astreaRoot + "/bin/weather-cli"
    property bool alertNotificationsEnabled: true
    property bool settingsLoaded: false

    Component.onCompleted: settingsLoadProc.running = true

    Timer {
        interval: 1800000
        repeat: true
        running: root.settingsLoaded && !root.backendMissing
        onTriggered: root.refresh()
    }

    function refresh(force) {
        if ((root.backendMissing && force !== true) || weatherProc.running)
            return
        if (force === true)
            root.backendMissing = false
        loading = true
        errorMsg = ""
        weatherProc.running = true
    }

    function retryBackend() {
        root.backendMissing = false
        root.errorMsg = ""
        if (!root.settingsLoaded && !settingsLoadProc.running)
            settingsLoadProc.running = true
        else
            root.refresh(true)
    }

    function markBackendMissing() {
        root.backendMissing = true
        root.errorMsg = root.missingBackendMessage()
        root.loading = false
    }

    function missingBackendMessage() {
        return "Backend do clima nao encontrado: " + weatherCli + ". Reinstale os servicos do Astrea ou rode astrea-services.sh doctor."
    }

    function setAlertNotificationsEnabled(enabled) {
        alertNotificationsEnabled = enabled
        if (root.backendMissing)
            return
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
                    root.backendMissing = false
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
                if (this.text.indexOf(root.weatherCli) !== -1)
                    root.markBackendMissing()
                else if (this.text.trim().length > 0)
                    root.errorMsg = this.text.trim()
            }
        }
        onExited: exitCode => {
            if (exitCode === 126 || exitCode === 127)
                root.markBackendMissing()
            else if (exitCode !== 0 && root.errorMsg === "")
                root.errorMsg = "Falha ao atualizar o clima"
            root.loading = false
        }
    }

    Process {
        id: settingsLoadProc
        command: ["/usr/bin/env", root.weatherCli, "settings"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length === 0)
                    return
                try {
                    var data = JSON.parse(this.text)
                    root.backendMissing = false
                    root.alertNotificationsEnabled = data.notifications_enabled !== false
                } catch(e) {
                    root.alertNotificationsEnabled = true
                }
                root.settingsLoaded = true
                root.refresh()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.indexOf(root.weatherCli) !== -1)
                    root.markBackendMissing()
            }
        }
        onExited: exitCode => {
            if (exitCode === 126 || exitCode === 127)
                root.markBackendMissing()
            if (!root.settingsLoaded) {
                root.settingsLoaded = true
                if (!root.backendMissing)
                    root.refresh()
                else
                    root.loading = false
            }
        }
    }

    Process {
        id: settingsSaveProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }
}
