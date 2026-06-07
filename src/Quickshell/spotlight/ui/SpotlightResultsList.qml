import QtQuick
import QtQuick.Layouts
import "../../components" as Components

ColumnLayout {
    id: root

    property var controller: null
    property string queryText: ""
    property string fontFamily: "SF Pro Display"
    readonly property int resultRowHeight: 50
    readonly property int resultIconSize: 40
    readonly property int resultIconSourceSize: 80
    readonly property int count: resultList.count

    signal launchRequested(int index)

    Layout.fillWidth: true
    visible: queryText.length > 0 && resultList.count > 0
    spacing: 0

    function move(delta) {
        if (resultList.count <= 0)
            return
        resultList.currentIndex = (resultList.currentIndex + delta + resultList.count) % resultList.count
    }

    function launchCurrent() {
        if (resultList.count > 0)
            root.launchRequested(resultList.currentIndex)
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: "#15FFFFFF"
        Layout.topMargin: 12
        Layout.bottomMargin: 8
    }

    ListView {
        id: resultList

        Layout.fillWidth: true
        implicitHeight: Math.min(count, 6) * root.resultRowHeight
        model: root.controller ? root.controller.results : []
        currentIndex: 0
        interactive: false

        delegate: Rectangle {
            width: resultList.width
            height: root.resultRowHeight
            radius: 7
            color: resultList.currentIndex === index ? "#007AFF" : "transparent"

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 15

                Components.AppIcon {
                    Layout.preferredWidth: root.resultIconSize
                    Layout.preferredHeight: root.resultIconSize
                    entry: modelData
                    iconRadius: 7
                    sourcePixelSize: root.resultIconSourceSize
                    fallbackRadius: 7
                    fallbackColor: "#22FFFFFF"
                }

                Text {
                    text: modelData ? modelData.name : ""
                    font.family: root.fontFamily
                    font.pixelSize: 17
                    color: "white"
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: resultList.currentIndex = index
                onClicked: root.launchRequested(index)
            }
        }
    }
}
