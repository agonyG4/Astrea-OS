import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".." as Components

Item {
    id: root

    property alias text: field.text
    property alias placeholderText: field.placeholderText
    property alias selectedText: field.selectedText
    property alias echoMode: field.echoMode
    property bool showSearchIcon: true
    property bool showClearButton: true
    property bool clearOnEscape: true
    property bool selectAllOnFocus: false
    property string iconText: "⌕"
    property color accent: Components.Theme.accent
    property color textPrimary: Components.Theme.textPrimary
    property color textSecondary: Components.Theme.textSecondary
    property color textTertiary: Components.Theme.textTertiary
    property color surfaceColor: Components.Theme.cardBg
    property color borderColor: Components.Theme.cardBorder
    property int controlHeight: 40

    signal textEdited(string text)
    signal accepted(string text)
    signal cleared()
    signal escapePressed()

    implicitHeight: controlHeight
    implicitWidth: 260

    function focusField(selectText) {
        field.forceActiveFocus()
        if (selectText)
            field.selectAll()
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        radius: Components.Theme.controlRadius + 3
        color: area.pressed
            ? frame.pressedBg
            : (area.containsMouse || field.activeFocus ? frame.hoverBg : root.surfaceColor)
        border.width: 1
        border.color: field.activeFocus ? root.accent : root.borderColor

        readonly property color hoverBg: Components.Theme.themeMode === 1
            ? Qt.rgba(0, 0, 0, 0.045)
            : Qt.rgba(1, 1, 1, 0.08)
        readonly property color pressedBg: Components.Theme.themeMode === 1
            ? Qt.rgba(0, 0, 0, 0.065)
            : Qt.rgba(1, 1, 1, 0.11)

        Behavior on color { ColorAnimation { duration: Components.Theme.animationFast } }
        Behavior on border.color { ColorAnimation { duration: Components.Theme.animationFast } }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.IBeamCursor
            acceptedButtons: Qt.LeftButton
            onPressed: mouse => {
                mouse.accepted = false
                field.forceActiveFocus()
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 13
            anchors.rightMargin: 8
            spacing: 8

            Text {
                visible: root.showSearchIcon
                text: root.iconText
                color: field.activeFocus ? root.accent : root.textTertiary
                font.family: Components.Theme.fontFamily
                font.pixelSize: Components.Theme.fontSizeLarge
                font.weight: Components.Theme.fontWeightDemiBold
                verticalAlignment: Text.AlignVCenter
                Layout.alignment: Qt.AlignVCenter

                Behavior on color { ColorAnimation { duration: Components.Theme.animationFast } }
            }

            TextField {
                id: field

                Layout.fillWidth: true
                Layout.fillHeight: true
                selectByMouse: true
                selectedTextColor: Components.Theme.accentForeground
                selectionColor: root.accent
                color: root.textPrimary
                placeholderTextColor: root.textTertiary
                background: null
                font.family: Components.Theme.fontFamily
                font.pixelSize: Components.Theme.fontSizeNormal
                font.weight: Components.Theme.fontWeightMedium
                verticalAlignment: TextInput.AlignVCenter
                leftPadding: 0
                rightPadding: 0

                onTextEdited: root.textEdited(text)
                onAccepted: root.accepted(text)
                onActiveFocusChanged: {
                    if (activeFocus && root.selectAllOnFocus)
                        Qt.callLater(selectAll)
                }

                Keys.onPressed: event => {
                    if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_A) {
                        field.selectAll()
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Escape) {
                        if (root.clearOnEscape && field.text !== "") {
                            field.text = ""
                            root.textEdited("")
                            root.cleared()
                        }
                        root.escapePressed()
                        event.accepted = true
                    }
                }
            }

            Rectangle {
                visible: root.showClearButton && field.text !== ""
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: 12
                color: clearArea.pressed
                    ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                    : (clearArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

                Behavior on color { ColorAnimation { duration: Components.Theme.animationFast } }

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: clearArea.containsMouse ? root.textPrimary : root.textSecondary
                    font.family: Components.Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Components.Theme.fontWeightDemiBold
                }

                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        field.text = ""
                        field.forceActiveFocus()
                        root.textEdited("")
                        root.cleared()
                    }
                }
            }
        }
    }
}
