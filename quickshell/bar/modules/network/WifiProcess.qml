import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property bool   connected: false
    property string ssid:      ""

    function refresh() {
        wifiProc.running = false
        wifiProc.running = true
    }

    property var wifiProc: Process {
        command: ["bash","-c","nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                root.ssid      = data.trim()
                root.connected = root.ssid !== ""
            }
        }
    }
}
