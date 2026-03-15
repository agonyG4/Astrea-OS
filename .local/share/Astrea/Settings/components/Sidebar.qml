import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    color: Qt.rgba(1, 1, 1, 0.05)

    required property var model
    required property int selectedIndex
    signal selectIndex(int i)

    readonly property color accent: "#0a84ff"

    // ── Borda direita ─────────────────────────────────────────────────────
    Rectangle {
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: 1
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    // ── Nav items ─────────────────────────────────────────────────────────
    ColumnLayout {
        anchors { fill: parent; topMargin: 16; bottomMargin: 16 }
        spacing: 2

        Repeater {
            model: root.model

            delegate: Item {
                Layout.fillWidth: true
                height: 40

                readonly property bool active: root.selectedIndex === model.index

                Rectangle {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    radius: 8
                    color: active
                        ? Qt.rgba(0.04, 0.52, 1, 0.18)
                        : hma.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                    border.width: active ? 1 : 0
                    border.color: Qt.rgba(0.04, 0.52, 1, 0.35)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                    spacing: 10

                    // Ícone Nerd Font
                    Rectangle {
                        width:  30
                        height: 30
                        radius: 8
                        color: active ? root.accent : Qt.rgba(1, 1, 1, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: model.sym
                            color: active ? "#ffffff" : "#98989f"
                            font.pixelSize: 15
                            font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    Text {
                        text: model.label
                        color: active ? "#ffffff" : "#98989f"
                        font.pixelSize: 13
                        font.weight: active ? Font.Medium : Font.Normal
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    Item { Layout.fillWidth: true }

                }

                MouseArea {
                    id: hma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    root.selectIndex(model.index)
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}