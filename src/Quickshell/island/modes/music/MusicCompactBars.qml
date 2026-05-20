import QtQuick

Item {
    id: root

    property bool active: false
    property var bars: [0, 0, 0, 0, 0, 0]
    property int minHeight: 4
    property int maxHeight: 18
    property color tint: "#ffffff"
    property int barTravel: 18

    visible: opacity > 0
    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    Row {
        spacing: 3
        anchors {
            right: parent.right
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }

        Repeater {
            model: 6
            Item {
                width: 3
                height: 20

                Rectangle {
                    width: 3
                    height: root.bars[index] <= 0 ? (root.active ? root.minHeight : 0) : Math.min(root.maxHeight, Math.max(root.minHeight, root.bars[index] / 100 * root.barTravel))
                    radius: 2
                    anchors.centerIn: parent
                    color: root.tint
                    Behavior on height {
                        NumberAnimation {
                            duration: root.bars[index] <= 0 ? 280 : 82 + index * 4
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on color { ColorAnimation { duration: 800 } }
                }
            }
        }
    }
}
