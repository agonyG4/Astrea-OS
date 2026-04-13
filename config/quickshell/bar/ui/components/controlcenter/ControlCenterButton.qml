import QtQuick
import Qt5Compat.GraphicalEffects
import "../../.."

Item {
    id: root
    width: 36
    height: 36

    function updatePopupAnchor() {
        if (!root.ccPopupRef) return
        const point = root.mapToItem(null, root.width / 2, root.height / 2)
        root.ccPopupRef.anchorX = point.x
    }

    onXChanged: updatePopupAnchor()
    onWidthChanged: updatePopupAnchor()
    onCcPopupRefChanged: updatePopupAnchor()
    Component.onCompleted: updatePopupAnchor()

    Rectangle {
        id: bg
        anchors.centerIn: parent
        width: 28
        height: 28
        radius: Theme.radiusMedium
        color: tapHandler.pressed ? Qt.rgba(1, 1, 1, 0.1) : (hoverHandler.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
        Behavior on color { ColorAnimation { duration: 150 } }

        // Icon (macOS Control Center style)
        Image {
            id: icon
            anchors.centerIn: parent
            width: 16; height: 16
            source: "../../../assets/topbar/control_center-icon.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            opacity: tapHandler.pressed ? 0.7 : 1.0

            layer.enabled: true
            layer.smooth: true
            layer.effect: ColorOverlay {
                color: Theme.iconMain
            }
        }
    }

    property var ccPopupRef: null

    HoverHandler { id: hoverHandler }
    TapHandler {
        id: tapHandler
        onTapped: {
            if (root.ccPopupRef) {
                const point = root.mapToItem(null, root.width / 2, root.height / 2)
                root.ccPopupRef.toggleAt(point.x)
            }
        }
    }
}
