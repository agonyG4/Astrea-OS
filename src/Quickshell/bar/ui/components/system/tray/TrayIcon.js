.pragma library

function source(icon) {
    if (!icon)
        return ""

    const marker = "?path="
    const markerIndex = icon.indexOf(marker)
    if (markerIndex < 0)
        return icon

    const name = icon.slice(0, markerIndex).replace(/^image:\/\/icon\//, "")
    const path = icon.slice(markerIndex + marker.length)
    if (!name || !path)
        return icon

    const fileName = name.match(/\.(png|svg|ico|xpm)$/i) ? name : name + ".png"
    return "file://" + path.replace(/\/$/, "") + "/" + fileName
}
