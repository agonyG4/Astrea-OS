import QtQuick
import QtQuick.Layouts
import "../AstreaComponents" as Astrea

Rectangle {
    id: bubble

    property string initials: ""
    property string tag: ""
    property bool compact: false
    property bool unread: false

    Layout.preferredWidth: compact ? 34 : 46
    Layout.preferredHeight: compact ? 34 : 46
    implicitWidth: compact ? 34 : 46
    implicitHeight: compact ? 34 : 46
    radius: width / 2
    color: unread
        ? Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.18)
        : tagTint(tag)
    border.width: 1
    border.color: unread
        ? Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.34)
        : Astrea.Theme.cardBorder

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

    Text {
        anchors.centerIn: parent
        text: bubble.initials
        color: bubble.unread ? Astrea.Theme.accent : Astrea.Theme.textSecondary
        font.family: Astrea.Theme.fontFamily
        font.pixelSize: bubble.compact ? Astrea.Theme.fontSizeSmall : Astrea.Theme.fontSizeNormal
        font.weight: Astrea.Theme.fontWeightDemiBold
    }
}
