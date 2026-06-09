.pragma library

function resetActivationCandidate(root) {
    root.lastActivationCandidatePath = ""
    root.lastActivationCandidateAt = 0
}

function focusFileSurface(root) {
    const window = root && root.Window ? root.Window.window : null
    if (window && window.focusFileSurface)
        window.focusFileSurface()
}

function handlePrimaryItemClick(root, appState, path, isDir, fileUrl, fileName, index, modifiers) {
    const ctrl = Boolean(modifiers & Qt.ControlModifier)
    const shift = Boolean(modifiers & Qt.ShiftModifier)
    appState.handleSelection(fileName, index, ctrl, shift, false)
    if (ctrl || shift)
        return

    const now = Date.now()
    if (root.lastActivationCandidatePath === path &&
            (now - root.lastActivationCandidateAt) <= root.activationIntervalMs) {
        resetActivationCandidate(root)
        appState.openItem(path, isDir, fileUrl)
        return
    }

    root.lastActivationCandidatePath = path
    root.lastActivationCandidateAt = now
}

function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value))
}

function prepareScrollRestore(root, appState, viewMode, path) {
    root.trackedPath = path || ""
    root.scrollSyncReady = false
    root.restoringScroll = true
    root.pendingRestoreY = appState.savedScrollPosition(root.trackedPath, viewMode)
    root.restoreAttempts = 0
}

function applyPendingScrollRestore(root, appState, flickable) {
    if (!root.restoringScroll || !root.trackedPath ||
            root.trackedPath !== appState.currentPath || appState.searchActive)
        return

    var retryTimer = root.restoreRetryTimerRef

    var maxY = Math.max(0, flickable.contentHeight - flickable.height)
    var targetY = clamp(root.pendingRestoreY, 0, maxY)
    if (Math.abs(flickable.contentY - targetY) > 0.5)
        flickable.contentY = targetY

    if (root.pendingRestoreY <= 0 || maxY >= root.pendingRestoreY || root.restoreAttempts >= 24) {
        root.restoringScroll = false
        root.scrollSyncReady = true
        if (retryTimer)
            retryTimer.stop()
    } else {
        root.restoreAttempts += 1
        if (retryTimer)
            retryTimer.restart()
    }
}

function refreshAfterModelChange(root, appState, flickable, viewMode, rebuildFn, applyFn) {
    var preserveCurrentScroll = !root.restoringScroll &&
        !appState.loadingDir &&
        root.trackedPath === appState.currentPath &&
        !appState.searchActive
    var preservedY = preserveCurrentScroll ? flickable.contentY : 0

    rebuildFn()

    if (preserveCurrentScroll) {
        appState.rememberScrollPosition(root.trackedPath, viewMode, preservedY)
        Qt.callLater(function() {
            var maxY = Math.max(0, flickable.contentHeight - flickable.height)
            flickable.contentY = clamp(preservedY, 0, maxY)
        })
        return
    }

    if ((root.restoringScroll || appState.loadingDir) &&
            root.trackedPath === appState.currentPath &&
            root.pendingRestoreY > 0) {
        root.restoringScroll = true
        root.scrollSyncReady = false
        Qt.callLater(applyFn)
    }
}

function normalizedKind(kind, isDir, name) {
    if (isDir)
        return "Pastas"
    const lowerName = (name || "").toLowerCase()
    const lowerKind = (kind || "").toLowerCase()
    if (/\.sh$/i.test(lowerName))
        return "Scripts"
    if (lowerKind.indexOf("image") !== -1)
        return "Imagens"
    if (lowerKind.indexOf("video") !== -1)
        return "Videos"
    if (lowerKind.indexOf("audio") !== -1)
        return "Audio"
    if (lowerKind.indexOf("pdf") !== -1 || lowerKind.indexOf("text") !== -1
            || lowerKind.indexOf("document") !== -1 || lowerKind.indexOf("spreadsheet") !== -1
            || lowerKind.indexOf("presentation") !== -1 || lowerKind.indexOf("json") !== -1
            || lowerKind.indexOf("xml") !== -1 || lowerKind.indexOf("shellscript") !== -1)
        return "Documentos"
    return "Outros"
}

function sizeGroup(size, isDir) {
    if (isDir)
        return "Pastas"
    if (size <= 0)
        return "Vazio"
    if (size < 1024 * 1024)
        return "Pequenos (< 1 MB)"
    if (size < 100 * 1024 * 1024)
        return "Medios (< 100 MB)"
    return "Grandes"
}

function padDatePart(value) {
    return value < 10 ? "0" + value : String(value)
}

function monthYearLabel(date) {
    return padDatePart(date.getMonth() + 1) + "/" + date.getFullYear()
}

function dateGroup(modified) {
    const date = new Date(modified)
    if (!(date instanceof Date) || isNaN(date.getTime()))
        return "Sem data"
    const now = new Date()
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    const itemDay = new Date(date.getFullYear(), date.getMonth(), date.getDate())
    const diffDays = Math.floor((today - itemDay) / 86400000)
    if (diffDays <= 0)
        return "Hoje"
    if (diffDays === 1)
        return "Ontem"
    if (diffDays < 7)
        return "Ultimos 7 dias"
    if (diffDays < 30)
        return "Ultimos 30 dias"
    return monthYearLabel(date)
}

function groupLabelForItem(appState, item) {
    if (!appState.groupingEnabled)
        return ""
    switch (appState.sortField) {
    case "date":
        return dateGroup(item.fileModified)
    case "kind":
        return normalizedKind(item.fileKind, item.fileIsDir, item.fileName)
    case "size":
        return sizeGroup(item.fileSize, item.fileIsDir)
    default:
        return ""
    }
}
