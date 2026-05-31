import Quickshell
import Quickshell.Io
import QtQuick
import ".." as Modules

QtObject {
    id: root

    readonly property string statusPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/Astrea/status/network.json"
    property bool   connected: false
    property string type:      "none"
    property string ssid:      ""
    property string download:  "0 B/s"
    property string upload:    "0 B/s"
    property bool performancePaused: false

    function refresh() {
        statusBridge.refresh()
    }

    function applyStatus(text) {
        try {
            var payload = JSON.parse(text || "{}")
            root.connected = payload.connected === true
            root.type = payload.type || "none"
            root.ssid = payload.ssid || ""
            root.download = payload.download || "0 B/s"
            root.upload = payload.upload || "0 B/s"
        } catch (error) {
        }
    }

    property var statusBridge: Modules.StatusFile {
        statusPath: root.statusPath
        performancePaused: root.performancePaused
        onLoaded: text => root.applyStatus(text)
    }
}
