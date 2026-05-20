import QtQuick

Item {
    id: root

    property Component sourceComponent: null
    readonly property var popup: popupLoader.item

    function toggleAt(anchorX) {
        const x = anchorX !== undefined && isFinite(anchorX) ? anchorX : 0

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
}
