import Quickshell
import Quickshell.Io
import QtQuick 2.15
import QtQuick.Controls 2.15
import "." as Finder
import "AstreaI18n" as AstreaI18n

ApplicationWindow {
    id: root
    visible: true
    width: 1080
    height: 720
    color: "transparent"
    title: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.portal_dialog.title.astrea_file_dialog"]) || "Astrea File Dialog")

    property var options: ({})
    property string resultFile: ""
    property string pendingResultJson: ""
    readonly property string stateJsonScript: (Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")) + "/Core/bridge/state_json.py"

    function parseOptions() {
        var raw = Quickshell.env("ASTREA_FILE_DIALOG_OPTIONS") || Quickshell.env("BENCH_FILE_DIALOG_OPTIONS") || ""
        if (!raw)
            return {}

        try {
            return JSON.parse(raw)
        } catch (error) {
            console.error("Failed to parse Astrea file dialog options:", error)
            return {}
        }
    }

    function emitResult(payload) {
        console.log("__ASTREA_FILE_DIALOG__" + JSON.stringify(payload))
        console.log("__BENCH_FILE_DIALOG__" + JSON.stringify(payload))
    }

    property bool resultSent: false

    function emitResultOnce(payload) {
        if (resultSent)
            return
        resultSent = true
        pendingResultJson = JSON.stringify(payload)
        if (resultFile !== "") {
            resultWriter.running = false
            resultWriter.running = true
        } else {
            emitResult(payload)
            Qt.callLater(function() {
                Qt.quit()
            })
        }
    }

    Component.onCompleted: {
        Qt.application.name = "Explorer"
        Qt.application.organization = "agony"
        Qt.application.domain = "local"
        options = parseOptions()
        resultFile = Quickshell.env("ASTREA_FILE_DIALOG_RESULT_FILE") || Quickshell.env("BENCH_FILE_DIALOG_RESULT_FILE") || ""
        dialog.mode = options.mode || "open_file"
        dialog.dialogTitle = options.title || dialog.dialogTitle
        dialog.acceptLabel = options.acceptLabel || dialog.acceptLabel
        dialog.startFolder = options.startFolder || dialog.startFolder
        dialog.selectedName = options.currentName || ""
        dialog.nameFilters = options.filters || []
        dialog.initialViewMode = options.viewMode || "icon"
        dialog.allowMultiple = Boolean(options.multiple)
        // Delay opening the popup until the top-level window is established.
        Qt.callLater(function() {
            dialog.openDialog()
        })
    }

    Process {
        id: resultWriter
        command: [
            "python3",
            root.stateJsonScript,
            "write",
            root.resultFile,
            root.pendingResultJson
        ]
        running: false
        stdout: StdioCollector {}
        onExited: function() {
            emitResult(JSON.parse(root.pendingResultJson))
            Qt.quit()
        }
    }

    Finder.FileDialog {
        id: dialog

        onFileChosen: function(filePath, fileUrl) {
            root.emitResultOnce({
                accepted: true,
                filePath: filePath,
                fileUrl: fileUrl
            })
        }

        onFilesChosen: function(files) {
            var selected = files || []
            var first = selected.length > 0 ? selected[0] : {}
            root.emitResultOnce({
                accepted: true,
                files: selected,
                filePath: first.filePath || "",
                fileUrl: first.fileUrl || ""
            })
        }

        onRejected: {
            root.emitResultOnce({ accepted: false })
        }
    }

    onClosing: function(close) {
        root.emitResultOnce({ accepted: false })
    }
}
