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
    property bool startupWorkEnabled: false
    property real zoomLevel: 1.0
    property int currentFolderWarmOffset: -1
    property int currentFolderWarmChunkSize: 24
    property var retryThumbnailWarmRequest: null

    function clearCurrentFolderWarm() {
        currentFolderWarmOffset = -1
        currentFolderWarmTimer.stop()
        retryThumbnailWarmRequest = null
        thumbnailWarmRetryTimer.stop()
    }

    function beginCurrentFolderWarm() {
        if (!startupWorkEnabled || !app.currentPath || app.remoteDirectoryActive || app.loadingDir || app.searchActive || app.isRecentPath(app.currentPath) || app.fileModel.count <= 0)
            return
        var initialLimit = viewMode === "icon" ? 18 : 24
        requestThumbnailWarm(app.currentPath, 0, initialLimit)
        currentFolderWarmOffset = initialLimit
        currentFolderWarmChunkSize = initialLimit
        currentFolderWarmTimer.restart()
    }

    function queueNextCurrentFolderWarmChunk() {
        if (!app.currentPath || app.remoteDirectoryActive || app.loadingDir || app.searchActive || app.isRecentPath(app.currentPath) || currentFolderWarmOffset < 0)
            return
        if (currentFolderWarmOffset >= app.fileModel.count) {
            clearCurrentFolderWarm()
            return
        }
        if (currentFolderWarmOffset >= 96) {
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
            if (app.currentPath && !app.remoteDirectoryActive && !app.loadingDir && !app.searchActive)
                preview.beginCurrentFolderWarm()
        }
        function onLoadingDirChanged() {
            if (app.loadingDir)
                preview.clearCurrentFolderWarm()
            else if (app.currentPath && !app.remoteDirectoryActive && !app.searchActive)
                preview.beginCurrentFolderWarm()
        }
        function onSearchActiveChanged() {
            if (app.searchActive)
                preview.clearCurrentFolderWarm()
        }
        function onRemoteDirectoryActiveChanged() {
            if (app.remoteDirectoryActive)
                preview.clearCurrentFolderWarm()
            else if (app.currentPath && !app.loadingDir && !app.searchActive)
                preview.beginCurrentFolderWarm()
        }
    }


    function refreshPreviewMetadata() {
        if (!startupWorkEnabled || !app.currentPath || app.remoteDirectoryActive || previewRefreshProcess.running || app.searchActive || app.isRecentPath(app.currentPath))
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

    function fileIconName(fileName, isFolder, isExecutable) {
        if (isFolder) {
            var folderKey = fileName.toLowerCase()
            var folderIcons = {
                "desktop": "user-desktop",
                "área de trabalho": "user-desktop",
                "home": "user-home",
                "pasta pessoal": "user-home",
                "documentos": "folder-documents",
                "documents": "folder-documents",
                "downloads": "folder-download",
                "download": "folder-download",
                "imagens": "folder-images",
                "pictures": "folder-images",
                "fotos": "folder-images",
                "photos": "folder-images",
                "images": "folder-images",
                "music": "folder-music",
                "música": "folder-music",
                "musica": "folder-music",
                "vídeos": "folder-videos",
                "videos": "folder-videos",
                "vídeos": "folder-videos",
                "movies": "folder-videos",
                "public": "folder-public",
                "público": "folder-public",
                "publico": "folder-public",
                "templates": "folder-templates",
                "modelos": "folder-templates",
                "github": "folder-github",
                "git": "folder-git",
                "gitlab": "folder-gitlab",
                "games": "folder-games",
                "jogos": "folder-games",
                "steam": "folder-steam",
                "projects": "folder-projects",
                "projetos": "folder-projects",
                "development": "folder-development",
                "desenvolvimento": "folder-development",
                "scripts": "folder-script",
                "script": "folder-script",
                "code": "folder-code",
                "src": "folder-code",
                "source": "folder-code",
                "backup": "folder-build",
                "backups": "folder-build",
                "build": "folder-build",
                "dist": "folder-build",
                "out": "folder-build",
                "target": "folder-build",
                "tmp": "folder-temp",
                "temp": "folder-temp",
                "cache": "folder-temp",
                "logs": "folder-log",
                "log": "folder-log",
                "docker": "folder-docker",
                "android": "folder-android",
                "java": "folder-java",
                "html": "folder-html",
                "www": "folder-html",
                "web": "folder-html",
                "cloud": "folder-cloud",
                "dropbox": "folder-dropbox",
                "gdrive": "folder-gdrive",
                "drive": "folder-cloud",
                "torrent": "folder-torrent",
                "vbox": "folder-vbox",
                "virtualbox": "folder-vbox",
                "wine": "folder-wine",
                "flatpak": "folder-flatpak",
                "appimage": "folder-appimage",
                "extensions": "folder-extension",
                "extension": "folder-extension",
                "database": "folder-database",
                "db": "folder-database",
                "design": "folder-design",
                "drawing": "folder-drawing",
                "paint": "folder-paint",
                "presentation": "folder-presentation",
                "slides": "folder-presentation",
                "table": "folder-table",
                "spreadsheet": "folder-table",
                "bookmark": "folder-bookmark",
                "bookmarks": "folder-bookmark",
                "book": "folder-book",
                "books": "folder-book",
                "notes": "folder-notes",
                "nota": "folder-notes",
                "notas": "folder-notes",
                "mail": "folder-mail",
                "podcasts": "folder-podcast",
                "podcast": "folder-podcast",
                "library": "folder-library",
                "biblioteca": "folder-library",
                "important": "folder-important",
                "importante": "folder-important",
                "root": "folder-root",
                "trash": "user-trash",
                "lixeira": "user-trash"
            }
            if (folderIcons[folderKey])
                return folderIcons[folderKey]

            var containsRules = [
                { terms: ["github"], icon: "folder-github" },
                { terms: ["gitlab"], icon: "folder-gitlab" },
                { terms: ["steam"], icon: "folder-steam" },
                { terms: ["game", "games", "jogo", "jogos"], icon: "folder-games" },
                { terms: ["project", "projects", "projeto", "projetos"], icon: "folder-projects" },
                { terms: ["dev", "development", "desenvolvimento"], icon: "folder-development" },
                { terms: ["script", "scripts"], icon: "folder-script" },
                { terms: ["code", "src", "source", "repo"], icon: "folder-code" },
                { terms: ["build", "dist", "target", "backup"], icon: "folder-build" },
                { terms: ["temp", "tmp", "cache"], icon: "folder-temp" },
                { terms: ["log", "logs"], icon: "folder-log" },
                { terms: ["docker"], icon: "folder-docker" },
                { terms: ["android"], icon: "folder-android" },
                { terms: ["java"], icon: "folder-java" },
                { terms: ["html", "web", "www"], icon: "folder-html" },
                { terms: ["cloud", "drive"], icon: "folder-cloud" },
                { terms: ["dropbox"], icon: "folder-dropbox" },
                { terms: ["gdrive"], icon: "folder-gdrive" },
                { terms: ["torrent"], icon: "folder-torrent" },
                { terms: ["vbox", "virtualbox", "vm"], icon: "folder-vbox" },
                { terms: ["wine"], icon: "folder-wine" },
                { terms: ["flatpak"], icon: "folder-flatpak" },
                { terms: ["appimage"], icon: "folder-appimage" },
                { terms: ["extension", "extensions", "plugin", "plugins"], icon: "folder-extension" },
                { terms: ["database", "db", "sql"], icon: "folder-database" },
                { terms: ["design", "ui", "ux"], icon: "folder-design" },
                { terms: ["draw", "drawing", "paint", "art"], icon: "folder-drawing" },
                { terms: ["presentation", "slides"], icon: "folder-presentation" },
                { terms: ["table", "sheet", "spreadsheet"], icon: "folder-table" },
                { terms: ["bookmark", "bookmarks"], icon: "folder-bookmark" },
                { terms: ["book", "books", "ebook"], icon: "folder-book" },
                { terms: ["note", "notes", "nota", "notas"], icon: "folder-notes" },
                { terms: ["mail", "email"], icon: "folder-mail" },
                { terms: ["podcast", "podcasts"], icon: "folder-podcast" },
                { terms: ["library", "biblioteca"], icon: "folder-library" },
                { terms: ["important", "importante"], icon: "folder-important" }
            ]
            for (var i = 0; i < containsRules.length; i++) {
                var rule = containsRules[i]
                for (var j = 0; j < rule.terms.length; j++) {
                    if (folderKey.indexOf(rule.terms[j]) !== -1)
                        return rule.icon
                }
            }

            return "inode-directory"
        }

        if (isExecutable)
            return "application-x-executable"

        var lowerName = fileName.toLowerCase()
        var ext = fileName.split(".").pop().toLowerCase()
        var map = {
            "pdf": "application-pdf", "doc": "application-vnd.ms-word",
            "docx": "x-office-document",
            "odt": "libreoffice-oasis-text",
            "rtf": "application-rtf",
            "txt": "text-plain", "log": "text-plain",
            "md": "text-markdown",
            "xls": "application-vnd.ms-excel",
            "xlsx": "x-office-spreadsheet",
            "ods": "libreoffice-oasis-spreadsheet",
            "csv": "text-csv",
            "ppt": "application-vnd.ms-powerpoint",
            "pptx": "x-office-presentation",
            "odp": "libreoffice-oasis-presentation",
            "png": "image-png", "jpg": "application-image-jpg",
            "jpeg": "application-image-jpg", "gif": "application-image-gif",
            "svg": "image-svg+xml", "webp": "image-webp",
            "heic": "image-x-generic", "bmp": "application-image-bmp",
            "ico": "application-image-ico", "tif": "application-image-tiff",
            "tiff": "application-image-tiff", "xcf": "image-x-compressed-xcf",
            "psd": "application-photoshop", "ai": "application-illustrator",
            "mp3": "audio-x-generic", "flac": "audio-x-generic",
            "wav": "audio-x-generic", "aac": "audio-x-generic",
            "ogg": "audio-x-generic", "m4a": "audio-x-generic",
            "mid": "audio-midi", "midi": "audio-midi",
            "mp4": "video-x-generic", "mov": "video-x-generic",
            "avi": "video-x-generic", "mkv": "video-x-generic",
            "webm": "video-webm", "m4v": "video-x-generic",
            "zip": "application-x-zip", "tar": "application-x-tar",
            "gz": "application-x-gzip", "rar": "application-x-rar",
            "7z": "application-7zip",
            "bz2": "application-x-bzip", "xz": "application-x-lzma-compressed-tar",
            "zst": "application-zstd", "deb": "application-x-deb",
            "rpm": "application-x-rpm", "pkg": "package-x-generic",
            "dmg": "media-optical", "iso": "media-optical",
            "sh": "text-x-script", "bash": "text-x-script", "zsh": "text-x-script", "fish": "text-x-script",
            "py": "text-x-python",
            "js": "text-x-javascript", "mjs": "text-x-javascript", "cjs": "text-x-javascript",
            "ts": "text-x-typescript", "tsx": "text-x-typescript",
            "jsx": "text-x-javascript",
            "html": "text-html", "htm": "text-html", "css": "text-css", "scss": "text-x-sass",
            "sass": "text-x-sass", "less": "text-less",
            "json": "application-json", "xml": "text-xml", "yaml": "application-yaml", "yml": "application-yaml",
            "toml": "application-toml", "sql": "application-sql",
            "qml": "text-x-qml",
            "rs": "text-rust",
            "c": "text-x-c", "h": "text-x-chdr",
            "cpp": "text-x-c++src", "cc": "text-x-c++src", "cxx": "text-x-c++src",
            "hpp": "text-x-c++hdr", "hh": "text-x-c++hdr", "hxx": "text-x-c++hdr",
            "java": "text-x-java",
            "go": "text-x-go",
            "php": "text-x-php",
            "rb": "text-x-ruby",
            "swift": "text-x-generic",
            "kt": "text-x-kotlin",
            "lua": "text-x-lua", "cs": "text-x-csharp",
            "tex": "text-x-tex", "patch": "text-x-patch",
            "desktop": "application-x-desktop",
            "exe": "application-x-ms-dos-executable", "msi": "application-x-msdownload",
            "appimage": "application-vnd.appimage", "flatpak": "application-vnd.flatpak",
            "torrent": "application-x-bittorrent",
            "ttf": "font-x-generic", "otf": "font-x-generic"
        }
        if (lowerName === "dockerfile")
            return "text-dockerfile"
        if (lowerName === "makefile")
            return "text-x-makefile"
        if (map[ext])
            return map[ext]
        return ext === fileName.toLowerCase() ? "unknown" : "text-x-generic"
    }

    function themedIconSource(iconName, size, themeName) {
        if (!iconName)
            iconName = "unknown"

        function pickSize(availableSizes, requested) {
            for (var i = 0; i < availableSizes.length; ++i) {
                if (requested <= availableSizes[i])
                    return availableSizes[i]
            }
            return availableSizes[availableSizes.length - 1]
        }

        var iconSize = size || 24
        var macTahoe = Quickshell.env("HOME") + "/.local/share/icons/" + themeName
        var macTahoePlaces = {
            "user-desktop": "user-desktop.svg",
            "user-home": "folder-home.svg",
            "folder-documents": "folder-documents.svg",
            "folder-downloads": "folder-download.svg",
            "folder-download": "folder-download.svg",
            "folder-pictures": "folder-images.svg",
            "folder-images": "folder-images.svg",
            "folder-music": "folder-music.svg",
            "folder-videos": "folder-videos.svg",
            "folder-publicshare": "folder-public.svg",
            "folder-public": "folder-public.svg",
            "folder-templates": "folder-templates.svg",
            "folder-code": "folder-code.svg",
            "folder-games": "folder-games.svg",
            "folder-git": "folder-git.svg",
            "folder-github": "folder-github.svg",
            "folder-gitlab": "folder-gitlab.svg",
            "folder-steam": "folder-steam.svg",
            "folder-script": "folder-script.svg",
            "folder-projects": "folder-projects.svg",
            "folder-development": "folder-development.svg",
            "folder-build": "folder-build.svg",
            "folder-cloud": "folder-cloud.svg",
            "folder-dropbox": "folder-dropbox.svg",
            "folder-gdrive": "folder-gdrive.svg",
            "folder-html": "folder-html.svg",
            "folder-temp": "folder-temp.svg",
            "folder-log": "folder-log.svg",
            "folder-root": "folder-root.svg",
            "folder-torrent": "folder-torrent.svg",
            "folder-vbox": "folder-vbox.svg",
            "folder-wine": "folder-wine.svg",
            "folder-docker": "folder-docker.svg",
            "folder-android": "folder-android.svg",
            "folder-java": "folder-java.svg",
            "folder-flatpak": "folder-flatpak.svg",
            "folder-appimage": "folder-appimage.svg",
            "folder-extension": "folder-extension.svg",
            "folder-database": "folder-database.svg",
            "folder-design": "folder-design.svg",
            "folder-drawing": "folder-drawing.svg",
            "folder-paint": "folder-paint.svg",
            "folder-presentation": "folder-presentation.svg",
            "folder-table": "folder-table.svg",
            "folder-bookmark": "folder-bookmark.svg",
            "folder-book": "folder-book.svg",
            "folder-notes": "folder-notes.svg",
            "folder-mail": "folder-mail.svg",
            "folder-podcast": "folder-podcast.svg",
            "folder-library": "folder-library.svg",
            "folder-important": "folder-important.svg",
            "user-trash": "user-trash.svg",
            "network-workgroup": "network-workgroup-symbolic.svg",
            "inode-directory": "folder.svg",
            "document-open-recent": "document-open-recent-symbolic.svg"
        }
        var macTahoeActions = {
            "system-search": "system-search.svg",
            "document-open-recent": "document-open-recent.svg"
        }
        var macTahoeDevices = {
            "drive-harddisk": "drive-harddisk.svg",
            "drive-removable-media": "drive-removable-media.svg"
        }
        var macTahoeMimeAliases = {
            "application-msword": "application-vnd.ms-word",
            "application-gzip": "application-x-gzip",
            "application-zip": "application-x-zip",
            "image-gif": "application-image-gif",
            "image-bmp": "application-image-bmp",
            "text-x-markdown": "text-markdown"
        }

        if (macTahoePlaces[iconName]) {
            var placeName = macTahoePlaces[iconName]
            if (placeName.indexOf("-symbolic.svg") !== -1)
                return "file://" + macTahoe + "/places/symbolic/" + placeName
            if (iconSize > 24 && placeName !== "folder-gitlab.svg")
                return "file://" + macTahoe + "/places/scalable/" + placeName
            return "file://" + macTahoe + "/places/" + pickSize([16, 22, 24], iconSize) + "/" + placeName
        }

        if (macTahoeActions[iconName]) {
            var actionSizes = iconName === "system-search" ? [32] : [16, 22, 24, 32]
            return "file://" + macTahoe + "/actions/" + pickSize(actionSizes, iconSize) + "/" + macTahoeActions[iconName]
        }

        if (macTahoeDevices[iconName])
            return "file://" + macTahoe + "/devices/" + pickSize([16, 22, 24, 32], iconSize) + "/" + macTahoeDevices[iconName]

        if (iconName === "media-optical")
            return "file://" + macTahoe + "/mimes/scalable/application-x-cd-image.svg"

        if (macTahoeMimeAliases[iconName])
            return "file://" + macTahoe + "/mimes/scalable/" + macTahoeMimeAliases[iconName] + ".svg"

        return "file://" + macTahoe + "/mimes/scalable/" + iconName + ".svg"
    }

    function portalIconSource(iconName, size) {
        return themedIconSource(iconName, size, "MacTahoe")
    }

    function sidebarIconSource(iconName, size) {
        return themedIconSource(iconName, size, "MacTahoe-dark")
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
        if (!path || app.remoteDirectoryActive)
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
        if (!request || app.remoteDirectoryActive)
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

    function requestHasMissingPreview(request) {
        if (app.remoteDirectoryActive || !request || request.path !== app.currentPath || app.fileModel.count <= 0)
            return false

        var offset = Math.max(0, parseInt(request.offset || "0", 10))
        var limit = Math.max(1, parseInt(request.limit || "12", 10))
        var end = Math.min(app.fileModel.count, offset + limit)

        for (var i = offset; i < end; i++) {
            var item = app.fileModel.get(i)
            if (item
                    && !item.fileIsDir
                    && (item.filePreviewUrl || "") === ""
                    && app.isPreviewableFile(item.fileName, item.fileIsDir))
                return true
        }
        return false
    }

    function retryThumbnailWarm(request) {
        if (!request)
            return

        retryThumbnailWarmRequest = {
            path: request.path,
            showHidden: request.showHidden,
            sortField: request.sortField,
            sortAsc: request.sortAsc,
            foldersFirst: request.foldersFirst,
            offset: request.offset,
            limit: request.limit,
            retries: (request.retries || 0) + 1
        }
        thumbnailWarmRetryTimer.restart()
    }

    function warmCurrentDirectoryThumbnails() {
        if (!startupWorkEnabled || !app.currentPath || app.remoteDirectoryActive || app.searchActive || app.isRecentPath(app.currentPath))
            return
        requestThumbnailWarm(app.currentPath, 0, viewMode === "icon" ? 18 : 24)
    }

    function scheduleVisibleThumbnailWarm(firstIndex, lastIndex) {
        if (!startupWorkEnabled || !app.currentPath || app.remoteDirectoryActive || app.loadingDir || app.isRecentPath(app.currentPath))
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
        if (startupWorkEnabled && !startupWarmTimer.running)
            startupWarmTimer.start()
    }

    function scheduleHomeThumbnailWarmup() {
        startupWarmQueue = []
        enqueueStartupWarm(app.homePath, 8)
        enqueueStartupWarm(app.homePath + "/Downloads", 10)
        enqueueStartupWarm(app.homePath + "/Imagens", 10)
        enqueueStartupWarm(app.homePath + "/Documentos", 6)
    }

    function enableStartupWork() {
        if (startupWorkEnabled)
            return
        startupWorkEnabled = true
        if (app.currentPath && !app.remoteDirectoryActive && !app.loadingDir && !app.searchActive)
            beginCurrentFolderWarm()
        if (!startupWarmTimer.running && startupWarmQueue.length > 0)
            startupWarmTimer.start()
    }

    function formatSize(bytes) {
        if (bytes < 0) return "—"
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MB"
        return (bytes / 1073741824).toFixed(2) + " GB"
    }

    function padDatePart(value) {
        return value < 10 ? "0" + value : String(value)
    }

    function formatAbsoluteDate(date) {
        if (!(date instanceof Date) || isNaN(date.getTime())) return "—"
        return padDatePart(date.getDate()) + "/" + padDatePart(date.getMonth() + 1) + "/" + date.getFullYear()
    }

    function formatDate(date) {
        if (!date) return "—"
        if (typeof date === "number")
            date = new Date(date)
        else if (!(date instanceof Date))
            date = new Date(date)
        if (!(date instanceof Date) || isNaN(date.getTime())) return "—"

        var now = new Date()
        var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        var itemDay = new Date(date.getFullYear(), date.getMonth(), date.getDate())
        var diffDays = Math.floor((today - itemDay) / 86400000)
        if (diffDays < 0)
            return formatAbsoluteDate(date)
        if (diffDays > 1)
            return formatAbsoluteDate(date)

        var diff = (now - date) / 1000
        if (diff < 60) return "Agora"
        if (diff < 3600) return Math.floor(diff / 60) + " min atrás"
        if (diffDays === 0) return "Hoje, " + Qt.formatTime(date, "hh:mm")
        return "Ontem"
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
        if (zoomLevel < 1.7) return 4
        if (zoomLevel < 1.9) return 5
        return 6
    }

    function thumbnailColumnCount() {
        return app.thumbnailColumnStops[thumbnailLevel()]
    }

    function thumbnailScale() {
        return app.thumbnailScaleStops[thumbnailLevel()]
    }

    function isShellScript(path) {
        return /\.sh$/i.test(path || "")
    }

    function isWindowsExecutable(path) {
        return /\.(exe|msi)$/i.test(path || "")
    }

    function isDesktopLauncher(path) {
        return /\.desktop$/i.test(path || "")
    }

    function isDirectExecutable(path) {
        var value = String(path || "")
        var name = value.split("/").pop()
        if (/\.(appimage|run|bin|elf|x86_64|bundle)$/i.test(name))
            return true
        return name !== "" && name.indexOf(".") === -1
    }

    function openShellScript(path) {
        if (!path)
            return
        shellScriptProcess.command = [app.astreaLaunch, "--file", path]
        shellScriptProcess.running = false
        shellScriptProcess.running = true
    }

    function openDirectExecutable(path) {
        if (!path)
            return
        directExecutableProcess.command = [app.astreaLaunch, "--file", path]
        directExecutableProcess.running = false
        directExecutableProcess.running = true
    }

    function openDesktopLauncher(path) {
        if (!path)
            return
        directExecutableProcess.command = [app.astreaLaunch, "--desktop", path]
        directExecutableProcess.running = false
        directExecutableProcess.running = true
    }

    function openWindowsExecutable(path) {
        if (!path)
            return
        app.fileOperationError = ""
        app.fileOperationStatus = "Abrindo app Windows..."
        windowsExecutableProcess.command = [app.windowsRun, "--json", path]
        windowsExecutableProcess.running = false
        windowsExecutableProcess.running = true
    }

    function windowsLaunchPayload() {
        var text = windowsExecutableStdout.text.trim()
        if (!text)
            return null
        try {
            return JSON.parse(text)
        } catch (error) {
            return null
        }
    }

    function openExternalFile(path, fileUrl) {
        externalOpenProcess.command = [app.astreaLaunch, "--file", path || fileUrl]
        externalOpenProcess.running = false
        externalOpenProcess.running = true
    }

    function openItem(path, isDir, fileUrl) {
        app.recordRecentItem(path, isDir, fileUrl)
        if (isDir) {
            app.navigateTo(path)
            return
        }
        if (app.dialogActive && (app.dialogMode === "open_file" || app.dialogMode === "save_file")) {
            app.dialogFileActivated(path, fileUrl)
            return
        }
        if (isShellScript(path)) {
            openShellScript(path)
            return
        }
        if (isWindowsExecutable(path)) {
            openWindowsExecutable(path)
            return
        }
        if (isDesktopLauncher(path)) {
            openDesktopLauncher(path)
            return
        }
        if (isDirectExecutable(path)) {
            openDirectExecutable(path)
            return
        }
        openExternalFile(path, fileUrl)
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

    property Timer thumbnailWarmRetryTimer: Timer {
        interval: 650
        repeat: false
        onTriggered: {
            if (!preview.retryThumbnailWarmRequest)
                return
            if (preview.thumbnailWarmProcess.running) {
                restart()
                return
            }

            var request = preview.retryThumbnailWarmRequest
            preview.retryThumbnailWarmRequest = null
            preview.startThumbnailWarm(request)
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
            else if (exitCode === 0
                    && activeRequest
                    && activeRequest.path === app.currentPath
                    && !isNaN(warmedCount)
                    && warmedCount === 0
                    && (activeRequest.retries || 0) < 3
                    && preview.requestHasMissingPreview(activeRequest))
                preview.retryThumbnailWarm(activeRequest)

            preview.activeThumbnailWarmRequest = null

            if (preview.pendingThumbnailWarmRequest)
                preview.thumbnailWarmDebounce.restart()
            else if (preview.currentFolderWarmOffset >= 0)
                preview.currentFolderWarmTimer.restart()
            if (preview.startupWorkEnabled && !preview.startupWarmTimer.running && preview.startupWarmQueue.length > 0)
                preview.startupWarmTimer.start()
        }
    }

    property Process shellScriptProcess: Process {
        command: []
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0)
                Qt.openUrlExternally(app.fileUrlForPath(command[command.length - 1]))
        }
    }

    property Process directExecutableProcess: Process {
        command: []
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0)
                Qt.openUrlExternally(app.fileUrlForPath(command[command.length - 1]))
        }
    }

    property Process windowsExecutableProcess: Process {
        command: []
        running: false
        stdout: StdioCollector { id: windowsExecutableStdout }
        stderr: StdioCollector { id: windowsExecutableStderr }
        onExited: function(exitCode) {
            var payload = preview.windowsLaunchPayload()
            if (exitCode === 0 && (!payload || payload.ok !== false)) {
                app.fileOperationError = ""
                app.fileOperationStatus = "Abrindo app Windows via " + ((payload && payload.runner) ? payload.runner : "Proton GE")
                return
            }

            var message = ""
            if (payload && payload.error)
                message = payload.error
            else if (windowsExecutableStderr.text.trim())
                message = windowsExecutableStderr.text.trim()
            else
                message = "Falha ao abrir app Windows"

            if (payload && payload.log)
                message += " (" + payload.log + ")"
            app.fileOperationError = message
            app.fileOperationStatus = message
        }
    }

    property Process externalOpenProcess: Process {
        command: []
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0)
                Qt.openUrlExternally(app.fileUrlForPath(command[command.length - 1]))
        }
    }

}
