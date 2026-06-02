import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import "../AstreaComponents" as Astrea

Item {
    id: sheet

    property string to: ""
    property string subject: ""
    property string messageBody: ""
    property string statusText: ""
    property bool canSend: false
    property color softSurface: Astrea.Theme.cardBg
    signal closeRequested()
    signal toEdited(string value)
    signal subjectEdited(string value)
    signal bodyEdited(string value)
    signal sendRequested()

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, Astrea.Theme.themeMode === 1 ? 0.10 : 0.22)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: sheet.closeRequested()
    }

    Rectangle {
        id: composer
        width: Math.min(560, parent.width - 48)
        height: Math.min(484, parent.height - 48)
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 24
        anchors.bottomMargin: 24
        radius: Astrea.Theme.cardRadius
        color: Astrea.Theme.cardBg
        border.width: 1
        border.color: Astrea.Theme.cardBorder
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Astrea.Theme.themeMode === 1 ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(0, 0, 0, 0.52)
            shadowBlur: 0.9
            shadowVerticalOffset: 10
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Astrea.Theme.spacingLarge
            spacing: Astrea.Theme.spacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Astrea.Theme.spacing

                Astrea.DisplayLabel {
                    Layout.fillWidth: true
                    text: "New Message"
                    textColor: Astrea.Theme.textPrimary
                    font.pixelSize: Astrea.Theme.fontSizeTitle
                    font.weight: Astrea.Theme.fontWeightDemiBold
                }

                Astrea.Button {
                    text: ""
                    iconText: "\uf00d"
                    iconFontFamily: "JetBrainsMono Nerd Font"
                    controlWidth: 34
                    controlHeight: 32
                    flat: true
                    onClicked: sheet.closeRequested()
                }
            }

            ComposeField {
                Layout.fillWidth: true
                label: "To"
                value: sheet.to
                surfaceColor: sheet.softSurface
                onEdited: value => sheet.toEdited(value)
            }

            ComposeField {
                Layout.fillWidth: true
                label: "Subject"
                value: sheet.subject
                surfaceColor: sheet.softSurface
                onEdited: value => sheet.subjectEdited(value)
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Astrea.Theme.controlRadius + 3
                color: sheet.softSurface
                border.width: 1
                border.color: bodyField.activeFocus ? Astrea.Theme.accent : Astrea.Theme.cardBorder

                TextArea {
                    id: bodyField
                    anchors.fill: parent
                    anchors.margins: 10
                    text: sheet.messageBody
                    color: Astrea.Theme.textPrimary
                    selectedTextColor: Astrea.Theme.accentForeground
                    selectionColor: Astrea.Theme.accent
                    placeholderText: "Write a message"
                    placeholderTextColor: Astrea.Theme.textTertiary
                    wrapMode: TextEdit.WordWrap
                    background: null
                    font.family: Astrea.Theme.fontFamily
                    font.pixelSize: Astrea.Theme.fontSizeNormal
                    onTextChanged: sheet.bodyEdited(text)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Astrea.Theme.spacing

                Astrea.TextLabel {
                    Layout.fillWidth: true
                    text: sheet.statusText
                    textColor: Astrea.Theme.textSecondary
                    font.pixelSize: Astrea.Theme.fontSizeSmall
                    elide: Text.ElideRight
                }

                Astrea.Button {
                    text: "Discard"
                    flat: true
                    onClicked: sheet.closeRequested()
                }

                Astrea.Button {
                    text: "Send"
                    primary: true
                    enabled: sheet.canSend
                    onClicked: sheet.sendRequested()
                }
            }
        }
    }
}
