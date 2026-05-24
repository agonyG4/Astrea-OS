import QtQuick

Item {
    id: root

    property Component sourceComponent: null
    property real anchorOffset: 0
    property real lastAnchorX: 0
    readonly property var popup: popupLoader.item
    readonly property bool shown: popupLoader.item ? popupLoader.item.shown : false

    function resolveAnchor(anchorX) {
        return (anchorX !== undefined && isFinite(anchorX) ? anchorX : root.lastAnchorX) + root.anchorOffset
    }

    function updateAnchorAt(anchorX) {
        if (anchorX !== undefined && isFinite(anchorX))
            root.lastAnchorX = anchorX

        if (popupLoader.item && popupLoader.item.shown)
            popupLoader.item.anchorX = root.resolveAnchor(root.lastAnchorX)
    }

    function toggleAt(anchorX) {
        if (anchorX !== undefined && isFinite(anchorX))
            root.lastAnchorX = anchorX

        const x = root.resolveAnchor(root.lastAnchorX)

        if (!popupLoader.active) {
            popupLoader.active = true
            Qt.callLater(() => {
                if (popupLoader.item)
                    popupLoader.item.toggleAt(x)
            })
            return
        }

        if (popupLoader.item)
            popupLoader.item.toggleAt(x)
    }

    Loader {
        id: popupLoader
        active: false
        sourceComponent: root.sourceComponent
    }

    onAnchorOffsetChanged: updateAnchorAt(root.lastAnchorX)
}
