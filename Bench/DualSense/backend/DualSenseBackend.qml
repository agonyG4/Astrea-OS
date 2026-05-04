import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: backend

    readonly property string scriptPath: Quickshell.env("HOME") + "/GitHub/Bench/DualSense/scripts/dualsense_manager.py"

    property bool loading: true
    property bool applying: false
    property bool installed: false
    property bool ready: false
    property var devices: []
    property string device: ""
    property string battery: ""
    property string info: ""
    property string message: "Loading"
    property string lastCommand: ""
    property string lastError: ""
    property string _statusBuffer: ""
    property string _applyBuffer: ""
    property string _applyErrorBuffer: ""
    property string _configBuffer: ""
    property bool _refreshAfterApply: true
    property var _liveCommand: []
    property string _liveBuffer: ""
    property string _liveErrorBuffer: ""
    property var config: ({})

    signal applied(string action, bool ok)
    signal configLoaded()

    function loadConfig() {
        if (configProc.running)
            return
        _configBuffer = ""
        configProc.command = ["python3", scriptPath, "config", "get"]
        configProc.running = true
    }

    function saveConfig(patch) {
        var merged = config || {}
        for (var key in patch)
            merged[key] = patch[key]
        config = merged
        saveConfigProc.command = ["python3", scriptPath, "config", "set", "--payload", JSON.stringify(patch)]
        saveConfigProc.running = false
        saveConfigProc.running = true
    }

    function refresh() {
        if (statusProc.running)
            return

        loading = true
        lastError = ""
        _statusBuffer = ""

        var command = ["python3", scriptPath]
        if (device !== "")
            command.push("--device", device)
        command.push("status")

        statusProc.command = command
        statusProc.running = true
    }

    function applyAction(action, args, refreshAfter) {
        if (applyProc.running)
            applyProc.running = false

        applying = true
        _refreshAfterApply = refreshAfter === undefined ? true : refreshAfter
        lastError = ""
        _applyBuffer = ""
        _applyErrorBuffer = ""

        var command = ["python3", scriptPath]
        if (device !== "")
            command.push("--device", device)
        command.push("apply", action)

        for (var i = 0; i < args.length; i++)
            command.push(String(args[i]))

        lastCommand = command.join(" ")
        applyProc.command = command
        applyProc.running = true
    }

    function applyLiveAction(action, args) {
        var command = ["python3", scriptPath]
        if (device !== "")
            command.push("--device", device)
        command.push("apply", action)

        for (var i = 0; i < args.length; i++)
            command.push(String(args[i]))

        if (liveProc.running) {
            _liveCommand = command
            return
        }

        _liveBuffer = ""
        _liveErrorBuffer = ""
        liveProc.command = command
        liveProc.running = true
    }

    Process {
        id: statusProc
        command: []
        stdout: SplitParser {
            onRead: line => backend._statusBuffer += line
        }
        stderr: SplitParser {
            onRead: line => backend.lastError += line
        }
        onExited: exitCode => {
            backend.loading = false
            try {
                var payload = JSON.parse(backend._statusBuffer)
                backend.installed = !!payload.installed
                backend.devices = payload.devices || []
                backend.device = payload.device || ""
                backend.battery = payload.battery || ""
                backend.info = payload.info || ""
                backend.message = payload.message || (payload.ok ? "Ready" : "Unavailable")
                backend.ready = !!payload.ok
                if (!payload.ok && backend.devices.length > 0)
                    backend.lastError = payload.message || backend.lastError
            } catch (e) {
                backend.ready = false
                backend.message = exitCode === 0 ? "Status parse error" : "Status command failed"
                backend.lastError = backend._statusBuffer || String(e)
            }
            backend._statusBuffer = ""
        }
    }

    Process {
        id: applyProc
        command: []
        stdout: SplitParser {
            onRead: line => backend._applyBuffer += line
        }
        stderr: SplitParser {
            onRead: line => backend._applyErrorBuffer += line
        }
        onExited: exitCode => {
            backend.applying = false
            var ok = exitCode === 0
            try {
                var payload = JSON.parse(backend._applyBuffer)
                ok = !!payload.ok
                backend.lastError = ok ? "" : (payload.stderr || payload.stdout || "Command failed")
            } catch (e) {
                backend.lastError = ok ? "" : (backend._applyErrorBuffer || backend._applyBuffer || "Command failed")
            }
            backend.applied("", ok)
            if (backend._refreshAfterApply)
                backend.refresh()
        }
    }

    Process {
        id: liveProc
        command: []
        stdout: SplitParser {
            onRead: line => backend._liveBuffer += line
        }
        stderr: SplitParser {
            onRead: line => backend._liveErrorBuffer += line
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                backend.lastError = backend._liveErrorBuffer || backend._liveBuffer || "Command failed"

            if (backend._liveCommand.length > 0) {
                liveProc.command = backend._liveCommand
                backend._liveCommand = []
                backend._liveBuffer = ""
                backend._liveErrorBuffer = ""
                liveProc.running = true
            }
        }
    }

    Process {
        id: configProc
        command: []
        stdout: SplitParser {
            onRead: line => backend._configBuffer += line
        }
        onExited: {
            try {
                var payload = JSON.parse(backend._configBuffer)
                backend.config = payload.config || {}
                backend.configLoaded()
            } catch (e) {
                backend.config = {}
            }
            backend._configBuffer = ""
        }
    }

    Process {
        id: saveConfigProc
        command: []
    }

    Component.onCompleted: {
        loadConfig()
        refresh()
    }
}
