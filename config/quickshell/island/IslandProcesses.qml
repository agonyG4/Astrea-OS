import Quickshell
import Quickshell.Io
import QtQuick

Item {
    // ── API Pública ────────────────────────────────────────────────

    function normalizeFileUrl(input) {
        var raw = (input?.toString) ? input.toString() : String(input || "")
        if (!raw?.startsWith("file://")) return ""
        var path = raw.split("?")[0].slice(7)
        try { path = decodeURIComponent(path) } catch (e) {}
        return "file://" + encodeURI(path)
    }

    function isSupportedFileUrl(fileUrl) {
        var lower = fileUrl.toLowerCase().split("?")[0]
        return lower.startsWith("file://") && lower.length > 7
    }

    // ── Categorias ─────────────────────────────────────────────────
    function getFileCategory(url) {
        var u = (url || "").toLowerCase().split("?")[0]
        if (/\.(png|jpg|jpeg|webp|gif|bmp|avif|heic|heif|svg|ico|tiff|tif)$/.test(u)) return "image"
        if (/\.(mp4|mkv|webm|avi|mov|flv|wmv|m4v|ogv|3gp|ts)$/.test(u))              return "video"
        if (/\.(mp3|flac|ogg|wav|aac|m4a|opus|wma|aiff)$/.test(u))                   return "audio"
        if (/\.pdf$/.test(u))                                                          return "pdf"
        if (/\.(zip|tar|gz|bz2|xz|7z|rar|zst|lz4)$/.test(u))                        return "archive"
        if (/\.(doc|docx|odt|rtf|pages)$/.test(u))                                    return "doc"
        if (/\.(xls|xlsx|ods|csv)$/.test(u))                                          return "spreadsheet"
        if (/\.(ppt|pptx|odp|key)$/.test(u))                                          return "presentation"
        if (/\.(js|ts|py|rs|go|c|cpp|h|hpp|java|kt|swift|rb|php|sh|fish|lua|qml|css|html|xml|json|yaml|toml|md)$/.test(u)) return "code"
        if (/\.(ttf|otf|woff|woff2)$/.test(u))                                        return "font"
        return "generic"
    }

    function getCategoryEmoji(cat) {
        return ({ image: "🖼", video: "🎬", audio: "🎵", pdf: "📄", archive: "📦",
                  doc: "📝", spreadsheet: "📊", presentation: "📽", code: "💻", font: "🔤" })[cat] ?? "📎"
    }

    function getCategoryAccent(cat) {
        return ({ image: "#a78bfa", video: "#f472b6", audio: "#34d399", pdf: "#f87171",
                  archive: "#fbbf24", doc: "#60a5fa", spreadsheet: "#4ade80",
                  presentation: "#fb923c", code: "#38bdf8", font: "#e879f9" })[cat] ?? "#94a3b8"
    }

    function getFileExtension(url) {
        var u = (url || "").toLowerCase().split("?")[0]
        var dot = u.lastIndexOf(".")
        return dot === -1 ? "" : u.slice(dot + 1)
    }

    function getFileName(url) {
        var u = (url || "").split("?")[0]
        return decodeURIComponent(u.slice(Math.max(u.lastIndexOf("/"), u.lastIndexOf("%2F")) + 1))
    }

    // ── Dropped files ──────────────────────────────────────────────
    function persistDroppedImages() {
        saveDroppedImages.payload = JSON.stringify(island.droppedImages)
        saveDroppedImages.running = false
        Qt.callLater(() => { saveDroppedImages.running = true })
    }

    function addDroppedFiles(urls) {
        if (!urls?.length) return
        for (var i = 0; i < urls.length; i++) {
            var fileUrl = normalizeFileUrl(urls[i])
            if (!fileUrl || !isSupportedFileUrl(fileUrl)) continue
            if (_pendingDroppedSources.indexOf(fileUrl) !== -1) continue
            _pendingDroppedSources.push(fileUrl)
        }
        importNextDroppedFile()
    }
    function addDroppedImages(urls) { addDroppedFiles(urls) }

    function importNextDroppedFile() {
        if (importDroppedImage.running || !_pendingDroppedSources.length) return
        importDroppedImage.sourceUrl = _pendingDroppedSources.shift()
        importDroppedImage.running = false
        Qt.callLater(() => { importDroppedImage.running = true })
    }
    function importNextDroppedImage() { importNextDroppedFile() }

    function addImportedDroppedImage(fileUrl) {
        var normalized = normalizeFileUrl(fileUrl)
        if (!normalized || !isSupportedFileUrl(normalized)) return
        var next = island.droppedImages.slice()
        if (next.indexOf(normalized) !== -1) return
        next.push(normalized)
        if (next.length > 24) cleanupDroppedTempFile(next.shift())
        island.droppedImages = next
        persistDroppedImages()
    }

    function cleanupDroppedTempFile(fileUrl) {
        if (!fileUrl?.startsWith("file://")) return
        if (!fileUrl.includes("/.cache/island-dropped-images/")) return
        deleteDroppedImage.sourceUrl = fileUrl
        deleteDroppedImage.running = false
        Qt.callLater(() => { deleteDroppedImage.running = true })
    }

    function removeDroppedFile(url) {
        var fileUrl = normalizeFileUrl(url)
        if (!fileUrl) return
        var current = island.droppedImages.slice()
        var idx = current.indexOf(fileUrl)
        if (idx === -1) return
        current.splice(idx, 1)
        island.droppedImages = current
        persistDroppedImages()
        cleanupDroppedTempFile(fileUrl)
    }
    function removeDroppedImage(url) { removeDroppedFile(url) }

    function openFile(url) {
        var p = normalizeFileUrl(url).replace("file://", "")
        if (!p) return
        openProcess.command = ["xdg-open", p]
        openProcess.running = false
        Qt.callLater(() => { openProcess.running = true })
    }

    function openFolder(url) {
        var p = normalizeFileUrl(url).replace("file://", "")
        if (!p) return
        openProcess.command = ["xdg-open", p.substring(0, p.lastIndexOf("/"))]
        openProcess.running = false
        Qt.callLater(() => { openProcess.running = true })
    }

    // ── Playback ───────────────────────────────────────────────────
    function playPause() {
        if (island.sharedMusicState)
            island.sharedMusicState.playPause()
    }

    function next() {
        if (island.sharedMusicState)
            island.sharedMusicState.next()
    }

    function prev() {
        if (island.sharedMusicState)
            island.sharedMusicState.prev()
    }

    function toggleShuffle() {
        if (island.sharedMusicState)
            island.sharedMusicState.toggleShuffle()
    }

    function toggleLoop() {
        if (island.sharedMusicState)
            island.sharedMusicState.toggleLoop()
    }

    function setPosition(targetPosMicroSec) {
        if (island.sharedMusicState)
            island.sharedMusicState.setPosition(targetPosMicroSec)
    }

    // ── Estado interno ─────────────────────────────────────────────
    property string legacyConfigFile:     Qt.resolvedUrl("config/island.json").toString().replace("file://", "")
    property string stateDir:             Quickshell.env("HOME") + "/.local/state/Astrea/island"
    property string configFile:           stateDir + "/island.json"
    property string droppedImagesFile:    stateDir + "/dropped-images.json"
    property string droppedImagesTempDir: "/home/agony/.cache/island-dropped-images"
    property var    _pendingDroppedSources: []

    // ── Processos: ficheiros ───────────────────────────────────────
    Process {
        id: openProcess
        command: ["xdg-open", ""]
        running: false
    }

    Process {
        id: saveDroppedImages
        property string payload: "[]"
        command: ["bash", "-c",
            "mkdir -p \"$(dirname \"$1\")\"; printf '%s' \"$2\" > \"$1\"",
            "--", droppedImagesFile, payload]
        running: false
    }

    Process {
        id: importDroppedImage
        property string sourceUrl: ""
        command: ["bash", "-c",
            "python3 -c \"import os,sys,time,shutil,urllib.parse;" +
            "u=sys.argv[1].split('?',1)[0];" +
            "src=urllib.parse.unquote(u[7:]);" +
            "out=sys.argv[2];" +
            "os.makedirs(out,exist_ok=True);" +
            "name=os.path.basename(src) or 'file';" +
            "dst=os.path.join(out,f'{time.time_ns()}-{name}');" +
            "shutil.copy2(src,dst);" +
            "print('file://'+urllib.parse.quote(dst,safe='/'))\" \"$1\" \"$2\"",
            "--", sourceUrl, droppedImagesTempDir]
        running: false
        stdout: SplitParser { onRead: data => addImportedDroppedImage(data.trim()) }
        onRunningChanged: if (!running) Qt.callLater(() => { importNextDroppedFile() })
    }

    Process {
        id: deleteDroppedImage
        property string sourceUrl: ""
        command: ["bash", "-c",
            "python3 -c \"import os,sys,urllib.parse;" +
            "p=urllib.parse.unquote(sys.argv[1].split('?',1)[0][7:]);" +
            "os.path.exists(p) and os.remove(p)\" \"$1\"",
            "--", sourceUrl]
        running: false
    }

    Process {
        id: sanitizeDroppedImages
        property string payload: "[]"
        command: ["bash", "-c",
            "python3 -c \"import json,os,sys,urllib.parse;" +
            "out=[];" +
            "seen=set();" +
            "[out.append(nu) or seen.add(nu)" +
            " for u in json.loads(sys.argv[1])" +
            " if (nu:='file://'+urllib.parse.quote(urllib.parse.unquote(str(u).split('?',1)[0][7:]),safe='/'))" +
            " and str(u).startswith('file://') and os.path.exists(urllib.parse.unquote(str(u).split('?',1)[0][7:]))" +
            " and nu not in seen];" +
            "print(json.dumps(out))\" \"$1\"",
            "--", payload]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data.trim())
                    if (!Array.isArray(parsed)) return
                    island.droppedImages = parsed
                    persistDroppedImages()
                } catch (e) {}
            }
        }
    }

    // ── Monitores de config / estado ───────────────────────────────
    Process {
        id: gamemodeMonitor
        command: ["bash", "-c",
            "gamemoded -s 2>/dev/null | grep -q 'is active' && echo active || echo inactive;" +
            "while inotifywait -q -e modify /tmp/gamemode_status 2>/dev/null; do cat /tmp/gamemode_status; done"]
        running: true
        stdout: SplitParser { onRead: data => { island.gamemodeActive = data.trim() === "active" } }
    }

    Process {
        id: configMonitor
        command: ["bash", "-c",
            "FILE=\"$1\"; LEGACY=\"$2\";" +
            "mkdir -p \"$(dirname \"$FILE\")\";" +
            "if [ ! -f \"$FILE\" ]; then " +
            "  if [ -f \"$LEGACY\" ]; then cp \"$LEGACY\" \"$FILE\"; " +
            "  else printf '%s\n' '{' '    \"enabled\": true,' '    \"always_on_top\": true,' '    \"music\": true,' '    \"show_gamemode_notify\": false,' '    \"style\": \"Notch\"' '}' > \"$FILE\"; " +
            "  fi; " +
            "fi;" +
            "cat \"$FILE\" | tr '\\n' ' '; echo;" +
            "while inotifywait -q -e modify \"$FILE\" 2>/dev/null; do cat \"$FILE\" | tr '\\n' ' '; echo; done",
            "--", configFile, legacyConfigFile]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    var c = JSON.parse(data.trim())
                    island.islandConfig.enabled              = c.enabled              ?? true
                    island.islandConfig.always_on_top        = c.always_on_top        ?? true
                    island.islandConfig.music                = c.music                ?? true
                    island.islandConfig.show_gamemode_notify = c.show_gamemode_notify ?? false
                    island.islandConfig.style                = c.style                ?? "Notch"
                } catch(e) {}
            }
        }
    }

    Process {
        id: droppedImagesMonitor
        command: ["bash", "-c",
            "FILE=\"$1\";" +
            "mkdir -p \"$(dirname \"$FILE\")\";" +
            "[ -f \"$FILE\" ] || echo '[]' > \"$FILE\";" +
            "cat \"$FILE\" | tr '\\n' ' '; echo;" +
            "while inotifywait -q -e modify \"$FILE\" 2>/dev/null; do cat \"$FILE\" | tr '\\n' ' '; echo; done",
            "--", droppedImagesFile]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data.trim())
                    if (!Array.isArray(parsed)) return
                    sanitizeDroppedImages.payload = JSON.stringify(parsed)
                    sanitizeDroppedImages.running = false
                    Qt.callLater(() => { sanitizeDroppedImages.running = true })
                } catch (e) {}
            }
        }
    }

}
