import QtQuick

IndicatorButton {
    id: root

    property var popupHost: null
    readonly property var hostedPopup: popupHost ? popupHost.popup : null

    signal activated(real anchorX)

    popupRef: popupHost
    autoTogglePopup: false

    onClicked: anchorX => {
        if (root.popupHost)
            root.popupHost.toggleAt(anchorX)
        root.activated(anchorX)
    }
}
