import QtQuick
import "../../.."

Item {
    id: control

    property var popupRef: null
    property bool active: popupRef ? popupRef.shown : false
    property int fixedWidth: 0
    property int horizontalPadding: 16
    property int backgroundMargin: 3
    property int backgroundRadius: Theme.radiusMedium - 2
    property color activeColor: Qt.rgba(1, 1, 1, 0.15)
    property color pressedColor: Qt.rgba(1, 1, 1, 0.12)
    property color hoverColor: Theme.separator
    property color idleColor: "transparent"
    property alias spacing: contentRow.spacing
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: mouseArea.pressed

    default property alias contentData: contentRow.data

    signal clicked()
    signal wheel(var event)

    width: fixedWidth > 0 ? fixedWidth : contentRow.implicitWidth + horizontalPadding
    height: 34

    function updatePopupAnchor() {
        if (!control.popupRef) return
        const point = control.mapToItem(null, control.width / 2, control.height / 2)
        control.popupRef.anchorX = point.x
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

        Behavior on color { ColorAnimation { duration: 100 } }
    }

    HoverHandler {
        id: hoverHandler
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 4
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            control.togglePopup()
            control.clicked()
        }

        onWheel: event => control.wheel(event)
    }
}
