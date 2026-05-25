import QtQuick
import QtQuick.Controls

Item {
    id: root

    default property alias contentData: contentColumn.data

    property real topMargin: 10
    property real bottomMargin: 10
    property real leftMargin: 10
    property real rightMargin: 8
    property real cornerRadius: 20
    property color backgroundColor: Qt.rgba(1, 1, 1, 0.05)
    property color washColor: Qt.rgba(1, 1, 1, 0.015)
    property color borderColor: Qt.rgba(1, 1, 1, 0.08)
    property real contentTopPadding: 16
    property real contentBottomPadding: 16
    property real contentSpacing: 2
    property bool clipContent: true

    Rectangle {
        id: card
        anchors {
            fill: parent
            topMargin: root.topMargin
            bottomMargin: root.bottomMargin
            leftMargin: root.leftMargin
            rightMargin: root.rightMargin
        }

        radius: root.cornerRadius
        clip: root.clipContent
        color: root.backgroundColor

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.washColor
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: root.borderColor
        }

        ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            clip: true

            Column {
                id: contentColumn
                width: parent.width
                topPadding: root.contentTopPadding
                bottomPadding: root.contentBottomPadding
                spacing: root.contentSpacing
            }
        }
    }
}
