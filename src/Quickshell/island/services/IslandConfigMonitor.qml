import Quickshell.Io
import QtQuick

Item {
    id: root

    property string configFile: ""
    property string legacyConfigFile: ""
    property string stateScript: ""

    signal configChanged(var config)

    function applyConfigText(text) {
        try {
            root.configChanged(JSON.parse((text || "").trim()))
        } catch (error) {}
    }

    FileView {
        id: configFileView
        path: root.configFile
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyConfigText(text())
    }

    Process {
        id: configEnsure
        command: ["python3", root.stateScript, "ensure-config", root.configFile, root.legacyConfigFile]
        running: root.stateScript !== "" && root.configFile !== ""
        stdout: SplitParser {
            onRead: data => root.applyConfigText(data)
        }
        onExited: configFileView.reload()
    }
}
