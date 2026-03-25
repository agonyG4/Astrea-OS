import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: sel

    // ── Interface ─────────────────────────────────────────────────────────
    property string label: ""
    property var    options: []
    property int    selectedIndex: -1
    signal selected(int index)
    property bool isButton: false

    // ── Styling (Matching System Defaults) ───────────────────────────────
    property color accent:        "#0a84ff"
    property color textPrimary:   "#ffffff"
    property color textSecondary: "#98989f"
    property color cardBg:        Qt.rgba(1, 1, 1, 0.05)
    property color cardBorder:    Qt.rgba(1, 1, 1, 0.08)
    property color popupBg:       Qt.rgba(0.13, 0.13, 0.14, 0.97)

    implicitHeight: 34

    readonly property int maxVisible: 5
    readonly property int itemH:      36
    readonly property int popupPad:   6
    readonly property int listH: Math.min(sel.options.length, sel.maxVisible) * sel.itemH + popupPad * 2

    // ── Main Button ───────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 8
        color: btnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : sel.cardBg
        border.width: 1
        border.color: (dropdown.visible || btnArea.pressed) ? sel.accent : sel.cardBorder
        
        Behavior on color        { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: sel.label
                color: sel.textPrimary
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            Text {
                visible: !sel.isButton
                text: dropdown.visible ? "⌃" : "⌄"
                color: sel.textSecondary
                font.pixelSize: 11
            }
            Text {
                visible: sel.isButton
                text: "\uf03e"
                font.family: "JetBrainsMono Nerd Font"
                color: btnArea.containsMouse ? sel.accent : sel.textSecondary
                font.pixelSize: 11
            }
        }

        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (sel.isButton) sel.selected(-1)
                else dropdown.visible ? dropdown.close() : dropdown.open()
            }
        }
    }

    // ── Dialog (Popup) ────────────────────────────────────────────────────
    Popup {
        id: dropdown
        y: sel.height + 4
        width: Math.max(sel.width, 160)
        height: sel.listH
        padding: sel.popupPad
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        visible: false
        enabled: !sel.isButton

        background: Rectangle {
            radius: 10
            color: sel.popupBg
            border.width: 1
            border.color: sel.cardBorder
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 130; easing.type: Easing.OutCubic }
            NumberAnimation { property: "y"; from: sel.height; to: sel.height + 4; duration: 130; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
        }

        contentItem: ListView {
            id: listView
            clip: true
            model: sel.options
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            onVisibleChanged: if (visible && sel.selectedIndex >= 0) positionViewAtIndex(sel.selectedIndex, ListView.Contain)

            ScrollBar.vertical: ScrollBar {
                policy: sel.options.length > sel.maxVisible ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Qt.rgba(1, 1, 1, 0.25) }
                background: Rectangle { color: "transparent" }
            }

            delegate: Rectangle {
                readonly property bool active: sel.selectedIndex === index
                width: listView.width
                height: sel.itemH
                radius: 7
                color: active
                    ? Qt.rgba(sel.accent.r, sel.accent.g, sel.accent.b, 0.18)
                    : rowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    Text {
                        Layout.fillWidth: true
                        text: modelData
                        color: active ? sel.accent : sel.textPrimary
                        font.pixelSize: 13
                        font.weight: active ? Font.Medium : Font.Normal
                    }
                    Text {
                        visible: active
                        text: "✓"
                        color: sel.accent
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { sel.selected(index); dropdown.close() }
                }
            }
        }
    }
}
