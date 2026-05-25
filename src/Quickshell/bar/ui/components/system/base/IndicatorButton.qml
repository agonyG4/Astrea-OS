import QtQuick
import "../../../.."

Item {
    id: control

    property var popupRef: null
    property bool active: popupRef ? popupRef.shown : false
    property int fixedWidth: 0
    property int horizontalPadding: Theme.spacingContainer
    property int backgroundMargin: Theme.spacingTiny
    property int backgroundRadius: Theme.radiusMedium - 2
    property color activeColor: Theme.shellActive
    property color pressedColor: Theme.shellPressed
    property color hoverColor: Theme.shellHover
    property color idleColor: "transparent"
    property bool autoTogglePopup: true
    property alias spacing: contentRow.spacing
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: mouseArea.pressed

    default property alias contentData: contentRow.data

    signal clicked(real anchorX)
    signal wheel(var event)

    width: fixedWidth > 0 ? fixedWidth : contentRow.implicitWidth + horizontalPadding
    height: 34

    function updatePopupAnchor() {
        if (!control.popupRef || !control.popupRef.updateAnchorAt) return
        const point = control.mapToItem(null, control.width / 2, control.height / 2)
        control.popupRef.updateAnchorAt(point.x)
    }

    function togglePopup() {
        if (!control.popupRef) return
        const point = control.mapToItem(null, control.width / 2, control.height / 2)
        control.popupRef.toggleAt(point.x)
    }

    onXChanged: updatePopupAnchor()
    onWidthChanged: updatePopupAnchor()
    onPopupRefChanged: updatePopupAnchor()
    Component.onCompleted: updatePopupAnchor()

    Rectangle {
        anchors.fill: parent
        anchors.margins: control.backgroundMargin
        radius: control.backgroundRadius
        color: control.active ? control.activeColor
             : control.pressed ? control.pressedColor
             : control.hovered ? control.hoverColor
             : control.idleColor

        Behavior on color { ColorAnimation { duration: Theme.animationMicro } }
    }

    HoverHandler {
        id: hoverHandler
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.spacingMicro
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            const point = control.mapToItem(null, control.width / 2, control.height / 2)
            if (control.autoTogglePopup)
                control.togglePopup()
            control.clicked(point.x)
        }

        onWheel: event => control.wheel(event)
    }
}
