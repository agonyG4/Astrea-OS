import QtQuick
import "../../AstreaComponents" as Astrea

Rectangle {
    id: button
    property string text: ""
    property bool enabledState: true
    property bool primary: false
    signal clicked()

    implicitWidth: Math.max(90, label.implicitWidth + 28)
    implicitHeight: 36
    radius: 12
    opacity: enabledState ? 1 : 0.42
    color: primary ? Astrea.Theme.accent : (area.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
    border.width: primary ? 0 : 1
    border.color: Astrea.Theme.cardBorder

    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
        id: label
        anchors.centerIn: parent
        text: button.text
        color: button.primary ? "#ffffff" : Astrea.Theme.textPrimary
        font.family: Astrea.Theme.fontFamily
        font.pixelSize: Astrea.Theme.fontSizeSmall
        font.weight: Font.Medium
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: button.enabledState
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
