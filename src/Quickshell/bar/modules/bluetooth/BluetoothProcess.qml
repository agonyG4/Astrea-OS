import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    readonly property string scriptPath: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/System/scripts/bluetooth_manager.py"
    readonly property string statusPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/Astrea/status/bluetooth.json"

    property bool powered: false
    property string deviceName: ""
    property string devicesJson: "[]"
    property string scannedJson: "[]"
    property bool scanning: false
    property var _scannedList: []
    property var _scanOwners: ({})
    property string _statusBuf: ""
    property string _powerBuf: ""
    property bool powerPending: false
    property string powerError: ""
    property bool _started: false

    function refresh() {
        statusRefreshProc.running = false
        statusRefreshProc.running = true
        if (directStatusProc.running)
            directStatusProc.running = false
        root._statusBuf = ""
        directStatusProc.running = true
    }

    function setPower(target) {
        if (root.powerPending || target === root.powered)
            return

        root.powerPending = true
        root.powerError = ""
        root._powerBuf = ""

        if (!target)
            root.stopScan()

        powerProc.command = ["python3", root.scriptPath, "power", target ? "on" : "off"]
        powerProc.running = false
        powerProc.running = true
    }

    function autoConnect(force) {
        if (scanning)
            return
        autoConnectProc.command = ["python3", root.scriptPath, force ? "force_autoconnect" : "autoconnect"]
        autoConnectProc.running = false
        autoConnectProc.running = true
    }

    function startScan() {
        if (!root.powered)
            return
        if (root.scanning)
            return
        root.scanning = true
        root._scannedList = []
        root.scannedJson = "[]"
        scanProc.running = false
        scanProc.running = true
    }

    function stopScan() {
        scanProc.running = false
        scanStopProc.running = false
        scanStopProc.running = true
        root.scanning = false
    }

    function requestScan(owner) {
        if (!owner)
            owner = "default"
        var owners = Object.assign({}, root._scanOwners)
        owners[owner] = true
        root._scanOwners = owners
        root.startScan()
    }

    function releaseScan(owner) {
        if (!owner)
            owner = "default"
        var owners = Object.assign({}, root._scanOwners)
        delete owners[owner]
        root._scanOwners = owners
        if (Object.keys(owners).length === 0 && root.scanning)
            root.stopScan()
    }

    function _addScanned(mac, name) {
        var paired = []
        try { paired = JSON.parse(root.devicesJson) } catch (e) {}
        for (var i = 0; i < paired.length; i++) {
            if (paired[i].mac === mac)
                return
        }
        for (var j = 0; j < root._scannedList.length; j++) {
            if (root._scannedList[j].mac === mac)
                return
        }
        var updated = root._scannedList.slice()
        updated.push({ mac: mac, name: name, connected: false, trusted: false, auto_connect: true })
        root._scannedList = updated
        root.scannedJson = JSON.stringify(updated)
    }

    function applyStatus(text) {
        try {
            var payload = JSON.parse(text || "{}")
            root.powered = payload.powered === true
            root.deviceName = payload.connected_name || ""
            root.devicesJson = JSON.stringify(payload.paired_devices || [])
            root.powerError = ""
        } catch (error) {
        }
    }

    function appendDirectStatus(data) {
        root._statusBuf += data
    }

    function appendPowerOutput(data) {
        root._powerBuf += data
    }

    function handlePowerExit(exitCode) {
        root.powerPending = false
        var ok = exitCode === 0
        try {
            if (root._powerBuf.trim()) {
                var payload = JSON.parse(root._powerBuf)
                ok = ok && payload.success === true
                if (typeof payload.powered === "boolean")
                    root.powered = payload.powered
                if (!ok)
                    root.powerError = payload.stderr || payload.stdout || payload.error || "Bluetooth power failed"
            }
        } catch (error) {
            ok = false
            root.powerError = "Bluetooth power returned invalid data"
        }
        if (!ok && root.powerError === "")
            root.powerError = "Bluetooth power failed"
        root._powerBuf = ""
        root.refresh()
        if (root.powered && Object.keys(root._scanOwners).length > 0)
            root.startScan()
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
        command: ["bash", "-c", "systemctl --user is-active --quiet astrea-status.service && systemctl --user kill -s SIGUSR1 astrea-status.service || systemctl --user start astrea-status.service"]
        running: false
        onExited: statusFile.reload()
    }

    property var directStatusProc: Process {
        id: directStatusProc
        command: ["python3", root.scriptPath, "status"]
        running: false
        stdout: SplitParser {
            onRead: data => root.appendDirectStatus(data)
        }
        onExited: exitCode => {
            if (exitCode === 0 && root._statusBuf.trim())
                root.applyStatus(root._statusBuf)
            root._statusBuf = ""
        }
    }

    property var powerProc: Process {
        id: powerProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: data => root.appendPowerOutput(data)
        }
        onExited: exitCode => root.handlePowerExit(exitCode)
    }

    property var autoConnectProc: Process {
        id: autoConnectProc
        command: ["python3", root.scriptPath, "autoconnect"]
        running: false
        onExited: () => {
            if (root._started)
                refresh()
        }
    }

    property var scanProc: Process {
        id: scanProc
        command: ["python3", root.scriptPath, "scan-stream"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    var payload = JSON.parse(data.trim())
                    if (payload.event === "done") {
                        root.scanning = false
                        root.refresh()
                        root._scanOwners = ({})
                    } else if (payload.event === "found") {
                        root._addScanned(payload.mac || "", payload.name || "")
                    }
                } catch (error) {
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                root.scanning = false
                root._scanOwners = ({})
            }
        }
    }

    property var scanStopProc: Process {
        id: scanStopProc
        command: ["bluetoothctl", "scan", "off"]
        running: false
    }

    property var pairProc: Process {
        id: pairProc
        property string targetMac: ""
        command: ["bash", "-lc", "bluetoothctl pair \"$1\" && bluetoothctl trust \"$1\"", "--", targetMac]
        running: false
        onExited: () => {
            root.refresh()
            root._scannedList = []
            root.scannedJson = "[]"
            root.autoConnect(true)
            root.requestScan("pair-refresh")
        }
    }

    Component.onCompleted: {
        root._started = true
        root.refresh()
    }
}
