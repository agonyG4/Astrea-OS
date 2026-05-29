import QtQuick

Item {
    id: root

    property bool active: false

    anchors.fill: parent

    IdleCompactView {
        anchors.fill: parent
        active: root.active
    }
}
