import QtQuick
import "../../.."

Item {
    id: control

    property string title: ""
    property string icon: ""
    property color iconColor: Theme.textDim
    property int iconSize: Theme.fontSizeIcon
    property int trailingGap: 8
    property int trailingWidth: iconText.visible ? iconText.implicitWidth : 0
    property int trailingHeight: 24
    property alias titleItem: titleLabel

    default property alias trailingData: trailingContent.data

    width: parent ? parent.width : implicitWidth
    height: 24

    Text {
        id: titleLabel
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: control.title
        color: Theme.textActive
        opacity: 0.85
        width: parent.width - trailingSlot.width - control.trailingGap
        elide: Text.ElideRight
        font {
            family: Theme.fontFamily
            pixelSize: Theme.fontSizeBody
            weight: Font.DemiBold
            letterSpacing: 0.3
        }
    }

    Item {
        id: trailingSlot
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: control.trailingWidth
        height: Math.max(24, control.trailingHeight)

        Text {
            id: iconText
            anchors.verticalCenter: parent.verticalCenter
            visible: control.icon !== ""
            text: control.icon
            color: control.iconColor
            font {
                family: Theme.fontFamily
                pixelSize: control.iconSize
            }
        }

        Item {
            id: trailingContent
            anchors.fill: parent
        }
    }
}
