import QtQuick
import QtQuick.Layouts
import "../../AstreaComponents" as Astrea

Rectangle {
    id: card
    default property alias content: contentColumn.data

    Layout.fillWidth: true
    implicitHeight: contentColumn.implicitHeight + 36
    radius: 18 // Estilo Premium do Weather
    color: Astrea.Theme.cardBg
    border.width: 1
    border.color: Astrea.Theme.cardBorder

    ColumnLayout {
        id: contentColumn
        width: parent.width - 32
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 12
    }
}
