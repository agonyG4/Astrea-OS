import QtQuick
import QtQuick.Layouts
import "../../AstreaComponents" as Astrea

Flow {
    id: root
    property var options: []
    property string value: ""
    signal selected(string value)

    spacing: 6

    Repeater {
        model: root.options
        Rectangle {
            readonly property bool active: root.value === modelData
            width: Math.max(50, label.implicitWidth + 18)
            height: 28
            radius: 8
            color: active ? Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.18) : (area.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
            border.width: 1
            border.color: active ? Astrea.Theme.accent : Astrea.Theme.cardBorder

            Text {
                id: label
                anchors.centerIn: parent
                text: modelData
                color: active ? Astrea.Theme.accent : Astrea.Theme.textPrimary
                font.family: Astrea.Theme.fontFamily
                font.pixelSize: Astrea.Theme.fontSizeSmall
                font.weight: Font.Medium
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selected(modelData)
            }
        }
    }
}
