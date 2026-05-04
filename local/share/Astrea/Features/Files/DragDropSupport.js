.pragma library

function dropModeFor(drop) {
    return drop && drop.source ? "move" : "copy"
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
        dropModeFor(drop)
    )
    drop.accepted = true
    return true
}
