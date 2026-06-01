.pragma library

function normalizeFileUrl(url) {
    const value = String(url || "").trim()
    if (value.indexOf("file://") !== 0)
        return ""
    const encoded = value.slice("file://".length)
    try {
        return decodeURIComponent(encoded)
    } catch (error) {
        return encoded
    }
}

function appendUniquePath(paths, seen, path) {
    const value = String(path || "").trim()
    if (!value || seen[value])
        return
    seen[value] = true
    paths.push(value)
}

function appendUriList(paths, seen, text) {
    const entries = String(text || "").split(/\r?\n/)
    for (var i = 0; i < entries.length; i++) {
        const path = normalizeFileUrl(entries[i])
        if (path)
            appendUniquePath(paths, seen, path)
    }
}

function appendPlainPathList(paths, seen, text) {
    const entries = String(text || "").split(/\r?\n/)
    for (var i = 0; i < entries.length; i++) {
        const value = String(entries[i] || "").trim()
        if (value.indexOf("/") === 0)
            appendUniquePath(paths, seen, value)
    }
}

function dataAsString(drop, format) {
    if (!drop || typeof drop.getDataAsString !== "function")
        return ""
    try {
        return drop.getDataAsString(format) || ""
    } catch (error) {
        return ""
    }
}

function dropPaths(drop) {
    const urls = [].concat((drop && drop.urls) || [])
    const paths = []
    const seen = {}
    for (var i = 0; i < urls.length; i++) {
        const path = normalizeFileUrl(urls[i])
        if (path)
            appendUniquePath(paths, seen, path)
        else
            appendUriList(paths, seen, urls[i])
    }

    appendUriList(paths, seen, dataAsString(drop, "text/uri-list"))
    appendPlainPathList(paths, seen, dataAsString(drop, "text/plain"))
    if (drop && drop.hasText)
        appendPlainPathList(paths, seen, drop.text)

    return paths
}

function isSelectedInternalDrop(drop, appState) {
    if (!appState || !appState.selectedPathsInCurrentFolder)
        return false
    const selected = appState.selectedPathsInCurrentFolder()
    if (!selected || selected.length === 0)
        return false
    const paths = dropPaths(drop)
    for (var i = 0; i < paths.length; i++) {
        if (selected.indexOf(paths[i]) !== -1)
            return true
    }
    return false
}

function dropModeFor(drop, appState) {
    if (drop && drop.source)
        return "move"
    return isSelectedInternalDrop(drop, appState) ? "move" : "copy"
}

function dragImageUrl(previewUrl, fallbackIconUrl) {
    if (previewUrl)
        return previewUrl
    return fallbackIconUrl || ""
}

function handleDroppedUrls(appState, drop, destinationPath) {
    const paths = dropPaths(drop)
    if (!paths || paths.length === 0)
        return false
    appState.dropFilePaths(
        paths,
        destinationPath || appState.currentPath,
        dropModeFor(drop, appState)
    )
    drop.accepted = true
    return true
}
