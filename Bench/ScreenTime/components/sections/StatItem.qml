import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../common" as Common
import "../.."

ColumnLayout {
    property string label: ""
    property string value: ""

    Layout.fillWidth: true
    spacing: 2

    Common.TextLabel {
        Layout.fillWidth: true
        text: label
        font.pixelSize: Theme.fontTiny
        font.weight: 600
        textColor: Theme.textTertiary
        elide: Text.ElideRight
    }

    Common.TextLabel {
        Layout.fillWidth: true
        text: value
        font.pixelSize: Theme.fontRegular
        font.weight: 600
        textColor: Theme.textPrimary
        elide: Text.ElideRight
    }
}
