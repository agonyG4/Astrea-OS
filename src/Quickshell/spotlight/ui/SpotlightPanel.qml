import QtQuick
import QtQuick.Layouts
import "../../AstreaI18n" as AstreaI18n

Rectangle {
    id: root

    property var controller: null
    readonly property string fontFamily: controller ? controller.fontFamily : "SF Pro Display"
    readonly property color placeholderTextColor: "#66FFFFFF"

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: parent.height * 0.25

    width: 600
    height: searchInput.text.length > 0 ? Math.min(contentCol.implicitHeight + 28, 450) : 58
    radius: 24

    color: "#80343434"
    border.color: "#33FFFFFF"
    border.width: 1
    clip: true

    scale: controller && controller.open ? 1.0 : 0.98
    opacity: controller && controller.open ? 1.0 : 0.0

    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
    Behavior on opacity { NumberAnimation { duration: 120 } }

    ColumnLayout {
        id: contentCol
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 14
        }
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 12

            Text {
                text: "⌕"
                font.family: root.fontFamily
                font.pixelSize: 24
                color: "#99FFFFFF"
                Layout.leftMargin: 8
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 30

                Text {
                    anchors.fill: parent
                    text: (AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["spotlight.placeholder"]) || "Spotlight Search"
                    font.family: root.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.Light
                    color: root.placeholderTextColor
                    verticalAlignment: Text.AlignVCenter
                    visible: searchInput.text.length === 0
                    renderType: Text.NativeRendering
                }

                TextInput {
                    id: searchInput
                    anchors.fill: parent

                    font.family: root.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.Light
                    color: "white"
                    selectionColor: "#407AFF"
                    selectedTextColor: "white"
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter

                    onTextChanged: if (root.controller) root.controller.scheduleResults(text)

                    Keys.onEscapePressed: if (root.controller) root.controller.close()
                    Keys.onReturnPressed: resultsList.launchCurrent()
                    Keys.onDownPressed: resultsList.move(1)
                    Keys.onUpPressed: resultsList.move(-1)

                    Component.onCompleted: forceActiveFocus()
                    onVisibleChanged: if (visible) { forceActiveFocus(); text = "" }
                }
            }

            SpotlightWeatherChip {
                controller: root.controller
                textColor: root.placeholderTextColor
                fontFamily: root.fontFamily
            }
        }

        SpotlightResultsList {
            id: resultsList
            controller: root.controller
            queryText: searchInput.text
            fontFamily: root.fontFamily
            onLaunchRequested: index => {
                if (root.controller)
                    root.controller.launch(index)
            }
        }
    }
}
