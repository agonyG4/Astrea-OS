import QtQuick 2.15
import QtQuick.Controls.impl 2.15
import "../.."
import "../../AstreaI18n" as AstreaI18n

Rectangle {
    id: root

    readonly property var selectedItem: AppState.fileModelRevision >= 0 ? AppState.selectedItem() : null
    readonly property string selectedName: AppState.selectedFile
    readonly property bool hasSelection: selectedName !== "" && selectedItem !== null
    readonly property bool selectedIsDir: Boolean(selectedItem && selectedItem.fileIsDir)
    readonly property bool selectedExecutable: Boolean(selectedItem && selectedItem.fileExecutable)
    readonly property string selectedPath: selectedItem ? (selectedItem.filePath || "") : ""
    readonly property string selectedUrl: selectedItem ? (selectedItem.fileUrl || "") : ""
    readonly property string selectedKind: selectedItem && selectedItem.fileKind ? selectedItem.fileKind : fallbackKind(selectedName, selectedIsDir)
    readonly property string selectedPreviewUrl: selectedItem ? (selectedItem.filePreviewUrl || "") : ""
    readonly property bool selectedPreviewable: AppState.isPreviewableFile(selectedName, selectedIsDir)
    readonly property string selectedPreviewSource: selectedPreviewUrl !== "" ? selectedPreviewUrl
        : (selectedPreviewable ? selectedUrl : "")

    color: Theme.bg
    clip: true

    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    function fallbackKind(name, isDir) {
        if (isDir)
            return "Pasta"
        if (!name)
            return "Arquivo"
        var dot = name.lastIndexOf(".")
        if (dot <= 0 || dot === name.length - 1)
            return "Arquivo"
        return name.slice(dot + 1).toUpperCase()
    }

    function selectedIndex() {
        for (var i = 0; i < AppState.fileModel.count; i++) {
            var item = AppState.fileModel.get(i)
            if (item && item.fileName === AppState.selectedFile)
                return i
        }
        return -1
    }

    function warmSelectedPreview() {
        if (!AppState.showPreview || !selectedPreviewable || selectedPreviewUrl !== "" || !AppState.currentPath)
            return
        var index = selectedIndex()
        if (index >= 0)
            AppState.requestThumbnailWarm(AppState.currentPath, index, 1)
    }

    onSelectedNameChanged: selectedWarmTimer.restart()
    onSelectedPreviewUrlChanged: selectedWarmTimer.restart()
    onVisibleChanged: selectedWarmTimer.restart()

    Timer {
        id: selectedWarmTimer
        interval: 80
        repeat: false
        onTriggered: root.warmSelectedPreview()
    }

    // Divisor esquerdo
    Rectangle { width: 1; height: parent.height; color: Theme.border }

    // ── Arquivo selecionado ───────────────────────────────────
    Column {
        anchors { fill: parent; margins: 16 }
        spacing: 12
        visible: root.hasSelection

        Item {
            width: parent.width
            height: root.selectedPreviewSource !== "" ? 150 : 76

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: 10
                visible: root.selectedPreviewSource !== ""
                color: Qt.rgba(1, 1, 1, 0.035)
                border.width: 1
                border.color: Theme.border
            }

            Image {
                id: previewImage
                anchors.centerIn: parent
                width: root.selectedPreviewSource !== "" ? parent.width - 18 : 64
                height: root.selectedPreviewSource !== "" ? parent.height - 18 : 64
                source: root.selectedPreviewSource
                visible: root.selectedPreviewSource !== "" && status === Image.Ready
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
                sourceSize: Qt.size(320, 240)
            }

            Image {
                anchors.centerIn: parent
                source: AppState.portalIconSource(AppState.fileIconName(root.selectedName, root.selectedIsDir, root.selectedExecutable), 64)
                width: 64
                height: 64
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                retainWhileLoading: true
                smooth: true
                sourceSize: Qt.size(64, 64)
                visible: root.selectedPreviewSource === "" || previewImage.status !== Image.Ready
            }
        }

        Text {
            width: parent.width
            text: root.selectedName
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
                    { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.preview_panel.label.tipo"]) || "Kind"),       value: root.selectedKind },
                    { label: "Tamanho", value: root.selectedIsDir ? "—" : AppState.formatSize(root.selectedItem ? root.selectedItem.fileSize : -1) },
                    { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.preview_panel.label.modificado"]) || "Modified"), value: AppState.formatDate(root.selectedItem ? root.selectedItem.fileModified : "") },
                    { label: "Local", value: root.selectedPath },
                ]
                Column {
                    width: parent.width; spacing: 2
                    Text { text: modelData.label; color: Theme.textTer;  font.pixelSize: 11 }
                    Text {
                        text: modelData.value
                        color: Theme.textSec
                        font.pixelSize: 12
                        wrapMode: Text.WrapAnywhere
                        width: parent.width
                        maximumLineCount: modelData.label === "Local" ? 3 : 2
                        elide: Text.ElideMiddle
                    }
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
        visible: !root.hasSelection
    }
}
