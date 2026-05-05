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
    property int archiveExtractionDoneCount: 0
    property int archiveExtractionTotalCount: 0
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
        archiveExtractionDoneCount = 0
        archiveExtractionTotalCount = 0

        archiveExtractProcess.command = [
            "bash", "-lc",
            "archive=\"$1\"; base=\"$2\"; parent=$(dirname -- \"$archive\"); archive_name=$(basename -- \"$archive\"); " +
            "dest=\"$parent/$base\"; n=2; while [ -e \"$dest\" ]; do dest=\"$parent/$base $n\"; n=$((n+1)); done; " +
            "mkdir -p -- \"$dest\" || exit 1; " +
            "lower=$(printf '%s' \"$archive\" | tr '[:upper:]' '[:lower:]'); " +
            "count_entries() { " +
            "  if [[ \"$lower\" =~ \\.zip$ ]] && command -v unzip >/dev/null 2>&1; then unzip -Z1 \"$archive\" 2>/dev/null | wc -l; " +
            "  elif [[ \"$lower\" =~ \\.rar$ ]] && command -v unrar >/dev/null 2>&1; then unrar lb \"$archive\" 2>/dev/null | wc -l; " +
            "  elif [[ \"$lower\" =~ \\.(7z|rar)$ ]] && command -v 7z >/dev/null 2>&1; then 7z l -ba \"$archive\" 2>/dev/null | awk 'NF { c++ } END { print c + 0 }'; " +
            "  elif command -v bsdtar >/dev/null 2>&1; then bsdtar -tf \"$archive\" 2>/dev/null | wc -l; " +
            "  else printf '0\\n'; fi; " +
            "}; " +
            "extract_archive() { " +
            "  if [[ \"$lower\" =~ \\.zip$ ]]; then " +
            "    if command -v unzip >/dev/null 2>&1; then unzip -o \"$archive\" -d \"$dest\"; else bsdtar -xf \"$archive\" -C \"$dest\"; fi; " +
            "  elif [[ \"$lower\" =~ \\.7z$ ]]; then " +
            "    7z x -y -o\"$dest\" \"$archive\"; " +
            "  elif [[ \"$lower\" =~ \\.rar$ ]]; then " +
            "    if command -v unrar >/dev/null 2>&1; then unrar x -o+ \"$archive\" \"$dest/\"; else 7z x -y -o\"$dest\" \"$archive\"; fi; " +
            "  else " +
            "    bsdtar -xf \"$archive\" -C \"$dest\"; " +
            "  fi; " +
            "}; " +
            "total=$(count_entries | tail -n1 | tr -dc '0-9'); total=${total:-0}; " +
            "printf 'START|%s|%s|%s\\n' \"$archive_name\" \"$dest\" \"$total\"; " +
            "log=$(mktemp); extract_archive >\"$log\" 2>&1 & pid=$!; " +
            "while kill -0 \"$pid\" 2>/dev/null; do " +
            "  done_count=$(find \"$dest\" -mindepth 1 2>/dev/null | wc -l | tr -dc '0-9'); done_count=${done_count:-0}; " +
            "  if [ \"$total\" -gt 0 ]; then pct=$((done_count * 100 / total)); [ \"$pct\" -gt 99 ] && pct=99; else pct=0; fi; " +
            "  printf 'PROGRESS|%s|%s|%s\\n' \"$done_count\" \"$total\" \"$pct\"; sleep 0.2; " +
            "done; " +
            "wait \"$pid\"; code=$?; rm -f -- \"$log\"; " +
            "done_count=$(find \"$dest\" -mindepth 1 2>/dev/null | wc -l | tr -dc '0-9'); done_count=${done_count:-0}; " +
            "if [ \"$code\" -eq 0 ]; then printf 'DONE|%s|%s|%s|100\\n' \"$dest\" \"$done_count\" \"$total\"; else printf 'ERROR|%s|%s\\n' \"$dest\" \"$code\"; fi; exit \"$code\"",
            "_", archivePath, folderName || basename(archivePath)
        ]
        archiveExtractProcess.running = false
        archiveExtractProcess.running = true
    }

    function handleArchiveExtractionLine(rawLine) {
        var line = String(rawLine || "").trim()
        if (line === "")
            return
        var parts = line.split("|")
        if (parts[0] === "START") {
            archiveExtractionFileName = parts[1] || archiveExtractionFileName
            archiveExtractionDestination = parts[2] || archiveExtractionDestination
            archiveExtractionTotalCount = Number(parts[3] || 0)
            archiveExtractionDoneCount = 0
            archiveExtractionStatus = "Extraindo..."
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
            archiveExtractionStatus = archiveExtractionPercent > 0
                ? ("Extraindo... " + archiveExtractionPercent + "%")
                : "Extraindo..."
        } else if (parts[0] === "DONE") {
            archiveExtractionDestination = parts[1] || archiveExtractionDestination
            archiveExtractionDoneCount = Number(parts[2] || archiveExtractionDoneCount)
            archiveExtractionTotalCount = Number(parts[3] || archiveExtractionTotalCount)
            archiveExtractionPercent = 100
            archiveExtractionProgress = 1
            archiveExtractionStatus = "Extracao concluida"
            archiveExtractionError = ""
        } else if (parts[0] === "ERROR") {
            archiveExtractionDestination = parts[1] || archiveExtractionDestination
            archiveExtractionError = "Falha ao extrair"
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
            "set -e; " +
            "mode=\"$1\"; policy=\"$2\"; dest=\"$3\"; rename_to=\"$4\"; shift 4; " +
            "unique_target() { " +
            "  dir=\"$1\"; name=\"$2\"; base=\"$name\"; ext=\"\"; " +
            "  case \"$name\" in .*|*.) ;; *.*) base=\"${name%.*}\"; ext=\".${name##*.}\" ;; esac; " +
            "  candidate=\"$dir/$name\"; n=2; " +
            "  while [ -e \"$candidate\" ]; do candidate=\"$dir/$base $n$ext\"; n=$((n + 1)); done; " +
            "  printf '%s\\n' \"$candidate\"; " +
            "}; " +
            "copy_item() { cp -aT --reflink=auto -- \"$1\" \"$2\"; }; " +
            "move_item() { mv -T -- \"$1\" \"$2\"; }; " +
            "same_item() { [ \"$(realpath -m -- \"$1\" 2>/dev/null || printf '%s' \"$1\")\" = \"$(realpath -m -- \"$2\" 2>/dev/null || printf '%s' \"$2\")\" ]; }; " +
            "publish_item() { " +
            "  src=\"$1\"; target=\"$2\"; " +
            "  if [ \"$mode\" != \"copy\" ]; then move_item \"$src\" \"$target\"; return $?; fi; " +
            "  dir=$(dirname -- \"$target\"); name=$(basename -- \"$target\"); tmp=\"$dir/.$name.bench-paste.$$\"; n=2; " +
            "  while [ -e \"$tmp\" ]; do tmp=\"$dir/.$name.bench-paste.$$.$n\"; n=$((n + 1)); done; " +
            "  if ! copy_item \"$src\" \"$tmp\"; then code=$?; rm -rf -- \"$tmp\"; return \"$code\"; fi; " +
            "  if move_item \"$tmp\" \"$target\"; then return 0; fi; " +
            "  code=$?; rm -rf -- \"$tmp\"; return \"$code\"; " +
            "}; " +
            "replace_item() { " +
            "  src=\"$1\"; target=\"$2\"; dir=$(dirname -- \"$target\"); name=$(basename -- \"$target\"); " +
            "  same_item \"$src\" \"$target\" && return 0; " +
            "  tmp=\"$dir/.$name.bench-paste.$$\"; backup=\"$dir/.$name.bench-replace.$$\"; n=2; " +
            "  while [ -e \"$tmp\" ]; do tmp=\"$dir/.$name.bench-paste.$$.$n\"; n=$((n + 1)); done; " +
            "  n=2; while [ -e \"$backup\" ]; do backup=\"$dir/.$name.bench-replace.$$.$n\"; n=$((n + 1)); done; " +
            "  if [ \"$mode\" = \"copy\" ]; then copy_item \"$src\" \"$tmp\"; else move_item \"$src\" \"$tmp\"; fi; " +
            "  had_backup=0; " +
            "  if [ -e \"$target\" ]; then move_item \"$target\" \"$backup\"; had_backup=1; fi; " +
            "  if move_item \"$tmp\" \"$target\"; then " +
            "    [ \"$had_backup\" -eq 0 ] || rm -rf -- \"$backup\"; " +
            "    return 0; " +
            "  fi; " +
            "  code=$?; " +
            "  if [ \"$had_backup\" -eq 1 ] && [ ! -e \"$target\" ] && [ -e \"$backup\" ]; then move_item \"$backup\" \"$target\" || true; fi; " +
            "  if [ \"$mode\" != \"copy\" ] && [ ! -e \"$src\" ] && [ -e \"$tmp\" ]; then move_item \"$tmp\" \"$src\" || true; fi; " +
            "  return \"$code\"; " +
            "}; " +
            "for f in \"$@\"; do " +
            "[ -e \"$f\" ] || continue; " +
            "name=$(basename -- \"$f\"); target=\"$dest/$name\"; " +
            "same_item \"$f\" \"$target\" && continue; " +
            "src_abs=$(realpath -m -- \"$f\" 2>/dev/null || printf '%s' \"$f\"); " +
            "dest_abs=$(realpath -m -- \"$dest\" 2>/dev/null || printf '%s' \"$dest\"); " +
            "if [ -d \"$f\" ]; then case \"$dest_abs/\" in \"$src_abs/\"*) continue ;; esac; fi; " +
            "if [ -e \"$target\" ]; then " +
            "  case \"$policy\" in " +
            "    overwrite) replace_item \"$f\" \"$target\"; continue ;; " +
            "    skip) continue ;; " +
            "    rename) [ -n \"$rename_to\" ] || continue; target=\"$dest/$rename_to\"; if [ -e \"$target\" ]; then continue; fi ;; " +
            "    keep-both) target=$(unique_target \"$dest\" \"$name\") ;; " +
            "  esac; " +
            "fi; " +
            "publish_item \"$f\" \"$target\"; " +
            "done",
            "_", mode, policy, destinationPath, pendingPasteRename
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
    }

    function deleteSelected() {
        if (app.selectedFiles.length === 0) return
        var targets = selectedPathsInCurrentFolder()
        pendingDeleteTargets = targets.slice()
        deleteProcess.command = [
            "bash", "-lc",
            "trashDir=\"$1\"; infoDir=\"$2\"; shift 2; mkdir -p -- \"$trashDir\" \"$infoDir\"; " +
            "encode_path() { " +
            "  if command -v python3 >/dev/null 2>&1; then python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=\"/\"))' \"$1\"; else printf '%s' \"$1\"; fi; " +
            "}; " +
            "for target in \"$@\"; do " +
            "[ -e \"$target\" ] || continue; " +
            "name=$(basename -- \"$target\"); dest=\"$trashDir/$name\"; " +
            "n=2; while [ -e \"$dest\" ]; do dest=\"$trashDir/$name $n\"; n=$((n+1)); done; " +
            "trash_name=$(basename -- \"$dest\"); info=\"$infoDir/$trash_name.trashinfo\"; " +
            "mv -- \"$target\" \"$dest\" || continue; " +
            "{ printf '[Trash Info]\\nPath='; encode_path \"$target\"; printf '\\nDeletionDate=%s\\n' \"$(date +'%Y-%m-%dT%H:%M:%S')\"; } > \"$info\"; " +
            "done",
            "_", app.trashFilesPath, app.trashInfoPath
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
            "bash", "-lc",
            "trashInfo=\"$1\"; fallbackDir=\"$2\"; shift 2; mkdir -p -- \"$fallbackDir\"; " +
            "decode_path() { " +
            "  if command -v python3 >/dev/null 2>&1; then python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))' \"$1\"; else printf '%s' \"$1\"; fi; " +
            "}; " +
            "unique_target() { " +
            "  dir=\"$1\"; name=\"$2\"; base=\"$name\"; ext=\"\"; " +
            "  case \"$name\" in .*|*.) ;; *.*) base=\"${name%.*}\"; ext=\".${name##*.}\" ;; esac; " +
            "  candidate=\"$dir/$name\"; n=2; " +
            "  while [ -e \"$candidate\" ]; do candidate=\"$dir/$base $n$ext\"; n=$((n + 1)); done; " +
            "  printf '%s\\n' \"$candidate\"; " +
            "}; " +
            "for trashed in \"$@\"; do " +
            "[ -e \"$trashed\" ] || continue; " +
            "trash_name=$(basename -- \"$trashed\"); info=\"$trashInfo/$trash_name.trashinfo\"; original=\"\"; " +
            "if [ -f \"$info\" ]; then raw=$(sed -n 's/^Path=//p' \"$info\" | head -n1); [ -n \"$raw\" ] && original=$(decode_path \"$raw\"); fi; " +
            "[ -n \"$original\" ] || original=\"$fallbackDir/$trash_name\"; " +
            "dest_dir=$(dirname -- \"$original\"); dest_name=$(basename -- \"$original\"); mkdir -p -- \"$dest_dir\" || dest_dir=\"$fallbackDir\"; " +
            "dest=$(unique_target \"$dest_dir\" \"$dest_name\"); " +
            "mv -- \"$trashed\" \"$dest\" && rm -f -- \"$info\"; " +
            "done",
            "_", app.trashInfoPath, "/home/agony"
        ].concat(targets)
        restoreProcess.running = false
        restoreProcess.running = true
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
        onExited: function(exitCode) {
            if (exitCode === 0 && ops.pendingPasteClearsClipboard)
                ops.clipboardFiles = []
            ops.pendingPasteClearsClipboard = false
            ops.pendingPostPasteThumbnailWarm = true
            app.refreshCurrentFolder()
            postPasteThumbnailWarmTimer.restart()
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
                ops.archiveExtractionStatus = "Extracao concluida"
                ops.archiveExtractionError = ""
                if (ops.archiveExtractionDestination !== "")
                    app.navigateTo(ops.archiveExtractionDestination)
                else
                    app.refreshCurrentFolder()
            } else {
                ops.archiveExtractionError = "Falha ao extrair"
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
