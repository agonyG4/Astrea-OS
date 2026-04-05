pragma Singleton
import Quickshell
import QtQuick 2.15
import QtQml 2.15
import Qt.labs.settings 1.1
import Quickshell.Io

QtObject {
    id: state

    // ── Estado ───────────────────────────────────────────────
    property string currentPath:  ""
    property var    history:      []
    property int    historyIdx:   -1

    property var    tabs:         [{ id: 0, path: "/home/agony", history: ["/home/agony"], historyIdx: 0 }]
    property int    activeTabIndex: 0
    property int    nextTabId:    1

    property string selectedFile: ""
    property var    selectedFiles: []
    property int    lastSelectedIndex: -1
    property bool   showPreview:  false
    property string viewMode:     "list"   // "list" | "icon"
    property string sortField:    "name"
    property bool   sortAsc:      true
    property bool   showHidden:   false
    property bool   foldersFirst: true
    property real   zoomLevel:    1.0
    property var    breadcrumbParts: [{ label: "/", path: "/" }]
    property bool   loadingDir:    false
    property string loadError:     ""
    property bool   previewsEnabled: false
    property bool   dialogActive: false
    property string dialogMode: "browse" // browse | open_file | save_file | select_folder
    readonly property bool isPortalDialog: (Quickshell.env("BENCH_FILE_DIALOG_OPTIONS") || "") !== ""
    property var    dialogFilePatterns: []
    property var    pendingThumbnailWarmRequest: null
    property var    activeThumbnailWarmRequest: null
    property string activeDirectoryRequestPath: ""
    property string activePreviewRefreshPath: ""
    property var    startupWarmQueue: []
    property bool   quickLookCooldown: false
    property bool   pasteConflictVisible: false
    property var    pasteConflictItems: []
    property var    pendingPasteFiles: []
    property string pendingPasteMode: ""
    property string pendingPasteRename: ""
    readonly property string quickLookPathFile: "/tmp/explorer-quicklook-path"
    readonly property string quickLookPidFile: "/tmp/explorer-quicklook.pid"
    readonly property string backendPath: "/home/agony/GitHub/Bench/Explorer/backend/target/release/explorer_backend"
    readonly property real minZoom: 0.75
    readonly property real maxZoom: 1.7
    readonly property real thumbnailZoomThreshold: 1.15
    readonly property var thumbnailColumnStops: [18, 14, 10, 7, 5]
    readonly property var thumbnailScaleStops: [1.0, 1.08, 1.16, 1.26, 1.38]

    property Settings persistedState: Settings {
        fileName: "/home/agony/.config/explorer.conf"
        category: "Explorer"
        property alias currentPath: state.currentPath
        property alias showPreview: state.showPreview
        property alias viewMode: state.viewMode
        property alias sortField: state.sortField
        property alias sortAsc: state.sortAsc
        property alias showHidden: state.showHidden
        property alias foldersFirst: state.foldersFirst
        property alias zoomLevel: state.zoomLevel
    }

    // ── Seleção ──────────────────────────────────────────────
    function isSelected(name) {
        if (!name) return false
        if (selectedFiles.indexOf(name) !== -1) return true
        return name === selectedFile
    }

    function clearSelection() {
        selectedFile = ""
        selectedFiles = []
        lastSelectedIndex = -1
    }

    function isCutPending(name) {
        if (!name || clipboardMode !== "cut") return false
        var fullPath = currentPath + "/" + name
        return clipboardFiles.indexOf(fullPath) !== -1
    }

    function handleSelection(name, index, ctrlMode, shiftMode) {
        if (!ctrlMode && !shiftMode) {
            selectedFile = name
            selectedFiles = [name]
            lastSelectedIndex = index
            return
        }

        if (ctrlMode) {
            var arr = selectedFiles.slice()
            var existingIdx = arr.indexOf(name)
            if (existingIdx !== -1) {
                arr.splice(existingIdx, 1)
                selectedFiles = arr
                if (selectedFile === name) {
                    selectedFile = arr.length > 0 ? arr[arr.length - 1] : ""
                }
            } else {
                arr.push(name)
                selectedFiles = arr
                selectedFile = name
            }
            lastSelectedIndex = index
            return
        }

        if (shiftMode && lastSelectedIndex !== -1 && index !== -1) {
            var min = Math.min(lastSelectedIndex, index)
            var max = Math.max(lastSelectedIndex, index)
            var range = []
            for (var i = min; i <= max; ++i) {
                if (i < fileModel.count)
                    range.push(fileModel.get(i).fileName)
            }
            selectedFiles = range
            selectedFile = name
            return
        }
    }

    // ── Model ────────────────────────────────────────────────
    property ListModel fileModel: ListModel {}

    // ── Navegação & Abas ─────────────────────────────────────
    function _syncTabState() {
        var t = tabs.slice()
        if (activeTabIndex >= 0 && activeTabIndex < t.length) {
            t[activeTabIndex].path = currentPath
            t[activeTabIndex].history = history
            t[activeTabIndex].historyIdx = historyIdx
            tabs = t
        }
    }

    function createTab(initialPath) {
        var path = initialPath || currentPath || "/home/agony"
        var t = tabs.slice()
        t.push({ id: nextTabId++, path: path, history: [path], historyIdx: 0 })
        tabs = t
        switchTab(t.length - 1)
    }

    function closeTab(index) {
        if (tabs.length <= 1) return
        var t = tabs.slice()
        var wasActive = (index === activeTabIndex)
        t.splice(index, 1)
        tabs = t
        
        if (wasActive) {
            var newIdx = Math.min(index, t.length - 1)
            activeTabIndex = -1 // Force change
            switchTab(newIdx)
        } else if (activeTabIndex > index) {
            activeTabIndex--
        }
    }

    function switchTab(index) {
        if (index < 0 || index >= tabs.length || index === activeTabIndex) return
        activeTabIndex = index
        var t = tabs[index]
        history = t.history.slice()
        historyIdx = t.historyIdx
        currentPath = t.path
        clearSelection()
        loadDirectory()
    }

    function navigateTo(path) {
        if (path === currentPath) return
        var newHist = history.slice(0, historyIdx + 1)
        newHist.push(path)
        history = newHist
        historyIdx = newHist.length - 1
        currentPath = path
        _syncTabState()
        clearSelection()
        loadDirectory()
    }

    function goBack()   { if (historyIdx > 0)                    _jump(historyIdx - 1) }
    function goForward(){ if (historyIdx < history.length - 1)   _jump(historyIdx + 1) }
    function _jump(idx) {
        historyIdx = idx
        currentPath = history[idx]
        _syncTabState()
        clearSelection()
        loadDirectory()
    }

    function pathComponents() {
        return breadcrumbParts
    }

    function rebuildBreadcrumbs() {
        var parts = currentPath.split("/").filter(Boolean)
        var result = [{ label: "/", path: "/" }]
        var acc = ""
        for (var i = 0; i < parts.length; i++) {
            acc += "/" + parts[i]
            result.push({ label: parts[i], path: acc })
        }
        breadcrumbParts = result
    }

    function refreshCurrentFolder() {
        if (!currentPath)
            return
        loadDirectory()
    }

    function refreshPreviewMetadata() {
        if (!currentPath || previewRefreshProcess.running)
            return

        activePreviewRefreshPath = currentPath
        previewRefreshProcess.command = [
            backendPath,
            "list",
            activePreviewRefreshPath,
            showHidden ? "1" : "0",
            sortField,
            sortAsc ? "1" : "0",
            foldersFirst ? "1" : "0"
        ]
        previewRefreshProcess.running = false
        previewRefreshProcess.running = true
    }

    function loadDirectory() {
        if (!currentPath)
            return

        loadingDir = true
        loadError = ""
        previewsEnabled = false
        activeDirectoryRequestPath = currentPath
        activePreviewRefreshPath = ""
        fileModel.clear()
        dirListProcess.command = [
            backendPath,
            "list",
            activeDirectoryRequestPath,
            showHidden ? "1" : "0",
            sortField,
            sortAsc ? "1" : "0",
            foldersFirst ? "1" : "0"
        ]
        dirListProcess.running = false
        dirListProcess.running = true
    }

    function replaceFileModel(items) {
        fileModel.clear()
        for (var i = 0; i < items.length; i++) {
            if (fileMatchesDialogFilter(items[i].fileName, items[i].fileIsDir))
                fileModel.append(items[i])
        }
    }

    function selectedItem() {
        if (!selectedFile)
            return null

        for (var i = 0; i < fileModel.count; i++) {
            var item = fileModel.get(i)
            if (item.fileName === selectedFile)
                return item
        }

        return null
    }

    function fileMatchesDialogFilter(fileName, isDir) {
        if (!dialogActive)
            return true

        if (dialogMode === "select_folder")
            return isDir

        if (isDir)
            return true

        if (!dialogFilePatterns || dialogFilePatterns.length === 0)
            return true

        var lowerName = (fileName || "").toLowerCase()
        for (var i = 0; i < dialogFilePatterns.length; i++) {
            var pattern = (dialogFilePatterns[i] || "").toLowerCase()
            if (!pattern || pattern === "*")
                return true
            if (pattern.indexOf("*.") === 0 && lowerName.lastIndexOf(pattern.slice(1)) === lowerName.length - (pattern.length - 1))
                return true
            if (pattern === lowerName)
                return true
        }

        return false
    }

    property var clipboardFiles: []
    property string clipboardMode: "copy"

    function copySelected() {
        if (selectedFiles.length === 0) return
        clipboardFiles = selectedFiles.map(function(name) { return currentPath + "/" + name })
        clipboardMode = "copy"
        console.log("Copiado: " + clipboardFiles.length + " arquivos")
    }

    function cutSelected() {
        if (selectedFiles.length === 0) return
        var newlyCut = selectedFiles.map(function(name) { return currentPath + "/" + name })
        var same = clipboardMode === "cut" && clipboardFiles.length === newlyCut.length && clipboardFiles.every(function(v, i) { return v === newlyCut[i] })
        if (same) {
            clipboardFiles = []
            clipboardMode = ""
            return
        }
        clipboardFiles = newlyCut
        clipboardMode = "cut"
        console.log("Recortado: " + clipboardFiles.length + " arquivos")
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
            "_", currentPath
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
            "_", mode, policy, currentPath, pendingPasteRename
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
        if (selectedFiles.length === 0) return
        var targets = selectedFiles.map(function(name) { return currentPath + "/" + name })
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
        clearSelection()
    }

    function openQuickLook() {
        if (quickLookCooldown)
            return

        var item = selectedItem()
        if (!item || !item.filePath)
            return

        quickLookCooldown = true
        quickLookCooldownTimer.restart()

        quickLookProcess.command = [
            "bash",
            "-lc",
            "pathfile=\"$2\"; pidfile=\"$3\"; selected=\"$1\"; " +
            "if [ -f \"$pidfile\" ] && kill -0 \"$(cat \"$pidfile\" 2>/dev/null)\" >/dev/null 2>&1; then " +
            "  current=$(cat \"$pathfile\" 2>/dev/null); " +
            "  if [ \"$current\" = \"$selected\" ]; then " +
            "    kill \"$(cat \"$pidfile\" 2>/dev/null)\" >/dev/null 2>&1; " +
            "    rm -f \"$pathfile\" \"$pidfile\"; " +
            "  else " +
            "    printf '%s' \"$selected\" > \"$pathfile\"; " +
            "  fi; " +
            "else " +
            "  printf '%s' \"$selected\" > \"$pathfile\"; " +
            "  rm -f \"$pidfile\"; " +
            "  qs -p /home/agony/GitHub/Bench/Look/quicklook.qml >/dev/null 2>&1 & echo $! > \"$pidfile\"; " +
            "fi",
            "--",
            item.filePath,
            quickLookPathFile,
            quickLookPidFile
        ]
        quickLookProcess.running = false
        quickLookProcess.running = true
    }

    function syncQuickLookSelection() {
        var item = selectedItem()
        if (!item || !item.filePath)
            return

        quickLookSyncProcess.command = [
            "bash",
            "-lc",
            "selected=\"$1\"; pidfile=\"$2\"; pathfile=\"$3\"; " +
            "if [ -f \"$pidfile\" ] && kill -0 \"$(cat \"$pidfile\" 2>/dev/null)\" >/dev/null 2>&1; then " +
            "  current=$(cat \"$pathfile\" 2>/dev/null); " +
            "  [ \"$current\" != \"$selected\" ] && printf '%s' \"$selected\" > \"$pathfile\" || true; " +
            "fi",
            "--",
            item.filePath,
            quickLookPidFile,
            quickLookPathFile
        ]
        quickLookSyncProcess.running = false
        quickLookSyncProcess.running = true
    }

    // ── Utilitários ──────────────────────────────────────────
    function fileIconName(fileName, isFolder) {
        if (isFolder) {
            var folderKey = fileName.toLowerCase()
            var folderIcons = {
                "desktop": "user-desktop",
                "área de trabalho": "user-desktop",
                "documentos": "folder-documents",
                "documents": "folder-documents",
                "downloads": "folder-downloads",
                "imagens": "folder-pictures",
                "pictures": "folder-pictures",
                "fotos": "folder-pictures",
                "music": "folder-music",
                "música": "folder-music",
                "musica": "folder-music",
                "videos": "folder-videos",
                "vídeos": "folder-videos",
                "movies": "folder-videos",
                "public": "folder-publicshare",
                "público": "folder-publicshare",
                "publico": "folder-publicshare",
                "templates": "folder-templates",
                "modelos": "folder-templates",
                "trash": "user-trash",
                "lixeira": "user-trash"
            }
            return folderIcons[folderKey] || "inode-directory"
        }
        var ext = fileName.split(".").pop().toLowerCase()
        var map = {
            "pdf":  "application-pdf",          "doc":  "application-msword",
            "docx": "application-msword",        "txt":  "text-plain",
            "md":   "text-x-markdown",
            "xls":  "application-vnd.ms-excel",  "xlsx": "application-vnd.ms-excel",
            "csv":  "text-csv",
            "ppt":  "application-vnd.ms-powerpoint", "pptx": "application-vnd.ms-powerpoint",
            "png":  "image-x-generic",           "jpg":  "image-x-generic",
            "jpeg": "image-x-generic",           "gif":  "image-gif",
            "svg":  "image-svg+xml",             "webp": "image-x-generic",
            "heic": "image-x-generic",           "bmp":  "image-bmp",
            "mp3":  "audio-mpeg",                "flac": "audio-x-flac",
            "wav":  "audio-x-wav",               "aac":  "audio-aac",
            "mp4":  "video-mp4",                 "mov":  "video-quicktime",
            "avi":  "video-x-msvideo",           "mkv":  "video-x-matroska",
            "webm": "video-webm",
            "zip":  "application-zip",           "tar":  "application-x-tar",
            "gz":   "application-gzip",          "rar":  "application-x-rar",
            "7z":   "application-x-7z-compressed",
            "dmg":  "media-optical",             "iso":  "media-optical",
            "sh":   "application-x-shellscript", "py":   "text-x-python",
            "js":   "application-javascript",    "ts":   "text-x-typescript",
            "html": "text-html",                 "css":  "text-css",
            "json": "application-json",          "xml":  "text-xml",
            "qml":  "text-x-qml",
            "ttf":  "font-x-generic",            "otf":  "font-x-generic",
        }
        return map[ext] || "text-x-generic"
    }

    function portalIconSource(iconName, size) {
        function pickSize(availableSizes, requested) {
            for (var i = 0; i < availableSizes.length; ++i) {
                if (requested <= availableSizes[i])
                    return availableSizes[i]
            }
            return availableSizes[availableSizes.length - 1]
        }

        var iconSize = size || 24
        var macTahoe = Quickshell.env("HOME") + "/.local/share/icons/MacTahoe-dark"
        var macTahoePlaces = {
            "user-desktop": "user-desktop.svg",
            "folder-documents": "folder-documents.svg",
            "folder-downloads": "folder-download.svg",
            "folder-pictures": "folder-images.svg",
            "folder-music": "folder-music.svg",
            "folder-videos": "folder-videos.svg",
            "folder-publicshare": "folder-public.svg",
            "folder-templates": "folder-templates.svg",
            "user-trash": "user-trash.svg",
            "network-workgroup": "network-workgroup-symbolic.svg",
            "inode-directory": "folder.svg",
            "folder-home": "folder-home.svg",
            "document-open-recent": "document-open-recent-symbolic.svg"
        }
        var macTahoeActions = {
            "system-search": "system-search.svg",
            "document-open-recent": "document-open-recent.svg"
        }
        var macTahoeDevices = {
            "drive-harddisk": "drive-harddisk.svg",
            "media-optical": "media-optical.svg"
        }
        if (macTahoePlaces[iconName]) {
            var placeName = macTahoePlaces[iconName]
            if (placeName.indexOf("-symbolic.svg") !== -1)
                return "file://" + macTahoe + "/places/symbolic/" + placeName
            if (iconSize > 24)
                return "file://" + macTahoe + "/places/scalable/" + placeName
            return "file://" + macTahoe + "/places/" + pickSize([16, 22, 24], iconSize) + "/" + placeName
        }

        if (macTahoeActions[iconName]) {
            return "file://" + macTahoe + "/actions/" + pickSize([16, 22, 24, 32], iconSize) + "/" + macTahoeActions[iconName]
        }

        if (macTahoeDevices[iconName]) {
            return "file://" + macTahoe + "/devices/" + pickSize([16, 22, 24, 32], iconSize) + "/" + macTahoeDevices[iconName]
        }

        return "file://" + macTahoe + "/mimes/scalable/" + iconName + ".svg"
    }

    function isPreviewableFile(fileName, isDir) {
        if (isDir || !fileName)
            return false

        var dotIndex = fileName.lastIndexOf(".")
        if (dotIndex <= 0 || dotIndex === fileName.length - 1)
            return false

        var ext = fileName.slice(dotIndex + 1).toLowerCase()
        return ["jpg", "jpeg", "png", "gif", "bmp", "webp", "svg"].indexOf(ext) !== -1
    }

    function requestThumbnailWarm(path, offset, limit) {
        if (!path)
            return

        pendingThumbnailWarmRequest = {
            path: path,
            showHidden: showHidden ? "1" : "0",
            sortField: sortField,
            sortAsc: sortAsc ? "1" : "0",
            foldersFirst: foldersFirst ? "1" : "0",
            offset: String(Math.max(0, offset || 0)),
            limit: String(Math.max(1, limit || 12))
        }
        if (!thumbnailWarmProcess.running)
            thumbnailWarmDebounce.restart()
    }

    function startThumbnailWarm(request) {
        if (!request)
            return

        activeThumbnailWarmRequest = request
        pendingThumbnailWarmRequest = null
        thumbnailWarmProcess.command = [
            backendPath,
            "warm-thumbnails",
            request.path,
            request.showHidden,
            request.sortField,
            request.sortAsc,
            request.foldersFirst,
            request.offset,
            request.limit
        ]
        thumbnailWarmProcess.running = false
        thumbnailWarmProcess.running = true
    }

    function warmCurrentDirectoryThumbnails() {
        if (!currentPath)
            return

        requestThumbnailWarm(currentPath, 0, viewMode === "icon" ? 18 : 24)
    }

    function scheduleVisibleThumbnailWarm(firstIndex, lastIndex) {
        if (!currentPath || loadingDir)
            return

        if (firstIndex < 0 || lastIndex < firstIndex)
            return

        requestThumbnailWarm(currentPath, firstIndex, Math.max(8, lastIndex - firstIndex + 1))
    }

    function enqueueStartupWarm(path, limit) {
        if (!path || path === currentPath)
            return

        for (var i = 0; i < startupWarmQueue.length; i++) {
            if (startupWarmQueue[i].path === path)
                return
        }

        startupWarmQueue.push({ path: path, limit: String(limit) })
        if (!startupWarmTimer.running)
            startupWarmTimer.start()
    }

    function scheduleHomeThumbnailWarmup() {
        startupWarmQueue = []
        enqueueStartupWarm("/home/agony", 8)
        enqueueStartupWarm("/home/agony/Downloads", 10)
        enqueueStartupWarm("/home/agony/Imagens", 10)
        enqueueStartupWarm("/home/agony/Documentos", 6)
    }

    function formatSize(bytes) {
        if (bytes < 0)          return "—"
        if (bytes < 1024)       return bytes + " B"
        if (bytes < 1048576)    return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MB"
        return (bytes / 1073741824).toFixed(2) + " GB"
    }

    function formatDate(date) {
        if (!date) return "—"
        if (typeof date === "number")
            date = new Date(date)
        var diff = (new Date() - date) / 1000
        if (diff < 60)     return "Agora"
        if (diff < 3600)   return Math.floor(diff / 60) + " min atrás"
        if (diff < 86400)  return "Hoje, " + Qt.formatTime(date, "hh:mm")
        if (diff < 172800) return "Ontem"
        return Qt.formatDate(date, "d MMM yyyy")
    }

    function itemColor(name, hovered) {
        if (isSelected(name)) return Theme.selected
        return hovered ? Theme.hover : "transparent"
    }

    function setZoom(level) {
        zoomLevel = Math.max(minZoom, Math.min(maxZoom, Math.round(level * 100) / 100))
        syncViewModeWithZoom()
    }

    function increaseZoom() {
        setZoom(zoomLevel + 0.1)
    }

    function decreaseZoom() {
        setZoom(zoomLevel - 0.1)
    }

    function resetZoom() {
        zoomLevel = 1.0
        syncViewModeWithZoom()
    }

    function syncViewModeWithZoom() {
        viewMode = zoomLevel >= thumbnailZoomThreshold ? "icon" : "list"
    }

    function thumbnailLevel() {
        if (zoomLevel < 1.25) return 0
        if (zoomLevel < 1.35) return 1
        if (zoomLevel < 1.45) return 2
        if (zoomLevel < 1.55) return 3
        return 4
    }

    function thumbnailColumnCount() {
        return thumbnailColumnStops[thumbnailLevel()]
    }

    function thumbnailScale() {
        return thumbnailScaleStops[thumbnailLevel()]
    }

    function openItem(path, isDir, fileUrl) {
        if (isDir) {
            navigateTo(path)
            return
        }
        if (dialogActive && (dialogMode === "open_file" || dialogMode === "save_file")) {
            dialogFileActivated(path, fileUrl)
            return
        }
        Qt.openUrlExternally(fileUrl)
    }

    signal dialogFileActivated(string path, string fileUrl)

    onCurrentPathChanged: rebuildBreadcrumbs()
    onSortFieldChanged: if (currentPath !== "") loadDirectory()
    onSortAscChanged: if (currentPath !== "") loadDirectory()
    onShowHiddenChanged: if (currentPath !== "") loadDirectory()
    onFoldersFirstChanged: if (currentPath !== "") loadDirectory()
    onSelectedFileChanged: syncQuickLookSelection()
    property Process dirListProcess: Process {
        id: dirListProcess
        command: []
        running: false
        stdout: StdioCollector {
            id: dirListStdout
            onStreamFinished: {
                if (state.activeDirectoryRequestPath !== state.currentPath)
                    return

                try {
                    state.replaceFileModel(JSON.parse(this.text))
                    state.loadError = ""
                } catch (error) {
                    state.fileModel.clear()
                    state.loadError = "Erro ao carregar diretório"
                }
                state.loadingDir = false
                if (state.loadError === "")
                    state.previewsEnabled = true
                if (state.loadError === "" && state.previewsEnabled && !state.isPortalDialog)
                    state.warmCurrentDirectoryThumbnails()
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0 && dirListStdout.text.trim() === "") {
                state.fileModel.clear()
                state.loadError = "Erro ao carregar diretório"
                state.loadingDir = false
                state.previewsEnabled = false
            }
        }
    }

    property Process previewRefreshProcess: Process {
        command: []
        running: false
        stdout: StdioCollector {
            id: previewRefreshStdout
            onStreamFinished: {
                if (state.activePreviewRefreshPath !== state.currentPath || state.loadingDir)
                    return

                try {
                    state.replaceFileModel(JSON.parse(this.text))
                } catch (error) {
                }
            }
        }
    }

    property Timer thumbnailWarmDebounce: Timer {
        interval: 80
        repeat: false
        onTriggered: {
            if (state.pendingThumbnailWarmRequest && !state.thumbnailWarmProcess.running)
                state.startThumbnailWarm(state.pendingThumbnailWarmRequest)
        }
    }

    property Timer startupWarmTimer: Timer {
        interval: 350
        repeat: true
        running: false
        onTriggered: {
            if (state.thumbnailWarmProcess.running || state.startupWarmQueue.length === 0) {
                if (state.startupWarmQueue.length === 0)
                    stop()
                return
            }

            var request = state.startupWarmQueue.shift()
            state.startThumbnailWarm({
                path: request.path,
                showHidden: "0",
                sortField: "name",
                sortAsc: "1",
                foldersFirst: "1",
                offset: "0",
                limit: request.limit
            })
        }
    }

    property Process thumbnailWarmProcess: Process {
        command: []
        running: false
        stdout: StdioCollector {
            id: thumbnailWarmStdout
        }
        onExited: function(exitCode) {
            var warmedCount = parseInt(thumbnailWarmStdout.text.trim(), 10)
            var activeRequest = state.activeThumbnailWarmRequest
            if (exitCode === 0
                    && activeRequest
                    && activeRequest.path === state.currentPath
                    && !isNaN(warmedCount)
                    && warmedCount > 0)
                state.refreshPreviewMetadata()

            state.activeThumbnailWarmRequest = null

            if (state.pendingThumbnailWarmRequest)
                state.thumbnailWarmDebounce.restart()
            if (!state.startupWarmTimer.running && state.startupWarmQueue.length > 0)
                state.startupWarmTimer.start()
        }
    }

    property Process quickLookProcess: Process {
        command: []
        running: false
    }

    property Process quickLookSyncProcess: Process {
        command: []
        running: false
    }

    property Timer quickLookCooldownTimer: Timer {
        interval: 220
        repeat: false
        onTriggered: state.quickLookCooldown = false
    }

    property Process pasteProcess: Process {
        command: []
        running: false
        onExited: function(exitCode) {
            state.refreshCurrentFolder()
        }
    }

    property Process conflictScanProcess: Process {
        command: []
        running: false
        stdout: StdioCollector {
            id: conflictScanStdout
            onStreamFinished: {
                var items = text.split("\n").map(function(line) { return line.trim() }).filter(Boolean)
                state.pasteConflictItems = items
                if (items.length > 0) {
                    state.pendingPasteRename = items.length === 1 ? items[0] : ""
                    state.pasteConflictVisible = true
                } else {
                    state.executePaste("keep-both")
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0 && conflictScanStdout.text.trim() === "") {
                state.pendingPasteFiles = []
                state.pendingPasteMode = ""
                state.pendingPasteRename = ""
            }
        }
    }

    property Process deleteProcess: Process {
        command: []
        running: false
        onExited: function(exitCode) {
            state.refreshCurrentFolder()
        }
    }
}
