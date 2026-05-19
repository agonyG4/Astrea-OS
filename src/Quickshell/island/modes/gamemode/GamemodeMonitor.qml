import Quickshell.Io
import QtQuick

Item {
    id: root

    property string stateScript: ""
    property bool active: false

    Process {
        id: gamemodeMonitor
        command: ["python3", root.stateScript, "gamemode"]
        running: true
        stdout: SplitParser {
            onRead: data => { root.active = data.trim() === "active" }
        }
    }
}
