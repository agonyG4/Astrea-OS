import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15
import Quickshell.Io

Window {
    id: root
    visible: instanceRegistered && !awaitingImageSize
    width: defaultWindowWidth
    height: defaultWindowHeight
    minimumWidth: 320
    minimumHeight: 120
    color: "transparent"
    title: "Quick Look"
    flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus

    property string targetPath: ""
    property string currentLoadedPath: ""
    property bool contentReady: false
    property bool isDirectory: false
    property string fileName: ""
    property string fileSize: ""
    property int fileCount: 0
    property int imageNaturalWidth: 0
    property int imageNaturalHeight: 0
    property bool awaitingImageSize: false
    property bool currentTargetIsImage: false
    property string instanceToken: ""
    property bool instanceRegistered: false
    readonly property int defaultWindowWidth: 625
    readonly property int defaultWindowHeight: 350
    readonly property real imageScreenUsageLimit: 0.7
    readonly property string pathFile: "/tmp/explorer-quicklook-path"
    readonly property string pidFile: "/tmp/explorer-quicklook.pid"
    readonly property string instanceFile: "/tmp/explorer-quicklook-instance"

    Shortcut { sequence: "Escape"; onActivated: Qt.quit() }
    Shortcut { sequence: "Space";  onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+W"; onActivated: Qt.quit() }

    Component.onCompleted: {
        instanceToken = Date.now().toString() + "-" + Math.floor(Math.random() * 1000000).toString()
        registerInstanceProcess.running = true
    }
    onClosing: {
        pathPollTimer.stop()
        instanceGuardTimer.stop()
    }
    Component.onDestruction: {
        pathPollTimer.stop()
        instanceGuardTimer.stop()
    }

    function openPath(path) {
        if (!path || path === currentLoadedPath)
            return

        imageMeasureProcess.running = false
        statProcess.running = false
        currentLoadedPath = path
        targetPath = path
        contentReady = false
        imageResizeTimer.stop()
        isDirectory = false
        fileCount = 0
        fileSize = ""
        imageNaturalWidth = 0
        imageNaturalHeight = 0
        currentTargetIsImage = isLikelyImagePath(path)
        resetToDefaultSize()
        var parts = path.split("/")
        fileName = parts[parts.length - 1] || parts[parts.length - 2] || path
        awaitingImageSize = currentTargetIsImage
        if (awaitingImageSize) {
            imageMeasureProcess.requestedPath = path
            imageMeasureProcess.running = false
            imageMeasureProcess.running = true
        } else {
            statProcess.requestedPath = path
            statProcess.running = true
        }
    }

    function resetToDefaultSize() {
        root.width = defaultWindowWidth
        root.height = defaultWindowHeight
    }

    function availableScreenWidth() {
        return root.screen ? root.screen.width : Screen.width
    }

    function availableScreenHeight() {
        return root.screen ? root.screen.height : Screen.height
    }

    function fitImageWindow() {
        if (!currentTargetIsImage || isDirectory)
            return

        var naturalWidth = imageNaturalWidth
        var naturalHeight = imageNaturalHeight

        if (naturalWidth <= 0 || naturalHeight <= 0) {
            naturalWidth = previewImage.implicitWidth
            naturalHeight = previewImage.implicitHeight
        }

        if (naturalWidth <= 0 || naturalHeight <= 0) {
            naturalWidth = previewImage.sourceSize.width
            naturalHeight = previewImage.sourceSize.height
        }

        if (naturalWidth <= 0 || naturalHeight <= 0)
            return

        var maxWidth = Math.floor(availableScreenWidth() * imageScreenUsageLimit)
        var maxHeight = Math.floor(availableScreenHeight() * imageScreenUsageLimit)
        var scale = Math.min(maxWidth / naturalWidth, maxHeight / naturalHeight, 1.0)

        root.width = Math.max(minimumWidth, Math.round(naturalWidth * scale))
        root.height = Math.max(minimumHeight, Math.round(naturalHeight * scale))
    }

    function getExtension() {
        var parts = root.targetPath.split(".")
        if (parts.length > 1) return parts[parts.length - 1].toUpperCase()
        return "ARQUIVO"
    }

    function iconNameForCurrentItem() {
        if (isDirectory) {
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

        var lowerName = fileName.toLowerCase()
        var dotIndex = lowerName.lastIndexOf(".")
        var ext = dotIndex >= 0 ? lowerName.slice(dotIndex + 1) : ""
        var map = {
            "pdf": "application-pdf",
            "doc": "application-msword",
            "docx": "application-msword",
            "txt": "text-plain",
            "md": "text-x-markdown",
            "xls": "application-vnd.ms-excel",
            "xlsx": "application-vnd.ms-excel",
            "csv": "text-csv",
            "ppt": "application-vnd.ms-powerpoint",
            "pptx": "application-vnd.ms-powerpoint",
            "png": "image-x-generic",
            "jpg": "image-x-generic",
            "jpeg": "image-x-generic",
            "gif": "image-gif",
            "svg": "image-svg+xml",
            "webp": "image-x-generic",
            "heic": "image-x-generic",
            "bmp": "image-bmp",
            "mp3": "audio-mpeg",
            "flac": "audio-x-flac",
            "wav": "audio-x-wav",
            "aac": "audio-aac",
            "mp4": "video-mp4",
            "mov": "video-quicktime",
            "avi": "video-x-msvideo",
            "mkv": "video-x-matroska",
            "webm": "video-webm",
            "zip": "application-zip",
            "tar": "application-x-tar",
            "gz": "application-gzip",
            "rar": "application-x-rar",
            "7z": "application-x-7z-compressed",
            "dmg": "media-optical",
            "iso": "media-optical",
            "sh": "application-x-shellscript",
            "py": "text-x-python",
            "js": "application-javascript",
            "ts": "text-x-typescript",
            "html": "text-html",
            "css": "text-css",
            "json": "application-json",
            "xml": "text-xml",
            "qml": "text-x-qml",
            "ttf": "font-x-generic",
            "otf": "font-x-generic"
        }
        return map[ext] || "text-x-generic"
    }

    function isLikelyImagePath(path) {
        var lower = (path || "").toLowerCase()
        return lower.endsWith(".png")
            || lower.endsWith(".jpg")
            || lower.endsWith(".jpeg")
            || lower.endsWith(".gif")
            || lower.endsWith(".bmp")
            || lower.endsWith(".svg")
            || lower.endsWith(".heic")
            || lower.endsWith(".avif")
    }

    // ── Modo IMAGEM ──
    Image {
        id: previewImage
        anchors.fill: parent
        source: contentReady && !isDirectory ? "file://" + root.targetPath : ""
        asynchronous: true
        cache: false
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: status === Image.Ready

        onStatusChanged: {
            if (!root.currentTargetIsImage) {
                root.resetToDefaultSize()
            } else if (status === Image.Ready) {
                imageResizeTimer.restart()
            } else if (status === Image.Error || status === Image.Null) {
                root.resetToDefaultSize()
            }
        }

        onSourceSizeChanged: imageResizeTimer.restart()
        onImplicitWidthChanged: imageResizeTimer.restart()
        onImplicitHeightChanged: imageResizeTimer.restart()
    }

    // ── Modo PADRÃO: pasta ou arquivo não-imagem ──
    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16
        visible: previewImage.status !== Image.Ready

        // LEFT: ícone do tema
        Item {
            width: 120
            height: 120
            Layout.alignment: Qt.AlignVCenter

            Image {
                anchors.centerIn: parent
                width: root.isDirectory ? 96 : 84
                height: root.isDirectory ? 96 : 84
                source: "image://icon/" + root.iconNameForCurrentItem()
                asynchronous: false
                cache: true
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }
        }

        // RIGHT: informações
        Column {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 6

            Text {
                text: root.fileName || "—"
                color: "white"
                font.pixelSize: 24
                font.bold: true
                elide: Text.ElideMiddle
                width: parent.width
            }

            Text {
                text: root.fileSize ? "Tamanho: " + root.fileSize : ""
                color: "#aaaaaa"
                font.pixelSize: 16
                visible: root.fileSize !== ""
            }

            Text {
                text: root.isDirectory ? ("Arquivos: " + root.fileCount) : ""
                color: "#aaaaaa"
                font.pixelSize: 12
                visible: root.isDirectory
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Qt.quit()
    }

    property Process registerInstanceProcess: Process {
        command: [
            "bash", "-lc",
            "printf '%s' \"$1\" > \"$2\"",
            "--",
            root.instanceToken,
            root.instanceFile
        ]
        running: false
        stdout: StdioCollector {}
        onExited: function() {
            root.instanceRegistered = true
            startupPathProcess.running = true
            pathPollTimer.start()
            instanceGuardTimer.start()
        }
    }

    property Process startupPathProcess: Process {
        command: ["bash", "-lc", "cat /tmp/explorer-quicklook-path 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var path = text.trim()
                if (path) root.openPath(path)
            }
        }
    }

    property Process imageMeasureProcess: Process {
        property string requestedPath: ""
        command: [
            "bash", "-lc",
            "magick identify -format '%w %h' \"$1\" 2>/dev/null || true",
            "--",
            requestedPath
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (imageMeasureProcess.requestedPath !== root.targetPath)
                    return

                var dimensionLine = text.trim()
                if (dimensionLine) {
                    var parts = dimensionLine.split(/\s+/)
                    root.imageNaturalWidth = parseInt(parts[0]) || 0
                    root.imageNaturalHeight = parseInt(parts[1]) || 0
                    if (root.imageNaturalWidth > 0 && root.imageNaturalHeight > 0)
                        root.fitImageWindow()
                }
                root.awaitingImageSize = false
                statProcess.requestedPath = imageMeasureProcess.requestedPath
                statProcess.running = false
                statProcess.running = true
            }
        }
        onExited: function() {
            if (imageMeasureProcess.requestedPath !== root.targetPath)
                return

            if (root.awaitingImageSize && !running) {
                root.awaitingImageSize = false
                statProcess.requestedPath = imageMeasureProcess.requestedPath
                statProcess.running = false
                statProcess.running = true
            }
        }
    }

    property Process pathWatchProcess: Process {
        command: ["bash", "-lc", "cat /tmp/explorer-quicklook-path 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var path = text.trim()
                if (path)
                    root.openPath(path)
            }
        }
    }

    Timer {
        id: pathPollTimer
        interval: 150
        repeat: true
        running: false
        onTriggered: {
            pathWatchProcess.running = false
            pathWatchProcess.running = true
        }
    }

    Timer {
        id: imageResizeTimer
        interval: 0
        repeat: false
        running: false
        onTriggered: root.fitImageWindow()
    }

    property Process instanceGuardProcess: Process {
        command: [
            "bash", "-lc",
            "cat \"$1\" 2>/dev/null",
            "--",
            root.instanceFile
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var activeToken = text.trim()
                if (root.instanceRegistered && activeToken && activeToken !== root.instanceToken)
                    Qt.quit()
            }
        }
    }

    Timer {
        id: instanceGuardTimer
        interval: 250
        repeat: true
        running: false
        onTriggered: {
            instanceGuardProcess.running = false
            instanceGuardProcess.running = true
        }
    }

    property Process statProcess: Process {
        property string requestedPath: ""
        command: [
            "bash", "-lc",
            "P=\"" + requestedPath + "\"; " +
            "if [ -d \"$P\" ]; then " +
            "  echo 'DIR'; " +
            "  COUNT=$(ls -1 \"$P\" 2>/dev/null | wc -l | tr -d ' '); echo \"$COUNT\"; " +
            "  SIZE=$(du -sh \"$P\" 2>/dev/null | cut -f1); echo \"$SIZE\"; " +
            "else " +
            "  echo 'FILE'; " +
            "  echo '0'; " +
            "  SIZE=$(du -sh \"$P\" 2>/dev/null | cut -f1); echo \"$SIZE\"; " +
            "fi"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (statProcess.requestedPath !== root.targetPath)
                    return

                var lines = text.trim().split("\n")
                if (lines.length >= 3) {
                    root.isDirectory = (lines[0].trim() === "DIR")
                    root.fileCount   = parseInt(lines[1].trim()) || 0
                    root.fileSize    = lines[2].trim()
                    if (root.isDirectory) {
                        root.currentTargetIsImage = false
                        root.resetToDefaultSize()
                    }
                }
                root.contentReady = true
                if (!root.currentTargetIsImage)
                    root.resetToDefaultSize()
                else if (!root.isDirectory && root.imageNaturalWidth > 0 && root.imageNaturalHeight > 0)
                    root.fitImageWindow()
            }
        }
    }
}
