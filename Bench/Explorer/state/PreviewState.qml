import Quickshell
import QtQuick 2.15
import Quickshell.Io

QtObject {
    id: preview

    property QtObject app
    property bool showPreview: false
    property string viewMode: "list"
    property bool previewsEnabled: false
    property var pendingThumbnailWarmRequest: null
    property var activeThumbnailWarmRequest: null
    property string activePreviewRefreshPath: ""
    property var startupWarmQueue: []
    property bool quickLookCooldown: false
    property real zoomLevel: 1.0
    property int currentFolderWarmOffset: -1
    property int currentFolderWarmChunkSize: 24

    function clearCurrentFolderWarm() {
        currentFolderWarmOffset = -1
        currentFolderWarmTimer.stop()
    }

    function beginCurrentFolderWarm() {
        if (!app.currentPath || app.loadingDir || app.searchActive || app.fileModel.count <= 0)
            return
        requestThumbnailWarm(app.currentPath, 0, viewMode === "icon" ? 18 : 24)
        currentFolderWarmOffset = viewMode === "icon" ? 18 : 24
        currentFolderWarmChunkSize = viewMode === "icon" ? 18 : 24
        currentFolderWarmTimer.restart()
    }

    function queueNextCurrentFolderWarmChunk() {
        if (!app.currentPath || app.loadingDir || app.searchActive || currentFolderWarmOffset < 0)
            return
        if (currentFolderWarmOffset >= app.fileModel.count) {
            clearCurrentFolderWarm()
            return
        }
        requestThumbnailWarm(app.currentPath, currentFolderWarmOffset, currentFolderWarmChunkSize)
        currentFolderWarmOffset += currentFolderWarmChunkSize
    }

    property Timer currentFolderWarmTimer: Timer {
        interval: 140
        repeat: false
        onTriggered: preview.queueNextCurrentFolderWarmChunk()
    }

    property Connections appConnections: Connections {
        target: app
        function onCurrentPathChanged() { preview.clearCurrentFolderWarm() }
        function onSortFieldChanged() { preview.clearCurrentFolderWarm() }
        function onSortAscChanged() { preview.clearCurrentFolderWarm() }
        function onShowHiddenChanged() { preview.clearCurrentFolderWarm() }
        function onFoldersFirstChanged() { preview.clearCurrentFolderWarm() }
        function onViewModeChanged() {
            preview.clearCurrentFolderWarm()
            if (app.currentPath && !app.loadingDir && !app.searchActive)
                preview.beginCurrentFolderWarm()
        }
        function onLoadingDirChanged() {
            if (app.loadingDir)
                preview.clearCurrentFolderWarm()
            else if (app.currentPath && !app.searchActive)
                preview.beginCurrentFolderWarm()
        }
        function onSearchActiveChanged() {
            if (app.searchActive)
                preview.clearCurrentFolderWarm()
        }
    }


    function refreshPreviewMetadata() {
        if (!app.currentPath || previewRefreshProcess.running || app.searchActive)
            return

        activePreviewRefreshPath = app.currentPath
        previewRefreshProcess.command = [
            app.backendPath,
            "list",
            activePreviewRefreshPath,
            app.showHidden ? "1" : "0",
            app.sortField,
            app.sortAsc ? "1" : "0",
            app.foldersFirst ? "1" : "0"
        ]
        previewRefreshProcess.running = false
        previewRefreshProcess.running = true
    }

    function openQuickLook() {
        if (quickLookCooldown)
            return

        var item = app.selectedItem()
        if (!item || !item.filePath)
            return

        quickLookCooldown = true
        quickLookCooldownTimer.restart()

        quickLookProcess.command = [
            "bash", "-lc",
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
            "--", item.filePath, app.quickLookPathFile, app.quickLookPidFile
        ]
        quickLookProcess.running = false
        quickLookProcess.running = true
    }

    function syncQuickLookSelection() {
        var item = app.selectedItem()
        if (!item || !item.filePath)
            return

        quickLookSyncProcess.command = [
            "bash", "-lc",
            "selected=\"$1\"; pidfile=\"$2\"; pathfile=\"$3\"; " +
            "if [ -f \"$pidfile\" ] && kill -0 \"$(cat \"$pidfile\" 2>/dev/null)\" >/dev/null 2>&1; then " +
            "  current=$(cat \"$pathfile\" 2>/dev/null); " +
            "  [ \"$current\" != \"$selected\" ] && printf '%s' \"$selected\" > \"$pathfile\" || true; " +
            "fi",
            "--", item.filePath, app.quickLookPidFile, app.quickLookPathFile
        ]
        quickLookSyncProcess.running = false
        quickLookSyncProcess.running = true
    }

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
            "pdf": "application-pdf", "doc": "application-msword",
            "docx": "application-msword", "txt": "text-plain",
            "md": "text-x-markdown",
            "xls": "application-vnd.ms-excel", "xlsx": "application-vnd.ms-excel",
            "csv": "text-csv",
            "ppt": "application-vnd.ms-powerpoint", "pptx": "application-vnd.ms-powerpoint",
            "png": "image-x-generic", "jpg": "image-x-generic",
            "jpeg": "image-x-generic", "gif": "image-gif",
            "svg": "image-svg+xml", "webp": "image-x-generic",
            "heic": "image-x-generic", "bmp": "image-bmp",
            "mp3": "audio-mpeg", "flac": "audio-x-flac",
            "wav": "audio-x-wav", "aac": "audio-aac",
            "mp4": "video-mp4", "mov": "video-quicktime",
            "avi": "video-x-msvideo", "mkv": "video-x-matroska",
            "webm": "video-webm",
            "zip": "application-zip", "tar": "application-x-tar",
            "gz": "application-gzip", "rar": "application-x-rar",
            "7z": "application-x-7z-compressed",
            "dmg": "media-optical", "iso": "media-optical",
            "sh": "application-x-shellscript", "py": "text-x-python",
            "js": "application-javascript", "ts": "text-x-typescript",
            "html": "text-html", "css": "text-css",
            "json": "application-json", "xml": "text-xml",
            "qml": "text-x-qml",
            "ttf": "font-x-generic", "otf": "font-x-generic"
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
            "drive-removable-media": "drive-removable-media.svg",
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

        if (macTahoeActions[iconName])
            return "file://" + macTahoe + "/actions/" + pickSize([16, 22, 24, 32], iconSize) + "/" + macTahoeActions[iconName]

        if (macTahoeDevices[iconName])
            return "file://" + macTahoe + "/devices/" + pickSize([16, 22, 24, 32], iconSize) + "/" + macTahoeDevices[iconName]

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
            showHidden: app.showHidden ? "1" : "0",
            sortField: app.sortField,
            sortAsc: app.sortAsc ? "1" : "0",
            foldersFirst: app.foldersFirst ? "1" : "0",
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
            app.backendPath,
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
        if (!app.currentPath || app.searchActive)
            return
        requestThumbnailWarm(app.currentPath, 0, viewMode === "icon" ? 18 : 24)
    }

    function scheduleVisibleThumbnailWarm(firstIndex, lastIndex) {
        if (!app.currentPath || app.loadingDir)
            return
        if (firstIndex < 0 || lastIndex < firstIndex)
            return
        requestThumbnailWarm(app.currentPath, firstIndex, Math.max(8, lastIndex - firstIndex + 1))
    }

    function enqueueStartupWarm(path, limit) {
        if (!path || path === app.currentPath)
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
        if (bytes < 0) return "—"
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MB"
        return (bytes / 1073741824).toFixed(2) + " GB"
    }

    function formatDate(date) {
        if (!date) return "—"
        if (typeof date === "number")
            date = new Date(date)
        var diff = (new Date() - date) / 1000
        if (diff < 60) return "Agora"
        if (diff < 3600) return Math.floor(diff / 60) + " min atrás"
        if (diff < 86400) return "Hoje, " + Qt.formatTime(date, "hh:mm")
        if (diff < 172800) return "Ontem"
        return Qt.formatDate(date, "d MMM yyyy")
    }

    function itemColor(name, hovered) {
        if (app.isSelected(name)) return app.themeSelected
        return hovered ? app.themeHover : "transparent"
    }

    function setZoom(level) {
        zoomLevel = Math.max(app.minZoom, Math.min(app.maxZoom, Math.round(level * 100) / 100))
        syncViewModeWithZoom()
    }

    function increaseZoom() { setZoom(zoomLevel + 0.1) }
    function decreaseZoom() { setZoom(zoomLevel - 0.1) }

    function resetZoom() {
        zoomLevel = 1.0
        syncViewModeWithZoom()
    }

    function syncViewModeWithZoom() {
        viewMode = zoomLevel >= app.thumbnailZoomThreshold ? "icon" : "list"
    }

    function thumbnailLevel() {
        if (zoomLevel < 1.25) return 0
        if (zoomLevel < 1.35) return 1
        if (zoomLevel < 1.45) return 2
        if (zoomLevel < 1.55) return 3
        return 4
    }

    function thumbnailColumnCount() {
        return app.thumbnailColumnStops[thumbnailLevel()]
    }

    function thumbnailScale() {
        return app.thumbnailScaleStops[thumbnailLevel()]
    }

    function openItem(path, isDir, fileUrl) {
        if (isDir) {
            app.navigateTo(path)
            return
        }
        if (app.dialogActive && (app.dialogMode === "open_file" || app.dialogMode === "save_file")) {
            app.dialogFileActivated(path, fileUrl)
            return
        }
        Qt.openUrlExternally(fileUrl)
    }

    property Process previewRefreshProcess: Process {
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (preview.activePreviewRefreshPath !== app.currentPath || app.loadingDir)
                    return
                try {
                    app.updateFileModelMetadata(JSON.parse(this.text))
                } catch (error) {
                }
            }
        }
    }

    property Timer previewRefreshDebounce: Timer {
        interval: 220
        repeat: false
        onTriggered: preview.refreshPreviewMetadata()
    }

    property Timer thumbnailWarmDebounce: Timer {
        interval: 80
        repeat: false
        onTriggered: {
            if (preview.pendingThumbnailWarmRequest && !preview.thumbnailWarmProcess.running)
                preview.startThumbnailWarm(preview.pendingThumbnailWarmRequest)
        }
    }

    property Timer startupWarmTimer: Timer {
        interval: 350
        repeat: true
        running: false
        onTriggered: {
            if (preview.thumbnailWarmProcess.running || preview.startupWarmQueue.length === 0) {
                if (preview.startupWarmQueue.length === 0)
                    stop()
                return
            }
            var request = preview.startupWarmQueue.shift()
            preview.startThumbnailWarm({
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
        stdout: StdioCollector { id: thumbnailWarmStdout }
        onExited: function(exitCode) {
            var warmedCount = parseInt(thumbnailWarmStdout.text.trim(), 10)
            var activeRequest = preview.activeThumbnailWarmRequest
            if (exitCode === 0
                    && activeRequest
                    && activeRequest.path === app.currentPath
                    && !isNaN(warmedCount)
                    && warmedCount > 0)
                preview.previewRefreshDebounce.restart()

            preview.activeThumbnailWarmRequest = null

            if (preview.pendingThumbnailWarmRequest)
                preview.thumbnailWarmDebounce.restart()
            else if (preview.currentFolderWarmOffset >= 0)
                preview.currentFolderWarmTimer.restart()
            if (!preview.startupWarmTimer.running && preview.startupWarmQueue.length > 0)
                preview.startupWarmTimer.start()
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
        onTriggered: preview.quickLookCooldown = false
    }
}
