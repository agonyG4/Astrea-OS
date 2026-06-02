import QtQuick

Item {
    id: root

    property bool pinned: false
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool expanded: hovered || pinned

    anchors.fill: parent

    HoverHandler {
        id: hoverHandler
    }
}
