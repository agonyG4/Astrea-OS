import QtQuick
import "../../../bar" as Bar

Item {
    id: root

    property bool active: false

    anchors.fill: parent

    GamemodeNotifyView {
        anchors.fill: parent
        active: root.active
        fontFamily: Bar.Theme.iconFontFamily
    }
}
