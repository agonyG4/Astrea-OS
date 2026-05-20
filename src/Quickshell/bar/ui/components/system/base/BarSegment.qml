import QtQuick
import "../../../.."

Item {
    id: root

    property int segmentHeight: 36
    property int horizontalPadding: 10
    property int fixedWidth: 0
    property alias spacing: contentRow.spacing
    property alias row: contentRow
    default property alias contentData: contentRow.data

    width: fixedWidth > 0 ? fixedWidth : contentRow.implicitWidth + horizontalPadding * 2
    height: segmentHeight
    opacity: 0

    function reveal() {
        opacity = 1
    }

    Component.onCompleted: reveal()

    HoverHandler {
        id: hoverHandler
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge - 2
        color: Theme.background
        border.width: 1
        border.color: hoverHandler.hovered ? Theme.barBorderHover : Theme.border

        Behavior on border.color { ColorAnimation { duration: Theme.animationNormal } }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.spacing
    }

    Behavior on opacity {
        NumberAnimation { duration: Theme.animationSlow; easing.type: Easing.OutCubic }
    }
}
