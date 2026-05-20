pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string astreaRoot: Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")
    readonly property string helperPath: astreaRoot + "/System/i18n/i18n.py"
    readonly property string configPath: (Quickshell.env("HOME") || "") + "/.config/AstreaOS/system/settings.json"

    property string language: "en_US"
    property var messages: ({})
    property var strings: ({})
    property var fallbackStrings: ({})
    property bool ready: false
    property string _buffer: ""


    function tr(key, fallback, params) {
        var value = (messages && messages[key]) || fallback || key
        if (params) {
            for (var name in params)
                value = value.replace(new RegExp("\\{" + name + "\\}", "g"), String(params[name]))
        }
        return value
    }

    function reload() {
        ready = false
        _buffer = ""
        loadProc.running = false
        loadProc.command = ["python3", helperPath, "dump"]
        loadProc.running = true
    }

    Component.onCompleted: reload()

    property var configReloadDebounce: Timer {
        id: configReloadDebounce
        interval: 120
        repeat: false
        onTriggered: root.reload()
    }

    property var configFile: FileView {
        id: configFile
        path: root.configPath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: configReloadDebounce.restart()
    }

    property var loadProc: Process {
        id: loadProc
        running: false
        stdout: SplitParser {
            onRead: data => root._buffer += data
        }
        onExited: code => {
            if (code === 0) {
                try {
                    var payload = JSON.parse(root._buffer || "{}")
                    var merged = ({})
                    var fallback = payload.fallback || ({})
                    var active = payload.strings || ({})
                    for (var fallbackKey in fallback)
                        merged[fallbackKey] = fallback[fallbackKey]
                    for (var activeKey in active)
                        merged[activeKey] = active[activeKey]
                    root.language = payload.language || "en_US"
                    root.strings = active
                    root.fallbackStrings = fallback
                    root.messages = merged
                } catch (e) {
                    console.log("Astrea i18n parse failed:", e)
                }
            } else {
                console.log("Astrea i18n helper failed:", code)
            }
            root._buffer = ""
            root.ready = true
        }
    }
}
