import Quickshell
import Quickshell.Io
import QtQuick
import ".." as Modules

QtObject {
    id: root

    readonly property string scriptPath: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/System/scripts/bluetooth_manager.py"
    readonly property string statusPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/Astrea/status/bluetooth.json"

    property bool powered: false
    property string deviceName: ""
    property var devices: []
    property var scannedDevices: []
    readonly property string devicesJson: JSON.stringify(devices)
    readonly property string scannedJson: JSON.stringify(scannedDevices)
    property bool scanning: false
    property var _scanOwners: ({})
    property string _powerBuf: ""
    property string _pairTargetMac: ""
    property bool powerPending: false
    property string powerError: ""
    property bool _started: false
    property bool performancePaused: false

    function refresh() {
        statusBridge.refresh()
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
        root.scannedDevices = []
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
        for (var i = 0; i < root.devices.length; i++) {
            if (root.devices[i].mac === mac)
                return
        }
        for (var j = 0; j < root.scannedDevices.length; j++) {
            if (root.scannedDevices[j].mac === mac)
                return
        }
        var updated = root.scannedDevices.slice()
        updated.push({ mac: mac, name: name, connected: false, trusted: false, auto_connect: true })
        root.scannedDevices = updated
    }

    function applyStatus(text) {
        try {
            var payload = JSON.parse(text || "{}")
            root.powered = payload.powered === true
            root.deviceName = payload.connected_name || ""
            root.devices = payload.paired_devices || []
            root.powerError = ""
        } catch (error) {
        }
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

    property var statusBridge: Modules.StatusFile {
        statusPath: root.statusPath
        performancePaused: root.performancePaused
        refreshOnCompleted: false
        onLoaded: text => root.applyStatus(text)
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
        command: ["bluetoothctl", "pair", targetMac]
        running: false
        onExited: exitCode => {
            root._pairTargetMac = targetMac
            if (exitCode === 0) {
                trustProc.command = ["bluetoothctl", "trust", root._pairTargetMac]
                trustProc.running = false
                trustProc.running = true
                return
            }
            root.refresh()
            root.scannedDevices = []
            root.autoConnect(true)
            root.requestScan("pair-refresh")
        }
    }

    property var trustProc: Process {
        id: trustProc
        command: []
        running: false
        onExited: () => {
            root.refresh()
            root.scannedDevices = []
            root.autoConnect(true)
            root.requestScan("pair-refresh")
        }
    }

    Component.onCompleted: {
        root._started = true
        root.refresh()
    }
}
