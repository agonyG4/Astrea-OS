import QtQuick 2.15
import Quickshell.Io

QtObject {
    id: ops

    property QtObject app
    property var pendingDeleteTargets: []
    property var clipboardFiles: []
    property string clipboardMode: "copy"
    property bool pasteConflictVisible: false
    property var pasteConflictItems: []
    property var pendingPasteFiles: []
    property string pendingPasteMode: ""
    property string pendingPasteDestination: ""
    property string pendingPasteRename: ""
    property string pendingClipboardImageMime: ""
    property bool pendingPostPasteThumbnailWarm: false

    function isCutPending(name) {
        if (!name || clipboardMode !== "cut") return false
        var fullPath = app.currentPath + "/" + name
        return clipboardFiles.indexOf(fullPath) !== -1
    }

    function copySelected() {
        if (app.selectedFiles.length === 0) return
        clipboardFiles = app.selectedFiles.map(function(name) { return app.currentPath + "/" + name })
        clipboardMode = "copy"
        syncSystemClipboardFiles(clipboardFiles)
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
        syncSystemClipboardFiles(clipboardFiles)
    }

    function syncSystemClipboardFiles(files) {
        if (!files || files.length === 0)
            return
        systemClipboardWrite.command = [
            "bash", "-lc",
            "for f in \"$@\"; do printf 'file://%s\\n' \"$f\"; done | wl-copy --type text/uri-list",
            "_"
        ].concat(files)
        systemClipboardWrite.running = false
        systemClipboardWrite.running = true
    }

    function normalizeFileUrl(url) {
        if (url === undefined || url === null)
            return ""
        var value = String(url)
        if (value.indexOf("file://") !== 0)
            return ""
        var decoded = value.slice("file://".length)
        try {
            return decodeURIComponent(decoded)
        } catch (e) {
            return decoded
        }
    }

    function joinPath(dirPath, fileName) {
        if (!dirPath)
            return fileName || ""
        return dirPath.replace(/\/+$/, "") + "/" + (fileName || "")
    }

    function basename(path) {
        var parts = String(path || "").split("/")
        return parts.length > 0 ? parts[parts.length - 1] : ""
    }

    function dropFiles(urls, destinationPath, mode) {
        if (!urls || urls.length === 0)
            return
        var files = []
        var resolvedDestination = destinationPath || app.currentPath
        for (var i = 0; i < urls.length; i++) {
            var path = normalizeFileUrl(urls[i])
            if (!path)
                continue
            var targetPath = joinPath(resolvedDestination, basename(path))
            if (path === targetPath)
                continue
            if (path)
                files.push(path)
        }
        if (files.length === 0)
            return
        startPasteForFiles(files, mode || "copy", resolvedDestination)
    }

    function startPasteForFiles(files, mode, destinationPath) {
        if (!files || files.length === 0)
            return
        var resolvedDestination = destinationPath || app.currentPath
        conflictScanProcess.command = [
            "bash", "-lc",
            "dest=\"$1\"; shift; " +
            "for f in \"$@\"; do " +
            "name=$(basename -- \"$f\"); target=\"$dest/$name\"; " +
            "if [ \"$f\" != \"$target\" ] && [ -e \"$target\" ]; then printf '%s\\n' \"$name\"; fi; " +
            "done",
            "_", resolvedDestination
        ].concat(files)
        pendingPasteFiles = files.slice()
        pendingPasteMode = mode || "copy"
        pendingPasteDestination = resolvedDestination
        conflictScanProcess.running = false
        conflictScanProcess.running = true
    }

    function parseClipboardUriList(raw) {
        return (raw || "")
            .split(/\r?\n/)
            .map(function(line) { return line.trim() })
            .filter(function(line) { return line !== "" && line[0] !== "#" && line.indexOf("file://") === 0 })
            .map(function(line) {
                var decoded = line.slice("file://".length)
                try {
                    return decodeURIComponent(decoded)
                } catch (e) {
                    return decoded
                }
            })
            .filter(function(path) { return path !== "" })
    }

    function pasteFiles() {
        if (clipboardMode === "cut" && clipboardFiles.length > 0) {
            startPasteForFiles(clipboardFiles.slice(), clipboardMode, app.currentPath)
            return
        }

        systemClipboardProbe.running = false
        systemClipboardProbe.running = true
    }

    function importClipboardImage(mimeType) {
        if (!mimeType)
            return
        pendingClipboardImageMime = mimeType
        pasteImageProcess.command = [
            "bash", "-lc",
            "set -e; " +
            "dest_dir=\"$1\"; mime=\"$2\"; " +
            "case \"$mime\" in " +
            "  image/png) ext='png' ;; " +
            "  image/jpeg) ext='jpg' ;; " +
            "  image/webp) ext='webp' ;; " +
            "  image/gif) ext='gif' ;; " +
            "  image/bmp) ext='bmp' ;; " +
            "  image/tiff) ext='tiff' ;; " +
            "  image/x-portable-pixmap) ext='ppm' ;; " +
            "  image/x-portable-graymap) ext='pgm' ;; " +
            "  image/x-portable-bitmap) ext='pbm' ;; " +
            "  *) ext='png' ;; " +
            "esac; " +
            "stamp=$(date +'%Y-%m-%d %H-%M-%S'); " +
            "base=\"Pasted Image $stamp\"; target=\"$dest_dir/$base.$ext\"; n=2; " +
            "while [ -e \"$target\" ]; do target=\"$dest_dir/$base $n.$ext\"; n=$((n+1)); done; " +
            "wl-paste --no-newline --type \"$mime\" > \"$target\"; " +
            "printf '%s\\n' \"$target\"",
            "_", app.currentPath, mimeType
        ]
        pasteImageProcess.running = false
        pasteImageProcess.running = true
    }

    function executePaste(policy) {
        var files = pendingPasteFiles.length > 0 ? pendingPasteFiles.slice() : clipboardFiles.slice()
        var mode = pendingPasteMode || clipboardMode
        var destinationPath = pendingPasteDestination || app.currentPath
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
            "_", mode, policy, destinationPath, pendingPasteRename
        ].concat(files)
        pasteProcess.running = false
        pasteProcess.running = true
        if (mode === "cut")
            clipboardFiles = []
        pendingPasteFiles = []
        pendingPasteMode = ""
        pendingPasteDestination = ""
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
        pendingPasteDestination = ""
        pendingPasteRename = ""
        pendingClipboardImageMime = ""
        pendingPostPasteThumbnailWarm = false
        postPasteThumbnailWarmTimer.stop()
    }

    function deleteSelected() {
        if (app.selectedFiles.length === 0) return
        var targets = app.selectedFiles.map(function(name) { return app.currentPath + "/" + name })
        pendingDeleteTargets = targets.slice()
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

    function emptyTrash() {
        emptyTrashProcess.command = [
            "bash", "-lc",
            "trash_files=\"$1\"; trash_info=\"$2\"; " +
            "mkdir -p -- \"$trash_files\" \"$trash_info\"; " +
            "find \"$trash_files\" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null; " +
            "find \"$trash_info\" -mindepth 1 -maxdepth 1 -exec rm -f -- {} + 2>/dev/null",
            "_", app.trashFilesPath, app.trashInfoPath
        ]
        emptyTrashProcess.running = false
        emptyTrashProcess.running = true
        app.clearSelection()
    }

    property Process pasteProcess: Process {
        command: []
        running: false
        onExited: function() {
            ops.pendingPostPasteThumbnailWarm = true
            app.refreshCurrentFolder()
            postPasteThumbnailWarmTimer.restart()
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

    property Process systemClipboardProbe: Process {
        command: [
            "bash", "-lc",
            "types=$(wl-paste --list-types 2>/dev/null || true); " +
            "if printf '%s\\n' \"$types\" | grep -qx 'text/uri-list'; then " +
            "  printf 'uri-list\\n'; " +
            "  wl-paste --no-newline --type text/uri-list 2>/dev/null || true; " +
            "elif printf '%s\\n' \"$types\" | grep -Eq '^(image/png|image/jpeg|image/webp|image/gif|image/bmp|image/tiff|image/x-portable-pixmap|image/x-portable-graymap|image/x-portable-bitmap)$'; then " +
            "  printf 'image\\n'; " +
            "  printf '%s' \"$(printf '%s\\n' \"$types\" | grep -E '^(image/png|image/jpeg|image/webp|image/gif|image/bmp|image/tiff|image/x-portable-pixmap|image/x-portable-graymap|image/x-portable-bitmap)$' | head -n1)\"; " +
            "fi"
        ]
        running: false
        stdout: StdioCollector {
            id: systemClipboardProbeStdout
            onStreamFinished: {
                var output = text || ""
                if (output === "")
                    return

                var newlineIndex = output.indexOf("\n")
                var mode = newlineIndex === -1 ? output.trim() : output.slice(0, newlineIndex).trim()
                var payload = newlineIndex === -1 ? "" : output.slice(newlineIndex + 1)

                if (mode === "uri-list") {
                var files = ops.parseClipboardUriList(payload)
                if (files.length > 0)
                        ops.startPasteForFiles(files, "copy", app.currentPath)
                } else if (mode === "image") {
                    ops.importClipboardImage(payload.trim())
                }
            }
        }
        onExited: function() {
            if (systemClipboardProbeStdout.text.trim() === "" && clipboardFiles.length > 0)
                ops.startPasteForFiles(clipboardFiles.slice(), clipboardMode, app.currentPath)
        }
    }

    property Process pasteImageProcess: Process {
        command: []
        running: false
        stdout: StdioCollector {
            id: pasteImageStdout
        }
        onExited: function(exitCode) {
            ops.pendingClipboardImageMime = ""
            if (exitCode === 0 && pasteImageStdout.text.trim() !== "") {
                ops.pendingPostPasteThumbnailWarm = true
                app.refreshCurrentFolder()
                postPasteThumbnailWarmTimer.restart()
            }
        }
    }

    property Timer postPasteThumbnailWarmTimer: Timer {
        interval: 180
        repeat: false
        onTriggered: {
            if (!ops.pendingPostPasteThumbnailWarm)
                return
            if (app.loadingDir) {
                restart()
                return
            }
            ops.pendingPostPasteThumbnailWarm = false
            app.warmCurrentDirectoryThumbnails()
        }
    }

    property Process systemClipboardWrite: Process {
        command: []
        running: false
    }

    property Process deleteProcess: Process {
        command: []
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) {
                app.removePathsFromFileModel(ops.pendingDeleteTargets)
                if (app.inTrashView)
                    app.refreshCurrentFolder()
            } else {
                app.refreshCurrentFolder()
            }
            ops.pendingDeleteTargets = []
        }
    }

    property Process emptyTrashProcess: Process {
        command: []
        running: false
        onExited: function() {
            app.refreshCurrentFolder()
        }
    }
}
