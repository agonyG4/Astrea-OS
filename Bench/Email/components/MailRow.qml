import QtQuick
import QtQuick.Layouts
import "../AstreaComponents" as Astrea

Rectangle {
    id: row

    property string messageId: ""
    property string fromName: ""
    property string subject: ""
    property string preview: ""
    property string timestamp: ""
    property string tag: ""
    property bool starred: false
    property bool isRead: true
    property bool selected: false
    property color selectedBg: Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.16)
    property color selectedBorder: Qt.rgba(Astrea.Theme.accent.r, Astrea.Theme.accent.g, Astrea.Theme.accent.b, 0.34)
    property color hoverSurface: Qt.rgba(1, 1, 1, 0.060)
    signal clicked()

    height: 118
    radius: 14
    color: selected ? selectedBg : (hover.hovered ? hoverSurface : "transparent")
    border.width: selected ? 1 : 0
    border.color: selected ? selectedBorder : Astrea.Theme.cardBorder
    scale: press.pressed ? 0.992 : 1

    Behavior on color { ColorAnimation { duration: Astrea.Theme.animationQuick; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: Astrea.Theme.animationQuick; easing.type: Easing.OutCubic } }

    HoverHandler { id: hover }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: Astrea.Theme.spacingSmall

        AvatarBubble {
            initials: rowInitials(row.fromName)
            tag: row.tag
            compact: true
            unread: !row.isRead
            Layout.alignment: Qt.AlignTop
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Astrea.TextLabel {
                    Layout.fillWidth: true
                    text: row.fromName
                    textColor: Astrea.Theme.textPrimary
                    font.pixelSize: Astrea.Theme.fontSizeNormal
                    font.weight: row.isRead ? Astrea.Theme.fontWeightMedium : Astrea.Theme.fontWeightDemiBold
                    elide: Text.ElideRight
                }

                Astrea.TextLabel {
                    text: row.timestamp
                    textColor: Astrea.Theme.textTertiary
                    font.pixelSize: Astrea.Theme.fontSizeSmall
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 7

                Rectangle {
                    Layout.preferredWidth: 7
                    Layout.preferredHeight: 7
                    radius: 4
                    color: row.isRead ? "transparent" : Astrea.Theme.accent
                }

                Astrea.TextLabel {
                    Layout.fillWidth: true
                    text: row.subject
                    textColor: Astrea.Theme.textPrimary
                    font.pixelSize: Astrea.Theme.fontSizeNormal
                    font.weight: row.isRead ? Astrea.Theme.fontWeightMedium : Astrea.Theme.fontWeightDemiBold
                    elide: Text.ElideRight
                }

                Text {
                    text: row.starred ? "\uf005" : ""
                    color: Astrea.Theme.warningColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Astrea.Theme.fontSizeSmall
                }
            }

            Astrea.TextLabel {
                Layout.fillWidth: true
                text: row.preview
                textColor: Astrea.Theme.textSecondary
                font.pixelSize: Astrea.Theme.fontSizeSmall
                lineHeight: 1.12
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
            }

            TagPill {
                label: row.tag
                tag: row.tag
            }
        }
    }

    function rowInitials(name) {
        const parts = (name || "Mail").replace(/^\s+|\s+$/g, "").split(/\s+/)
        const first = parts.length > 0 ? parts[0].charAt(0) : "M"
        const second = parts.length > 1 ? parts[parts.length - 1].charAt(0) : ""
        return (first + second).toUpperCase()
    }

    MouseArea {
        id: press
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }
}
