import QtQuick
import QtQuick.Layouts

Item {
    id: root
    height: 40

    required property string label
    required property string sym
    required property bool   selected
    signal clicked()

    readonly property color accent: "#0a84ff"

    // ── Fundo ─────────────────────────────────────────────────────────────
    Rectangle {
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        radius: 8
        color: root.selected
            ? Qt.rgba(0.04, 0.52, 1, 0.18)
            : hma.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
        border.width: root.selected ? 1 : 0
        border.color: Qt.rgba(0.04, 0.52, 1, 0.35)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // ── Conteúdo ──────────────────────────────────────────────────────────
    RowLayout {
        anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
        spacing: 10

        // Ícone
        Rectangle {
            width:  26
            height: 26
            radius: 7
            color: root.selected ? root.accent : Qt.rgba(1, 1, 1, 0.10)
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: root.sym
                color: root.selected ? "#ffffff" : "#98989f"
                font.pixelSize: 13
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        // Label
        Text {
            text: root.label
            color: root.selected ? "#ffffff" : "#98989f"
            font.pixelSize: 13
            font.weight: root.selected ? Font.Medium : Font.Normal
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Item { Layout.fillWidth: true }

        // Indicador ativo
        Rectangle {
            width:   3
            height:  16
            radius:  2
            color:   root.accent
            opacity: root.selected ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }

    // ── Interação ─────────────────────────────────────────────────────────
    MouseArea {
        id: hma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked:    root.clicked()
    }
}