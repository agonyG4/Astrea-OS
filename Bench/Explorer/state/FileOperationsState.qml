import QtQuick 2.15
import Quickshell.Io

QtObject {
    id: ops

    property QtObject app
    property var clipboardFiles: []
    property string clipboardMode: "copy"
    property bool pasteConflictVisible: false
    property var pasteConflictItems: []
    property var pendingPasteFiles: []
    property string pendingPasteMode: ""
    property string pendingPasteRename: ""

    function isCutPending(name) {
        if (!name || clipboardMode !== "cut") return false
        var fullPath = app.currentPath + "/" + name
        return clipboardFiles.indexOf(fullPath) !== -1
    }

    function copySelected() {
        if (app.selectedFiles.length === 0) return
        clipboardFiles = app.selectedFiles.map(function(name) { return app.currentPath + "/" + name })
        clipboardMode = "copy"
    }

    function cutSelected() {
        if (app.selectedFiles.length === 0) return
        var newlyCut = app.selectedFiles.map(function(name) { return app.currentPath + "/" + name })
        var same = clipboardMode === "cut" && clipboardFiles.length === newlyCut.length
                && clipboardFiles.every(function(v, i) { return v === newlyCut[i] })
        if (same) {
            clipboardFiles = []
            clipboardMode = ""
            return
        }
        clipboardFiles = newlyCut
        clipboardMode = "cut"
    }

    function pasteFiles() {
        if (clipboardFiles.length === 0) return

        conflictScanProcess.command = [
            "bash", "-lc",
            "dest=\"$1\"; shift; " +
            "for f in \"$@\"; do " +
            "name=$(basename -- \"$f\"); target=\"$dest/$name\"; " +
            "if [ \"$f\" != \"$target\" ] && [ -e \"$target\" ]; then printf '%s\\n' \"$name\"; fi; " +
            "done",
            "_", app.currentPath
        ].concat(clipboardFiles)
        pendingPasteFiles = clipboardFiles.slice()
        pendingPasteMode = clipboardMode
        conflictScanProcess.running = false
        conflictScanProcess.running = true
    }

    function executePaste(policy) {
        var files = pendingPasteFiles.length > 0 ? pendingPasteFiles.slice() : clipboardFiles.slice()
        var mode = pendingPasteMode || clipboardMode
        if (files.length === 0)
            return

        pasteProcess.command = [
            "bash", "-lc",
            "mode=\"$1\"; policy=\"$2\"; dest=\"$3\"; rename_to=\"$4\"; shift 4; " +
            "for f in \"$@\"; do " +
            "name=$(basename -- \"$f\"); target=\"$dest/$name\"; " +
            "if [ \"$f\" = \"$target\" ]; then continue; fi; " +
            "if [ -e \"$target\" ]; then " +
            "  case \"$policy\" in " +
            "    overwrite) rm -rf -- \"$target\" ;; " +
            "    skip) continue ;; " +
            "    rename) [ -n \"$rename_to\" ] || continue; target=\"$dest/$rename_to\"; if [ -e \"$target\" ]; then continue; fi ;; " +
            "    keep-both) n=2; while [ -e \"$target\" ]; do target=\"$dest/$name $n\"; n=$((n+1)); done ;; " +
            "  esac; " +
            "fi; " +
            "if [ \"$mode\" = \"copy\" ]; then cp -r -- \"$f\" \"$target\"; else mv -- \"$f\" \"$target\"; fi; " +
            "done",
            "_", mode, policy, app.currentPath, pendingPasteRename
        ].concat(files)
        pasteProcess.running = false
        pasteProcess.running = true
        if (mode === "cut")
            clipboardFiles = []
        pendingPasteFiles = []
        pendingPasteMode = ""
        pendingPasteRename = ""
        pasteConflictItems = []
        pasteConflictVisible = false
    }

    function resolvePasteConflict(policy) {
        executePaste(policy)
    }

    function renamePasteConflict(newName) {
        var trimmed = (newName || "").trim()
        if (pasteConflictItems.length !== 1 || !trimmed)
            return
        pendingPasteRename = trimmed
        executePaste("rename")
    }

    function cancelPasteConflict() {
        pasteConflictVisible = false
        pasteConflictItems = []
        pendingPasteFiles = []
        pendingPasteMode = ""
        pendingPasteRename = ""
    }

    function deleteSelected() {
        if (app.selectedFiles.length === 0) return
        var targets = app.selectedFiles.map(function(name) { return app.currentPath + "/" + name })
        deleteProcess.command = [
            "bash", "-lc",
            "trashDir=\"$HOME/.local/share/Trash/files\"; mkdir -p -- \"$trashDir\"; " +
            "for target in \"$@\"; do " +
            "name=$(basename -- \"$target\"); dest=\"$trashDir/$name\"; " +
            "n=2; while [ -e \"$dest\" ]; do dest=\"$trashDir/$name $n\"; n=$((n+1)); done; " +
            "mv -- \"$target\" \"$dest\"; " +
            "done",
            "_"
        ].concat(targets)
        deleteProcess.running = false
        deleteProcess.running = true
        app.clearSelection()
    }

    property Process pasteProcess: Process {
        command: []
        running: false
        onExited: function() {
            app.refreshCurrentFolder()
        }
    }

    property Process conflictScanProcess: Process {
        command: []
        running: false
        stdout: StdioCollector {
            id: conflictScanStdout
            onStreamFinished: {
                var items = text.split("\n").map(function(line) { return line.trim() }).filter(Boolean)
                ops.pasteConflictItems = items
                if (items.length > 0) {
                    ops.pendingPasteRename = items.length === 1 ? items[0] : ""
                    ops.pasteConflictVisible = true
                } else {
                    ops.executePaste("keep-both")
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0 && conflictScanStdout.text.trim() === "") {
                ops.pendingPasteFiles = []
                ops.pendingPasteMode = ""
                ops.pendingPasteRename = ""
            }
        }
    }

    property Process deleteProcess: Process {
        command: []
        running: false
        onExited: function() {
            app.refreshCurrentFolder()
        }
    }
}
