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
        var fileUrl = item.fileUrl || ("file://" + item.filePath)
        var isDir = Boolean(item.fileIsDir)
        var previewUrl = item.filePreviewUrl || ""
        if (!previewUrl && isPreviewablePath(item.filePath, isDir))
            previewUrl = fileUrl
        return {
            fileName: fileName,
            filePath: item.filePath,
            fileUrl: fileUrl,
            fileIsDir: isDir,
            fileHidden: Boolean(item.fileHidden || (fileName.charAt(0) === ".")),
            fileSize: typeof item.fileSize === "number" ? item.fileSize : -1,
            fileModified: item.fileModified || "",
            fileKind: item.fileKind || "",
            filePreviewUrl: previewUrl,
            lastAccessed: typeof item.lastAccessed === "number" ? item.lastAccessed : Date.now()
        }
    }

    function recentModelItems() {
        var normalized = []
        for (var i = 0; i < items.length; i++) {
            var item = normalizeItem(items[i])
            if (item)
                normalized.push(item)
        }
        normalized.sort(function(a, b) { return (b.lastAccessed || 0) - (a.lastAccessed || 0) })
        return normalized
    }

    function persist() {
        saveProc.command = [
            "python3",
            "-c",
            "import json, os, sys, tempfile; path = sys.argv[1]; data = json.loads(sys.argv[2]); os.makedirs(os.path.dirname(path), exist_ok=True); fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix='.finder-recents-', suffix='.json'); os.close(fd); open(tmp, 'w', encoding='utf-8').write(json.dumps(data, ensure_ascii=False)); os.replace(tmp, path)",
            storagePath,
            JSON.stringify(items)
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
            fileUrl: fileUrl || ("file://" + path),
            fileIsDir: Boolean(isDir),
            fileName: path.split("/").pop() || path,
            fileHidden: false,
            fileSize: -1,
            fileModified: "",
            fileKind: "",
            filePreviewUrl: "",
            lastAccessed: Date.now()
        }

        for (var i = 0; i < app.fileModel.count; i++) {
            var modelItem = app.fileModel.get(i)
            if (modelItem.filePath === path) {
                entry.fileName = modelItem.fileName || entry.fileName
                entry.fileUrl = modelItem.fileUrl || entry.fileUrl
                entry.fileIsDir = Boolean(modelItem.fileIsDir)
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

    Component.onCompleted: load()

    property Process loadProc: Process {
        command: [
            "python3",
            "-c",
            "import json, os, sys; path = sys.argv[1]; print(json.dumps(json.load(open(path, encoding='utf-8'))) if os.path.exists(path) else '[]')",
            recent.storagePath
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
