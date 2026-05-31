import QtQuick
import "../AstreaComponents" as Astrea

Rectangle {
    id: pill

    property string label: ""
    property string tag: ""

    implicitWidth: tagText.implicitWidth + 16
    implicitHeight: 22
    radius: 11
    color: tagTint(tag)
    border.width: 1
    border.color: Astrea.Theme.cardBorder
    visible: label !== ""

    function tagTint(value) {
        if (value === "Design")
            return Qt.rgba(0.93, 0.36, 0.52, 0.16)
        if (value === "Runtime" || value === "Shell" || value === "Gmail")
            return Qt.rgba(0.18, 0.58, 0.96, 0.16)
        if (value === "Paper")
            return Qt.rgba(0.20, 0.74, 0.48, 0.16)
        if (value === "Draft" || value === "Important")
            return Qt.rgba(0.98, 0.68, 0.22, 0.16)
        return Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.13)
    }

    Astrea.TextLabel {
        id: tagText
        anchors.centerIn: parent
        text: pill.label
        textColor: Astrea.Theme.textSecondary
        font.pixelSize: Astrea.Theme.fontSizeTiny
        font.weight: Astrea.Theme.fontWeightDemiBold
    }
}
