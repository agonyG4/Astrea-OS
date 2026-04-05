import QtQuick
import QtQuick.Layouts
import ".." as Components

Rectangle {
    id: root

    property string providerLabel: "Automatic (ISP)"
    property string detail: ""
    property color badgeColor: Components.Theme.textSecondary
    property bool isAuto: true

    radius: 10
    color: Qt.rgba(1, 1, 1, 0.035)
    border.width: 1
    border.color: Components.Theme.cardBorder
    implicitHeight: content.implicitHeight + 28

    Rectangle {
        width: 4
        radius: 2
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            margins: 10
        }
        color: root.badgeColor
    }

    ColumnLayout {
        id: content
        anchors {
            fill: parent
            leftMargin: 24
            rightMargin: 14
            topMargin: 14
            bottomMargin: 14
        }
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Components.StatusDot {
                active: true
                pulse: true
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: root.providerLabel
                color: Components.Theme.textPrimary
                font.family: Components.Theme.fontFamily
                font.pixelSize: 15
                font.weight: Components.Theme.fontWeightMedium
                Layout.fillWidth: true
            }

            Rectangle {
                radius: 999
                color: Qt.rgba(root.badgeColor.r, root.badgeColor.g, root.badgeColor.b, 0.16)
                border.width: 1
                border.color: Qt.rgba(root.badgeColor.r, root.badgeColor.g, root.badgeColor.b, 0.35)
                implicitHeight: 24
                implicitWidth: badgeText.implicitWidth + 18

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.isAuto ? "Auto" : "Manual"
                    color: root.badgeColor
                    font.family: Components.Theme.fontFamily
                    font.pixelSize: Components.Theme.fontSizeSmall
                    font.weight: Components.Theme.fontWeightMedium
                }
            }
        }

        Text {
            text: root.detail
            color: Components.Theme.textSecondary
            font.family: Components.Theme.fontFamily
            font.pixelSize: Components.Theme.fontSizeSmall
            font.weight: Components.Theme.fontWeightLight
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
    }
}
