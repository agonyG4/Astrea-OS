import QtQuick
import "../../../bar" as Bar

Item {
    id: root

    property bool active: false
    property string code: ""
    property string sender: ""
    property bool copied: false

    anchors.fill: parent

    EmailCodeView {
        anchors.fill: parent
        active: root.active
        code: root.code
        sender: root.sender
        copied: root.copied
        fontFamily: Bar.Theme.fontFamily
        iconFontFamily: Bar.Theme.iconFontFamily
    }
}
