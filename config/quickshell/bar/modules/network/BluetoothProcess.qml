import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    readonly property string scriptPath: Quickshell.env("HOME") + "/.local/share/Astrea/System/scripts/bluetooth_manager.py"

    property bool powered: false
    property string deviceName: ""
    property string devicesJson: "[]"
    property string scannedJson: "[]"
    property bool scanning: false
    property var _scannedList: []
    property string _statusBuf: ""

    function refresh() {
        if (statusProc.running)
            statusProc.running = false
        statusProc.running = true
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

    property var statusProc: Process {
        id: statusProc
        command: ["python3", root.scriptPath, "status"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root._statusBuf += data
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0 || !root._statusBuf.trim()) {
                root._statusBuf = ""
                return
            }
            try {
                const payload = JSON.parse(root._statusBuf)
                root.powered = !!payload.powered
                root.deviceName = payload.connected_name || ""
                root.devicesJson = JSON.stringify(payload.paired_devices || [])
            } catch (e) {
                console.log("Bluetooth status parse error:", e)
            }
            root._statusBuf = ""
        }
    }

    property var autoConnectProc: Process {
        id: autoConnectProc
        command: ["python3", root.scriptPath, "autoconnect"]
        running: false
        onExited: () => refresh()
    }

    property var scanProc: Process {
        id: scanProc
        command: ["bash", "-c", "
            (
                echo 'scan on'
                sleep 15
                echo 'scan off'
                sleep 1
            ) | bluetoothctl | while IFS= read -r line; do
                if echo \"$line\" | grep -q '\\[NEW\\] Device'; then
                    MAC=$(echo \"$line\" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}')
                    NAME=$(echo \"$line\" | sed 's/.*Device [0-9A-Fa-f:]*[[:space:]]*//')
                    NAME=$(echo \"$NAME\" | tr -d '\"\\\\' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [ -n \"$MAC\" ] && [ -n \"$NAME\" ] && [ \"$NAME\" != \"$MAC\" ] && ! echo \"$NAME\" | grep -qE '^([0-9A-Fa-f]{2}[-]){5}[0-9A-Fa-f]{2}$'; then
                        echo \"found|$MAC|$NAME\"
                    fi
                fi
                if echo \"$line\" | grep -q 'Discovery stopped\\|Discovering: no'; then
                    echo 'scan_done'
                fi
            done
        "]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line === "scan_done") {
                    root.scanning = false
                    root.refresh()
                } else if (line.indexOf("found|") === 0) {
                    var p = line.split("|")
                    if (p.length >= 3)
                        root._addScanned(p[1], p[2])
                }
            }
        }
        onRunningChanged: {
            if (!running)
                root.scanning = false
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
        }
    }

    property var refreshTimer: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    property var autoConnectTimer: Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: root.autoConnect(false)
    }
}
