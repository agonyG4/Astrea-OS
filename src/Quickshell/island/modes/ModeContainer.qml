import QtQuick

Item {
    id: root

    property bool active: false
    property int fadeInDuration: 140
    property int fadeOutDuration: 180
    default property alias content: contentHost.data

    anchors.fill: parent
    visible: opacity > 0.01
    opacity: active ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: root.active ? root.fadeInDuration : root.fadeOutDuration
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: contentHost
        anchors.fill: parent
    }
}
