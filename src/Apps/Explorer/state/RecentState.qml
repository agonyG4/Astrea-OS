import Quickshell
import QtQuick 2.15
import Quickshell.Io

QtObject {
    id: recent

    property QtObject app
    property var items: []
    property string loadBuffer: ""
    readonly property int maxItems: 60
    readonly property string storagePath: Quickshell.env("HOME") + "/.local/state/Astrea/finder-recents.json"
    readonly property string launchHistoryPath: Quickshell.env("HOME") + "/.local/state/Astrea/launch/history.jsonl"
    readonly property string xbelRecentPath: Quickshell.env("HOME") + "/.local/share/recently-used.xbel"
    readonly property string stateJsonScript: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Core/bridge/state_json.py"

    function isPreviewablePath(path, isDir) {
        if (isDir || !path)
            return false
        var lowerPath = path.toLowerCase()
        return [".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".svg"].some(function(ext) {
            return lowerPath.lastIndexOf(ext) === lowerPath.length - ext.length
        })
    }

    function normalizeItem(item) {
        if (!item || !item.filePath)
            return null

        var fileName = item.fileName || item.filePath.split("/").pop() || item.filePath
        var fileUrl = item.fileUrl || app.fileUrlForPath(item.filePath)
        var isDir = Boolean(item.fileIsDir)
        var previewUrl = item.filePreviewUrl || ""
        if (!previewUrl && isPreviewablePath(item.filePath, isDir))
            previewUrl = fileUrl
        return {
            fileName: fileName,
            filePath: item.filePath,
            fileUrl: fileUrl,
            fileIsDir: isDir,
            fileExecutable: Boolean(item.fileExecutable),
            fileHidden: Boolean(item.fileHidden || (fileName.charAt(0) === ".")),
            fileSize: typeof item.fileSize === "number" ? item.fileSize : -1,
            fileModified: item.fileModified || "",
            fileKind: item.fileKind || "",
            filePreviewUrl: previewUrl,
            lastAccessed: typeof item.lastAccessed === "number" ? item.lastAccessed : Date.now(),
            recentSource: item.recentSource || "finder"
        }
    }

    function persistedRecentItems() {
        var persisted = []
        for (var i = 0; i < items.length; i++) {
            var item = normalizeItem(items[i])
            if (item && item.recentSource === "finder")
                persisted.push(item)
        }
        return persisted
    }

    function recentModelItems() {
        var normalized = []
        for (var i = 0; i < items.length; i++) {
            var item = normalizeItem(items[i])
            if (item) {
                item.fileModified = item.lastAccessed
                normalized.push(item)
            }
        }
        normalized.sort(function(a, b) { return (b.lastAccessed || 0) - (a.lastAccessed || 0) })
        return normalized
    }

    function persist() {
        saveProc.command = [
            "python3",
            stateJsonScript,
            "write",
            storagePath,
            JSON.stringify(persistedRecentItems())
        ]
        saveProc.running = false
        saveProc.running = true
    }

    function load() {
        loadBuffer = ""
        loadProc.running = false
        loadProc.running = true
    }

    function recordAccess(path, isDir, fileUrl) {
        if (!path || app.isRecentPath(path) || app.isTrashPath(path) || app.dialogActive)
            return

        var entry = {
            filePath: path,
            fileUrl: fileUrl || app.fileUrlForPath(path),
            fileIsDir: Boolean(isDir),
            fileExecutable: false,
            fileName: path.split("/").pop() || path,
            fileHidden: false,
            fileSize: -1,
            fileModified: "",
            fileKind: "",
            filePreviewUrl: "",
            lastAccessed: Date.now(),
            recentSource: "finder"
        }

        for (var i = 0; i < app.fileModel.count; i++) {
            var modelItem = app.fileModel.get(i)
            if (modelItem.filePath === path) {
                entry.fileName = modelItem.fileName || entry.fileName
                entry.fileUrl = modelItem.fileUrl || entry.fileUrl
                entry.fileIsDir = Boolean(modelItem.fileIsDir)
                entry.fileExecutable = Boolean(modelItem.fileExecutable)
                entry.fileHidden = Boolean(modelItem.fileHidden)
                entry.fileSize = typeof modelItem.fileSize === "number" ? modelItem.fileSize : -1
                entry.fileModified = modelItem.fileModified || ""
                entry.fileKind = modelItem.fileKind || ""
                entry.filePreviewUrl = modelItem.filePreviewUrl || ""
                break
            }
        }

        var next = [normalizeItem(entry)]
        for (var j = 0; j < items.length; j++) {
            var existing = normalizeItem(items[j])
            if (!existing || existing.filePath === path)
                continue
            next.push(existing)
            if (next.length >= maxItems)
                break
        }

        items = next
        persist()

        if (app.isRecentPath(app.currentPath))
            app.refreshCurrentFolder()
    }

    property Process loadProc: Process {
        command: [
            "python3",
            app.helperPath,
            "merged-recents",
            recent.storagePath,
            recent.launchHistoryPath,
            recent.xbelRecentPath,
            "--limit",
            String(recent.maxItems)
        ]
        running: false
        stdout: SplitParser {
            onRead: data => recent.loadBuffer += data
        }
        onExited: function(code) {
            if (code !== 0) {
                recent.items = []
                return
            }
            try {
                var parsed = JSON.parse(recent.loadBuffer || "[]")
                var normalized = []
                for (var i = 0; i < parsed.length; i++) {
                    var item = recent.normalizeItem(parsed[i])
                    if (item)
                        normalized.push(item)
                }
                recent.items = normalized
                if (app.isRecentPath(app.currentPath))
                    app.refreshCurrentFolder()
            } catch (e) {
                recent.items = []
            }
        }
    }

    property Process saveProc: Process {
        command: []
        running: false
    }
}
