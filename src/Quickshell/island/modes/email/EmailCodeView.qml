import QtQuick
import "../../../bar" as Bar

Item {
    id: root

    property bool active: false
    property string code: ""
    property string sender: ""
    property bool copied: false
    property string fontFamily: ""
    property string iconFontFamily: ""

    visible: opacity > 0
    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    Row {
        anchors.centerIn: parent
        spacing: 12

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰇮"
            color: "#7dd3fc"
            font.family: root.iconFontFamily
            font.pixelSize: 26
            renderType: Text.NativeRendering
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: 210
                text: root.code
                color: Bar.Theme.textMain
                font.family: root.fontFamily
                font.pixelSize: 28
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Text {
                width: 210
                text: (root.copied ? "Copied from " : "Code from ") + (root.sender || "Email")
                color: Bar.Theme.textSecondary
                font.family: root.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
        }
    }
}
