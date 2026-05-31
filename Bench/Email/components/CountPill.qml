import QtQuick
import "../AstreaComponents" as Astrea

Rectangle {
    property int label: 0

    implicitWidth: Math.max(28, countText.implicitWidth + 16)
    implicitHeight: 24
    radius: 12
    color: Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.14)
    border.width: 1
    border.color: Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.24)

    Astrea.TextLabel {
        id: countText
        anchors.centerIn: parent
        text: parent.label
        textColor: Astrea.Theme.accent
        font.pixelSize: Astrea.Theme.fontSizeSmall
        font.weight: Astrea.Theme.fontWeightDemiBold
    }
}
