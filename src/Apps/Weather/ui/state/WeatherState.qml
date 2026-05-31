import Quickshell
import Quickshell.Io
import QtQuick 2.15
import "../../AstreaI18n" as AstreaI18n

Item {
    id: root
    visible: false

    property var weatherData: null
    property bool loading: true
    property string errorMsg: ""
    property bool backendMissing: false
    readonly property string astreaRoot: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + ""
    property string weatherCli: astreaRoot + "/bin/weather-cli"
    property string city: ""
    property string countryCode: ""
    property bool alertNotificationsEnabled: true
    property bool settingsLoaded: false
    property bool settingsBusy: false
    property string settingsError: ""
    property bool pendingRefreshAfterSave: false

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
        var command = ["/usr/bin/env", "ASTREA_ROOT=" + root.astreaRoot, root.weatherCli, "get"]
        var targetCity = (root.city || "").trim()
        if (targetCity.length > 0)
            command.push(targetCity)
        command.push("--json")
        if (force === true)
            command.push("--force")
        weatherProc.command = command
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
        return AstreaI18n.I18n.tr("apps.weather.ui.state.weather_state.error.backend_missing", "Weather backend not found: {path}. Reinstall Astrea services or run astrea-services.sh doctor.", {
            path: weatherCli
        })
    }

    function setAlertNotificationsEnabled(enabled) {
        saveSettings(root.city, enabled, false)
    }

    function setCity(value) {
        saveSettings(value, root.alertNotificationsEnabled, true)
    }

    function saveSettings(nextCity, notificationsEnabled, refreshAfterSave) {
        var cleanCity = (nextCity || "").trim().replace(/\s+/g, " ")
        if (root.backendMissing || root.settingsBusy)
            return
        root.settingsBusy = true
        root.settingsError = ""
        root.pendingRefreshAfterSave = refreshAfterSave === true
        var command = [
            "/usr/bin/env",
            "ASTREA_ROOT=" + root.astreaRoot,
            root.weatherCli,
            "settings",
            "--notifications",
            notificationsEnabled ? "true" : "false"
        ]
        if (cleanCity.length > 0) {
            command.push("--city")
            command.push(cleanCity)
        } else {
            command.push("--clear-city")
        }
        settingsSaveProc.command = command
        settingsSaveProc.running = true
    }

    Process {
        id: weatherProc
        command: ["/usr/bin/env", "ASTREA_ROOT=" + root.astreaRoot, root.weatherCli, "get", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var payload = JSON.parse(this.text)
                    root.weatherData = payload
                    root.countryCode = payload.country_code || ""
                    root.backendMissing = false
                    root.errorMsg = ""
                } catch(e) {
                    root.weatherData = null
                    root.errorMsg = AstreaI18n.I18n.tr("apps.weather.ui.state.weather_state.error.parse_json", "Could not parse weather JSON")
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
                root.errorMsg = AstreaI18n.I18n.tr("apps.weather.ui.state.weather_state.error.refresh_failed", "Could not update weather")
            root.loading = false
        }
    }

    Process {
        id: settingsLoadProc
        command: ["/usr/bin/env", "ASTREA_ROOT=" + root.astreaRoot, root.weatherCli, "settings"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length === 0)
                    return
                try {
                    var data = JSON.parse(this.text)
                    root.backendMissing = false
                    root.alertNotificationsEnabled = data.notifications_enabled !== false
                    root.city = data.city || ""
                } catch(e) {
                    root.alertNotificationsEnabled = true
                    root.city = ""
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
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length === 0)
                    return
                try {
                    var data = JSON.parse(this.text)
                    root.alertNotificationsEnabled = data.notifications_enabled !== false
                    root.city = data.city || ""
                    root.settingsError = ""
                } catch(e) {
                    root.settingsError = AstreaI18n.I18n.tr("apps.weather.ui.state.weather_state.error.settings_parse_failed", "Could not read saved settings")
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0)
                    root.settingsError = this.text.trim()
            }
        }
        onExited: exitCode => {
            root.settingsBusy = false
            if (exitCode !== 0 && root.settingsError === "")
                root.settingsError = AstreaI18n.I18n.tr("apps.weather.ui.state.weather_state.error.settings_save_failed", "Could not save weather settings")
            if (exitCode === 0 && root.pendingRefreshAfterSave)
                root.refresh(true)
            root.pendingRefreshAfterSave = false
        }
    }
}
