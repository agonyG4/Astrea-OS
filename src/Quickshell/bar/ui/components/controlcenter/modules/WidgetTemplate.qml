import QtQuick
import "../../../.."

Item {
    id: widget

    property var control: null
    property string widgetKind: ""
    property string widgetSize: "small"
    property string widgetGroup: ""
    property int preferredHeight: control ? control.moduleHeight(widgetKind, widgetSize, widgetGroup) : 68
    signal addClicked()

    width: parent ? parent.width : 120
    height: preferredHeight

    Loader {
        id: modulePreview

        anchors.fill: parent
        sourceComponent: widget.control ? widget.control.moduleComponent(widget.widgetKind) : null

        onLoaded: {
            if (item && item.control !== undefined)
                item.control = widget.control
            if (item && item.moduleKind !== undefined)
                item.moduleKind = widget.widgetKind
            if (item && item.moduleSize !== undefined)
                item.moduleSize = widget.widgetSize
            if (item && item.moduleGroup !== undefined)
                item.moduleGroup = widget.widgetGroup
        }
    }

    Rectangle {
        id: addBadge

        width: 22
        height: 22
        radius: height / 2
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -7
        anchors.rightMargin: -7
        z: 20
        color: addArea.containsMouse ? Theme.accent : Theme.surface
        border.width: 1
        border.color: addArea.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.44) : Theme.border

        Behavior on color { ColorAnimation { duration: Theme.animationHover } }
        Behavior on border.color { ColorAnimation { duration: Theme.animationHover } }

        Text {
            anchors.centerIn: parent
            text: "+"
            color: addArea.containsMouse ? "#ffffff" : Theme.shellTextActive
            font { family: Theme.fontFamily; pixelSize: 16; weight: Font.DemiBold }
        }
    }

    MouseArea {
        id: addArea

        anchors.fill: parent
        z: 10
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: widget.addClicked()
    }
}
