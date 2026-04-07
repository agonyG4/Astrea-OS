import QtQuick 2.15
import QtQuick.Controls.impl 2.15
import "../.."

Rectangle {
    color: Theme.bg
    clip: true

    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    // Divisor esquerdo
    Rectangle { width: 1; height: parent.height; color: Theme.border }

    // ── Arquivo selecionado ───────────────────────────────────
    Column {
        anchors { fill: parent; margins: 16 }
        spacing: 12
        visible: AppState.selectedFile !== ""

        IconImage {
            name: AppState.fileIconName(AppState.selectedFile, false)
            width: 64; height: 64
            sourceSize: Qt.size(64, 64)
            anchors.horizontalCenter: parent.horizontalCenter
            visible: true
        }

        Text {
            width: parent.width
            text: AppState.selectedFile
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            font { pixelSize: 13; weight: Font.Medium }
            color: Theme.text
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        Column {
            width: parent.width; spacing: 6
            Repeater {
                model: [
                    { label: "Tipo",       value: AppState.selectedFile.split(".").pop().toUpperCase() || "—" },
                    { label: "Modificado", value: "—" },
                    { label: "Criado",     value: "—" },
                ]
                Column {
                    width: parent.width; spacing: 2
                    Text { text: modelData.label; color: Theme.textTer;  font.pixelSize: 11 }
                    Text { text: modelData.value; color: Theme.textSec;  font.pixelSize: 12; wrapMode: Text.Wrap; width: parent.width }
                }
            }
        }
    }

    // ── Placeholder ───────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        text: "Nenhum item\nselecionado"
        color: Theme.textTer; font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        visible: AppState.selectedFile === ""
    }
}
