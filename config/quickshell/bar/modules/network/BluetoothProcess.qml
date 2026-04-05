import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property bool   powered:     false
    property string deviceName:  ""
    property string devicesJson: "[]"
    property string scannedJson: "[]"
    property bool   scanning:    false

    property var _scannedList: []

    function refresh() {
        btProc.running = false
        btProc.running = true
    }

    function startScan() {
        if (!root.powered) return
        root.scanning     = true
        root._scannedList = []
        root.scannedJson  = "[]"
        scanProc.running  = false
        scanProc.running  = true
    }

    function stopScan() {
        scanProc.running     = false
        scanStopProc.running = false
        scanStopProc.running = true
        root.scanning        = false
    }

    function _addScanned(mac, name) {
        var paired = []
        try { paired = JSON.parse(root.devicesJson) } catch(e) {}
        for (var i = 0; i < paired.length; i++) {
            if (paired[i].mac === mac) return
        }
        for (var j = 0; j < root._scannedList.length; j++) {
            if (root._scannedList[j].mac === mac) return
        }
        var updated = root._scannedList.slice()
        updated.push({ mac: mac, name: name, connected: false })
        root._scannedList = updated
        root.scannedJson  = JSON.stringify(updated)
    }

    property var btProc: Process {
        command: ["bash", "-c", "
            while true; do
                POWERED=$(bluetoothctl show < /dev/null | grep -q 'Powered: yes' && echo true || echo false);
                CON_DEV=$(bluetoothctl devices Connected < /dev/null | head -n1 | cut -d ' ' -f 2);
                if [ -n \"$CON_DEV\" ]; then
                    DEVICE=$(bluetoothctl info \"$CON_DEV\" < /dev/null | grep -m1 'Name:' | cut -d ' ' -f 2- || echo '');
                else
                    DEVICE='';
                fi
                DEVICES=$(bluetoothctl devices Paired < /dev/null);
                DEVICES_JSON=\"[\";
                if [ -n \"$DEVICES\" ]; then
                    FIRST=1;
                    while read -r line; do
                        if [ -z \"$line\" ]; then continue; fi;
                        MAC=$(echo \"$line\" | cut -d ' ' -f 2);
                        if [ -z \"$MAC\" ]; then continue; fi;
                        NAME=$(echo \"$line\" | cut -d ' ' -f 3-);
                        NAME=$(echo \"$NAME\" | tr -d '\"');
                        CONN=$(bluetoothctl info \"$MAC\" < /dev/null | grep -q 'Connected: yes' && echo true || echo false);
                        if [ $FIRST -eq 0 ]; then DEVICES_JSON=\"$DEVICES_JSON,\"; else FIRST=0; fi;
                        DEVICES_JSON=\"$DEVICES_JSON{\\\"mac\\\":\\\"$MAC\\\",\\\"name\\\":\\\"$NAME\\\",\\\"connected\\\":$CONN}\";
                    done <<< \"$DEVICES\";
                fi;
                DEVICES_JSON=\"$DEVICES_JSON]\";
                echo \"paired|$POWERED|$DEVICE|$DEVICES_JSON\";
                sleep 2;
            done
        "]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var p = data.split('|')
                if (p.length >= 4 && p[0] === 'paired') {
                    root.powered     = (p[1] === 'true')
                    root.deviceName  = p[2]
                    root.devicesJson = p[3]
                }
            }
        }
    }

    property var scanProc: Process {
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
                } else if (line.indexOf("found|") === 0) {
                    var p = line.split('|')
                    if (p.length >= 3) {
                        root._addScanned(p[1], p[2])
                    }
                }
            }
        }
        onRunningChanged: {
            if (!running) root.scanning = false
        }
    }

    property var scanStopProc: Process {
        command: ["bluetoothctl", "scan", "off"]
        running: false
    }

    property var pairProc: Process {
        property string targetMac: ""
        command: ["bluetoothctl", "pair", targetMac]
        running: false
        onRunningChanged: {
            if (!running) {
                root.refresh()
                root._scannedList = []
                root.scannedJson  = "[]"
            }
        }
    }
}
