import QtQuick 2.15
import QtQuick.Window 2.15
import "apps.js" as AppsData

Window {
    id: root
    visible: true
    width: 1280
    height: 820
    minimumWidth: 800
    minimumHeight: 520
    title: "Launchpad"
    color: "#111111"

    readonly property int cellSize: 96
    readonly property int iconSize: 64
    readonly property int spacingSize: 28
    readonly property var apps: AppsData.APPS

    Flickable {
        anchors.fill: parent
        anchors.margins: 24
        contentWidth: width
        contentHeight: grid.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Grid {
            id: grid
            width: parent.width
            columns: Math.max(1, Math.floor(width / (root.cellSize + root.spacingSize)))
            spacing: root.spacingSize

            Repeater {
                model: root.apps

                delegate: Item {
                    required property var modelData
                    width: root.cellSize
                    height: root.cellSize

                    Image {
                        anchors.centerIn: parent
                        width: root.iconSize
                        height: root.iconSize
                        source: modelData.icon ? "image://icon/" + modelData.icon : ""
                        asynchronous: false
                        cache: true
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }
                }
            }
        }
    }
}
