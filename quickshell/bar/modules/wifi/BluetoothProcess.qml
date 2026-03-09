import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property bool powered: false

    function refresh() {
        btProc.running = false
        btProc.running = true
    }

    property var btProc: Process {
        command: ["bash","-c","bluetoothctl show | grep 'Powered: yes'"]
        running: true
        stdout: SplitParser {
            onRead: data => { root.powered = data.trim() !== "" }
        }
    }
}
