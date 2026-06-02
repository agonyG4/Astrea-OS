import QtQuick
import "../AstreaComponents" as Astrea

Rectangle {
    id: pill

    property string label: ""
    property int value: 0
    property color surfaceColor: Astrea.Theme.cardBg

    implicitWidth: metricRow.implicitWidth + 20
    implicitHeight: 34
    radius: Astrea.Theme.controlRadius
    color: surfaceColor
    border.width: 1
    border.color: Astrea.Theme.cardBorder

    Row {
        id: metricRow
        anchors.centerIn: parent
        spacing: 7

        Astrea.TextLabel {
            text: pill.label
            textColor: Astrea.Theme.textSecondary
            font.pixelSize: Astrea.Theme.fontSizeSmall
        }

        Astrea.TextLabel {
            text: pill.value
            textColor: Astrea.Theme.textPrimary
            font.pixelSize: Astrea.Theme.fontSizeSmall
            font.weight: Astrea.Theme.fontWeightDemiBold
        }
    }
}
