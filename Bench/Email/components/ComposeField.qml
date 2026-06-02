import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../AstreaComponents" as Astrea

Rectangle {
    id: fieldRoot

    property string label: ""
    property string value: ""
    property color surfaceColor: Astrea.Theme.cardBg
    signal edited(string text)

    implicitHeight: 42
    radius: Astrea.Theme.controlRadius + 3
    color: surfaceColor
    border.width: 1
    border.color: input.activeFocus ? Astrea.Theme.accent : Astrea.Theme.cardBorder

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Astrea.TextLabel {
            Layout.preferredWidth: 60
            text: fieldRoot.label
            textColor: Astrea.Theme.textSecondary
            font.pixelSize: Astrea.Theme.fontSizeSmall
            font.weight: Astrea.Theme.fontWeightDemiBold
        }

        TextField {
            id: input
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: fieldRoot.value
            color: Astrea.Theme.textPrimary
            selectedTextColor: Astrea.Theme.accentForeground
            selectionColor: Astrea.Theme.accent
            background: null
            font.family: Astrea.Theme.fontFamily
            font.pixelSize: Astrea.Theme.fontSizeNormal
            verticalAlignment: TextInput.AlignVCenter
            leftPadding: 0
            rightPadding: 0
            onTextEdited: fieldRoot.edited(text)
        }
    }
}
