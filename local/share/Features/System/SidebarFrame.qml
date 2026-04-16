import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root

    default property alias contentData: contentColumn.data

    property real topMargin: 10
    property real bottomMargin: 10
    property real leftMargin: 12
    property real rightMargin: 8
    property real cornerRadius: 22
    property color backgroundColor: "#18181a"
    property color washColor: Qt.rgba(1, 1, 1, 0.02)
    property color borderColor: Qt.rgba(1, 1, 1, 0.09)
    property real contentTopPadding: 20
    property real contentBottomPadding: 20
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
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
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
