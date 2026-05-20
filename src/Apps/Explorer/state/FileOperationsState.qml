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
    property bool pendingPasteClearsClipboard: false
    property var pendingRestoreTargets: []
    property bool archiveExtractionRunning: false
    property real archiveExtractionProgress: 0
    property int archiveExtractionPercent: 0
    property string archiveExtractionFileName: ""
    property string archiveExtractionStatus: ""
    property string archiveExtractionError: ""
    property string archiveExtractionOutputBuffer: ""
    property string archiveExtractionDestination: ""
    property string archiveExtractionRevealName: ""
    property string archiveOperationMode: ""
    property int archiveExtractionDoneCount: 0
    property int archiveExtractionTotalCount: 0
    property bool fileOperationRunning: false
    property real fileOperationProgress: 0
    property int fileOperationPercent: 0
    property string fileOperationFileName: ""
    property string fileOperationStatus: ""
    property string fileOperationError: ""
    property string fileOperationOutputBuffer: ""
    property string fileOperationDestination: ""
    property string fileOperationMode: ""
    property int fileOperationDoneCount: 0
    property int fileOperationTotalCount: 0
    property bool appImageInstallRunning: false
    property string appImageInstallError: ""

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
            "python3",
            app.helperPath,
            "copy-uri-list"
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

    function fileUrlForPath(path) {
        return "file://" + String(path || "")
    }

    function selectedPathsInCurrentFolder() {
        return app.selectedFiles.map(function(name) { return app.currentPath + "/" + name })
    }

    function selectedUriListInCurrentFolder() {
        return selectedPathsInCurrentFolder().map(function(path) { return fileUrlForPath(path) }).join("\n")
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

    function resetFileOperation(mode, destinationPath, totalCount) {
        fileOperationRunning = true
        fileOperationProgress = 0
        fileOperationPercent = 0
        fileOperationFileName = ""
        fileOperationStatus = mode === "move" ? "Movendo..." : "Copiando..."
        fileOperationError = ""
        fileOperationOutputBuffer = ""
        fileOperationDestination = destinationPath || ""
        fileOperationMode = mode || "copy"
        fileOperationDoneCount = 0
        fileOperationTotalCount = totalCount || 0
        fileOperationHideTimer.stop()
    }

    function handleFileOperationLine(rawLine) {
        var line = String(rawLine || "").trim()
        if (line === "")
            return
        if (line[0] === "{") {
            try {
                var evt = JSON.parse(line)
                var eventName = String(evt.event || "").toLowerCase()
                if (eventName === "start") {
                    fileOperationMode = String(evt.mode || fileOperationMode || "copy")
                    fileOperationDestination = String(evt.destination || fileOperationDestination)
                    fileOperationTotalCount = Number(evt.total || fileOperationTotalCount || 0)
                    fileOperationDoneCount = 0
                    fileOperationStatus = fileOperationMode === "move" ? "Movendo..." : "Copiando..."
                    fileOperationPercent = 0
                    fileOperationProgress = 0
                    return
                } else if (eventName === "progress") {
                    fileOperationMode = String(evt.mode || fileOperationMode || "copy")
                    fileOperationDoneCount = Number(evt.done || 0)
                    fileOperationTotalCount = Number(evt.total || fileOperationTotalCount || 0)
                    var jsonPercent = Number(evt.percent || 0)
                    if (!isFinite(jsonPercent))
                        jsonPercent = 0
                    fileOperationPercent = Math.max(0, Math.min(100, Math.round(jsonPercent)))
                    fileOperationProgress = fileOperationPercent / 100
                    fileOperationFileName = String(evt.name || "")
                    fileOperationStatus = (fileOperationMode === "move" ? "Movendo" : "Copiando") + "... " + fileOperationPercent + "%"
                    return
                } else if (eventName === "done") {
                    fileOperationMode = String(evt.mode || fileOperationMode || "copy")
                    fileOperationDestination = String(evt.destination || fileOperationDestination)
                    fileOperationDoneCount = Number(evt.done || fileOperationDoneCount || 0)
                    fileOperationTotalCount = Number(evt.total || fileOperationTotalCount || 0)
                    var donePercent = Number(evt.percent || 100)
                    if (!isFinite(donePercent))
                        donePercent = 100
                    fileOperationPercent = Math.max(0, Math.min(100, Math.round(donePercent)))
                    fileOperationProgress = fileOperationPercent / 100
                    fileOperationStatus = fileOperationMode === "move" ? "Movido" : "Copiado"
                    fileOperationError = ""
                    return
                } else if (eventName === "error") {
                    var code = String(evt.code || "")
                    var message = String(evt.message || "")
                    fileOperationError = message !== "" ? message : "Falha na operacao"
                    if (code !== "")
                        fileOperationError = fileOperationError + " (" + code + ")"
                    fileOperationStatus = fileOperationError
                    return
                }
            } catch (e) {
            }
        }
        var parts = line.split("|")
        if (parts[0] === "START") {
            fileOperationMode = parts[1] || fileOperationMode
            fileOperationDestination = parts[2] || fileOperationDestination
            fileOperationTotalCount = Number(parts[3] || fileOperationTotalCount)
            fileOperationDoneCount = 0
            fileOperationStatus = fileOperationMode === "move" ? "Movendo..." : "Copiando..."
            fileOperationPercent = 0
            fileOperationProgress = 0
        } else if (parts[0] === "PROGRESS") {
            fileOperationDoneCount = Number(parts[1] || 0)
            fileOperationTotalCount = Number(parts[2] || fileOperationTotalCount)
            var percent = Number(parts[3] || 0)
            if (!isFinite(percent))
                percent = 0
            fileOperationPercent = Math.max(0, Math.min(99, Math.round(percent)))
            fileOperationProgress = fileOperationPercent / 100
            fileOperationFileName = parts.slice(4).join("|")
            fileOperationStatus = (fileOperationMode === "move" ? "Movendo" : "Copiando") + "... " + fileOperationPercent + "%"
        } else if (parts[0] === "DONE") {
            fileOperationDestination = parts[1] || fileOperationDestination
            fileOperationDoneCount = Number(parts[2] || fileOperationDoneCount)
            fileOperationTotalCount = Number(parts[3] || fileOperationTotalCount)
            fileOperationPercent = 100
            fileOperationProgress = 1
            fileOperationStatus = fileOperationMode === "move" ? "Movido" : "Copiado"
            fileOperationError = ""
        } else if (parts[0] === "ERROR") {
            fileOperationError = parts.slice(1).join("|") || "Falha na operacao"
            fileOperationStatus = fileOperationError
        }
    }

    function handleFileOperationOutput(data) {
        fileOperationOutputBuffer += data
        var lines = fileOperationOutputBuffer.split("\n")
        fileOperationOutputBuffer = lines.pop()
        for (var i = 0; i < lines.length; i++)
            handleFileOperationLine(lines[i])
    }

    function startArchiveExtraction(archivePath, folderName) {
        if (!archivePath)
            return

        archiveExtractionRunning = true
        archiveExtractionProgress = 0
        archiveExtractionPercent = 0
        archiveExtractionFileName = basename(archivePath)
        archiveExtractionStatus = "Preparando extracao..."
        archiveExtractionError = ""
        archiveExtractionOutputBuffer = ""
        archiveExtractionDestination = ""
        archiveExtractionRevealName = ""
        archiveOperationMode = "extract"
        archiveExtractionDoneCount = 0
        archiveExtractionTotalCount = 0

        archiveExtractProcess.command = [
            "python3",
            app.helperPath,
            "extract-archive",
            archivePath,
            folderName || basename(archivePath)
        ]
        archiveExtractProcess.running = false
        archiveExtractProcess.running = true
    }

    function startFolderCompression(folderPath, format) {
        if (!folderPath)
            return

        archiveExtractionRunning = true
        archiveExtractionProgress = 0
        archiveExtractionPercent = 0
        archiveExtractionFileName = basename(folderPath)
        archiveExtractionStatus = "Preparando compactacao..."
        archiveExtractionError = ""
        archiveExtractionOutputBuffer = ""
        archiveExtractionDestination = ""
        archiveExtractionRevealName = ""
        archiveOperationMode = "compress"
        archiveExtractionDoneCount = 0
        archiveExtractionTotalCount = 0

        archiveExtractProcess.command = [
            "python3",
            app.helperPath,
            "compress-folder",
            folderPath,
            format || "zip"
        ]
        archiveExtractProcess.running = false
        archiveExtractProcess.running = true
    }

    function handleArchiveExtractionLine(rawLine) {
        var line = String(rawLine || "").trim()
        if (line === "")
            return
        if (line[0] === "{") {
            try {
                var evt = JSON.parse(line)
                var eventName = String(evt.event || "").toLowerCase()
                if (eventName === "start") {
                    archiveExtractionFileName = String(evt.name || archiveExtractionFileName)
                    archiveExtractionDestination = String(evt.destination || archiveExtractionDestination)
                    archiveExtractionTotalCount = Number(evt.total || archiveExtractionTotalCount || 0)
                    archiveExtractionDoneCount = 0
                    archiveExtractionPercent = 0
                    archiveExtractionProgress = 0
                    archiveExtractionStatus = archiveOperationMode === "compress" ? "Compactando..." : "Extraindo..."
                    return
                } else if (eventName === "progress") {
                    archiveExtractionDoneCount = Number(evt.done || 0)
                    archiveExtractionTotalCount = Number(evt.total || archiveExtractionTotalCount || 0)
                    var p = Number(evt.percent || 0)
                    if (!isFinite(p)) p = 0
                    archiveExtractionPercent = Math.max(0, Math.min(100, Math.round(p)))
                    archiveExtractionProgress = archiveExtractionPercent / 100
                    var v = archiveOperationMode === "compress" ? "Compactando" : "Extraindo"
                    archiveExtractionStatus = v + "... " + archiveExtractionPercent + "%"
                    return
                } else if (eventName === "done") {
                    archiveExtractionDestination = String(evt.destination || archiveExtractionDestination)
                    archiveExtractionRevealName = basename(archiveExtractionDestination)
                    archiveExtractionDoneCount = Number(evt.done || archiveExtractionDoneCount || 0)
                    archiveExtractionTotalCount = Number(evt.total || archiveExtractionTotalCount || 0)
                    archiveExtractionPercent = 100
                    archiveExtractionProgress = 1
                    archiveExtractionStatus = archiveOperationMode === "compress" ? "Compactacao concluida" : "Extracao concluida"
                    archiveExtractionError = ""
                    return
                } else if (eventName === "error") {
                    var m = String(evt.message || "")
                    var c = String(evt.code || "")
                    archiveExtractionDestination = String(evt.destination || archiveExtractionDestination)
                    archiveExtractionError = m !== "" ? m : (archiveOperationMode === "compress" ? "Falha ao compactar" : "Falha ao extrair")
                    if (c !== "")
                        archiveExtractionError = archiveExtractionError + " (" + c + ")"
                    archiveExtractionStatus = archiveExtractionError
                    return
                }
            } catch (e) {}
        }
        var parts = line.split("|")
        if (parts[0] === "START") {
            archiveExtractionFileName = parts[1] || archiveExtractionFileName
            archiveExtractionDestination = parts[2] || archiveExtractionDestination
            archiveExtractionTotalCount = Number(parts[3] || 0)
            archiveExtractionDoneCount = 0
            archiveExtractionStatus = archiveExtractionStatus.indexOf("compact") !== -1
                ? "Compactando..."
                : "Extraindo..."
            archiveExtractionPercent = 0
            archiveExtractionProgress = 0
        } else if (parts[0] === "PROGRESS") {
            var percent = Number(parts[3] || 0)
            if (!isFinite(percent))
                percent = 0
            archiveExtractionDoneCount = Number(parts[1] || 0)
            archiveExtractionTotalCount = Number(parts[2] || archiveExtractionTotalCount)
            archiveExtractionPercent = Math.max(0, Math.min(99, Math.round(percent)))
            archiveExtractionProgress = archiveExtractionPercent / 100
            var verb = archiveExtractionStatus.indexOf("Compact") === 0 ? "Compactando" : "Extraindo"
            archiveExtractionStatus = archiveExtractionPercent > 0
                ? (verb + "... " + archiveExtractionPercent + "%")
                : (verb + "...")
        } else if (parts[0] === "DONE") {
            archiveExtractionDestination = parts[1] || archiveExtractionDestination
            archiveExtractionRevealName = basename(archiveExtractionDestination)
            archiveExtractionDoneCount = Number(parts[2] || archiveExtractionDoneCount)
            archiveExtractionTotalCount = Number(parts[3] || archiveExtractionTotalCount)
            archiveExtractionPercent = 100
            archiveExtractionProgress = 1
            archiveExtractionStatus = archiveExtractionStatus.indexOf("Compact") === 0
                ? "Compactacao concluida"
                : "Extracao concluida"
            archiveExtractionError = ""
        } else if (parts[0] === "ERROR") {
            archiveExtractionDestination = parts[1] || archiveExtractionDestination
            archiveExtractionError = archiveExtractionStatus.indexOf("Compact") === 0
                ? "Falha ao compactar"
                : "Falha ao extrair"
            archiveExtractionStatus = archiveExtractionError
        }
    }

    function handleArchiveExtractionOutput(data) {
        archiveExtractionOutputBuffer += data
        var lines = archiveExtractionOutputBuffer.split("\n")
        archiveExtractionOutputBuffer = lines.pop()
        for (var i = 0; i < lines.length; i++)
            handleArchiveExtractionLine(lines[i])
    }

    function dropFiles(urls, destinationPath, mode) {
        if (!urls || urls.length === 0)
            return
        var files = []
        var resolvedDestination = destinationPath || app.currentPath
        for (var i = 0; i < urls.length; i++) {
            var uriItems = String(urls[i] || "").split(/\r?\n/).filter(function(line) { return line.trim() !== "" })
            for (var u = 0; u < uriItems.length; u++) {
                var path = normalizeFileUrl(uriItems[u].trim())
                if (!path)
                    continue
                var targetPath = joinPath(resolvedDestination, basename(path))
                if (path === targetPath)
                    continue
                if (path)
                    files.push(path)
            }
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
            "python3",
            app.helperPath,
            "scan-conflicts",
            resolvedDestination,
            "--format",
            "json"
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
            "python3",
            app.helperPath,
            "paste-image",
            app.currentPath,
            mimeType
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

        resetFileOperation(mode, destinationPath, files.length)
        pasteProcess.command = [
            app.backendPath,
            "file-op",
            "--json-events",
            mode,
            destinationPath,
            policy,
            pendingPasteRename
        ].concat(files)
        pasteProcess.running = false
        pasteProcess.running = true
        pendingPasteClearsClipboard = mode === "cut"
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
        pendingPasteClearsClipboard = false
        postPasteThumbnailWarmTimer.stop()
        fileOperationHideTimer.stop()
    }

    function deleteSelected() {
        if (app.selectedFiles.length === 0) return
        var targets = selectedPathsInCurrentFolder()
        pendingDeleteTargets = targets.slice()
        deleteProcess.command = [
            "python3",
            app.helperPath,
            "trash",
            app.trashFilesPath,
            app.trashInfoPath
        ].concat(targets)
        deleteProcess.running = false
        deleteProcess.running = true
        app.clearSelection()
    }

    function restoreSelected() {
        if (!app.inTrashView || app.selectedFiles.length === 0) return
        var targets = selectedPathsInCurrentFolder()
        pendingRestoreTargets = targets.slice()
        restoreProcess.command = [
            "python3",
            app.helperPath,
            "restore-trash",
            app.trashInfoPath,
            app.homePath
        ].concat(targets)
        restoreProcess.running = false
        restoreProcess.running = true
        app.clearSelection()
    }

    function emptyTrash() {
        emptyTrashProcess.command = [
            "python3",
            app.helperPath,
            "empty-trash",
            app.trashFilesPath,
            app.trashInfoPath
        ]
        emptyTrashProcess.running = false
        emptyTrashProcess.running = true
        app.clearSelection()
    }

    function installAppImage(path) {
        if (!path || appImageInstallRunning)
            return
        appImageInstallError = ""
        appImageInstallRunning = true
        appImageInstallProcess.command = [app.backendPath, "install-appimage", path]
        appImageInstallProcess.running = false
        appImageInstallProcess.running = true
    }

    property Process pasteProcess: Process {
        command: []
        running: false
        stdout: SplitParser {
            onRead: data => ops.handleFileOperationOutput(data)
        }
        stderr: StdioCollector {
            id: pasteStderr
        }
        onExited: function(exitCode) {
            if (ops.fileOperationOutputBuffer !== "") {
                ops.handleFileOperationLine(ops.fileOperationOutputBuffer)
                ops.fileOperationOutputBuffer = ""
            }
            if (exitCode === 0) {
                if (ops.pendingPasteClearsClipboard)
                    ops.clipboardFiles = []
                ops.fileOperationPercent = 100
                ops.fileOperationProgress = 1
                if (ops.fileOperationStatus.indexOf("Copiad") !== 0 && ops.fileOperationStatus.indexOf("Movid") !== 0)
                    ops.fileOperationStatus = ops.fileOperationMode === "move" ? "Movido" : "Copiado"
                ops.fileOperationError = ""
            } else {
                var err = pasteStderr.text.trim()
                ops.fileOperationError = ops.fileOperationError || err || "Falha na operacao"
                ops.fileOperationStatus = ops.fileOperationError
            }
            ops.pendingPasteClearsClipboard = false
            ops.pendingPostPasteThumbnailWarm = true
            app.refreshCurrentFolder()
            postPasteThumbnailWarmTimer.restart()
            fileOperationHideTimer.restart()
        }
    }

    property Timer fileOperationHideTimer: Timer {
        interval: ops.fileOperationError !== "" ? 3600 : 1600
        repeat: false
        onTriggered: {
            ops.fileOperationRunning = false
            ops.fileOperationProgress = 0
            ops.fileOperationPercent = 0
            ops.fileOperationFileName = ""
            ops.fileOperationStatus = ""
            ops.fileOperationError = ""
            ops.fileOperationOutputBuffer = ""
            ops.fileOperationDestination = ""
            ops.fileOperationMode = ""
            ops.fileOperationDoneCount = 0
            ops.fileOperationTotalCount = 0
        }
    }

    property Process archiveExtractProcess: Process {
        command: []
        running: false
        stdout: SplitParser {
            onRead: data => ops.handleArchiveExtractionOutput(data)
        }
        onExited: function(exitCode) {
            if (ops.archiveExtractionOutputBuffer !== "") {
                ops.handleArchiveExtractionLine(ops.archiveExtractionOutputBuffer)
                ops.archiveExtractionOutputBuffer = ""
            }
            if (exitCode === 0) {
                ops.archiveExtractionPercent = 100
                ops.archiveExtractionProgress = 1
                ops.archiveExtractionStatus = ops.archiveOperationMode === "compress"
                    ? "Compactacao concluida"
                    : "Extracao concluida"
                ops.archiveExtractionError = ""
                app.refreshCurrentFolder()
                if (ops.archiveOperationMode === "extract" && ops.archiveExtractionRevealName !== "")
                    archiveRevealTimer.restart()
            } else {
                ops.archiveExtractionError = ops.archiveOperationMode === "compress"
                    ? "Falha ao compactar"
                    : "Falha ao extrair"
                ops.archiveExtractionStatus = ops.archiveExtractionError
                app.refreshCurrentFolder()
            }
            archiveExtractionHideTimer.restart()
        }
    }

    property Timer archiveExtractionHideTimer: Timer {
        interval: 1800
        repeat: false
        onTriggered: {
            ops.archiveExtractionRunning = false
            ops.archiveExtractionProgress = 0
            ops.archiveExtractionPercent = 0
            ops.archiveExtractionFileName = ""
            ops.archiveExtractionStatus = ""
            ops.archiveExtractionError = ""
            ops.archiveExtractionDestination = ""
            ops.archiveExtractionRevealName = ""
            ops.archiveOperationMode = ""
            ops.archiveExtractionDoneCount = 0
            ops.archiveExtractionTotalCount = 0
        }
    }

    property Process conflictScanProcess: Process {
        command: []
        running: false
        stdout: StdioCollector {
            id: conflictScanStdout
            onStreamFinished: {
                var raw = (text || "").trim()
                var parsedItems = []
                if (raw !== "") {
                    try {
                        var parsed = JSON.parse(raw)
                        if (Array.isArray(parsed))
                            parsedItems = parsed
                    } catch (e) {
                        parsedItems = raw.split("\n").map(function(line) { return line.trim() }).filter(Boolean).map(function(name) {
                            return { name: name, conflict_kind: "name-collision", supported_policies: ["skip", "overwrite", "keep-both", "rename"] }
                        })
                    }
                }

                var blocking = parsedItems.filter(function(item) {
                    var kind = String(item.conflict_kind || "")
                    return kind === "file-over-directory" || kind === "directory-over-file" || kind === "same-path"
                })
                if (blocking.length > 0) {
                    ops.pendingPasteFiles = []
                    ops.pendingPasteMode = ""
                    ops.pendingPasteDestination = ""
                    ops.pendingPasteRename = ""
                    ops.fileOperationRunning = true
                    ops.fileOperationError = "Conflito de tipo nao suportado para colagem"
                    ops.fileOperationStatus = ops.fileOperationError
                    fileOperationHideTimer.restart()
                    return
                }

                var items = parsedItems.map(function(item) { return String(item.name || "") }).filter(Boolean)
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

    property Timer archiveRevealTimer: Timer {
        interval: 120
        repeat: false
        onTriggered: {
            if (app.loadingDir) {
                restart()
                return
            }
            if (ops.archiveExtractionRevealName !== "")
                app.selectByName(ops.archiveExtractionRevealName)
        }
    }

    property Process systemClipboardWrite: Process {
        command: []
        running: false
    }

    property Process appImageInstallProcess: Process {
        command: []
        running: false
        stderr: StdioCollector {
            id: appImageInstallStderr
        }
        onExited: function(exitCode) {
            ops.appImageInstallRunning = false
            ops.appImageInstallError = exitCode === 0 ? "" : appImageInstallStderr.text.trim()
            app.refreshCurrentFolder()
        }
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

    property Process restoreProcess: Process {
        command: []
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) {
                app.removePathsFromFileModel(ops.pendingRestoreTargets)
                app.refreshCurrentFolder()
            } else {
                app.refreshCurrentFolder()
            }
            ops.pendingRestoreTargets = []
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
