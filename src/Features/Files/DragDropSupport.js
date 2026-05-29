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

function dropPaths(drop) {
    const urls = [].concat((drop && drop.urls) || [])
    const paths = []
    for (var i = 0; i < urls.length; i++) {
        const entries = String(urls[i] || "").split(/\r?\n/)
        for (var j = 0; j < entries.length; j++) {
            const path = normalizeFileUrl(entries[j])
            if (path)
                paths.push(path)
        }
    }
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
    if (!drop || !drop.hasUrls)
        return false
    appState.dropFiles(
        drop.urls,
        destinationPath || appState.currentPath,
        dropModeFor(drop, appState)
    )
    drop.accepted = true
    return true
}
