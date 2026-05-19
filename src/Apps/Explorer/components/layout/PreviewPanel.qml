import QtQuick 2.15
import QtQuick.Controls.impl 2.15
import "../.."
import "../../AstreaI18n" as AstreaI18n

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

        Image {
            source: {
                var item = AppState.selectedItem()
                return AppState.portalIconSource(AppState.fileIconName(AppState.selectedFile, false, item && item.fileExecutable), 64)
            }
            width: 64; height: 64
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            sourceSize: Qt.size(64, 64)
            anchors.horizontalCenter: parent.horizontalCenter
            visible: true
        }

        Text {
            width: parent.width
            text: AppState.selectedFile
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            font { pixelSize: 13; weight: Font.Normal }
            color: Theme.text
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        Column {
            width: parent.width; spacing: 6
            Repeater {
                model: [
                    { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.preview_panel.label.tipo"]) || "Kind"),       value: AppState.selectedFile.split(".").pop().toUpperCase() || "—" },
                    { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.preview_panel.label.modificado"]) || "Modified"), value: "—" },
                    { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.preview_panel.label.criado"]) || "Created"),     value: "—" },
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
        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.preview_panel.text.nenhum_item_selecionado"]) || "No item\\nselected")
        color: Theme.textTer; font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        visible: AppState.selectedFile === ""
    }
}
