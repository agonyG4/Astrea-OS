import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components/layout" as LayoutComponents
import "components/views" as ViewComponents
import "AstreaComponents" as UI
import "."
import "AstreaI18n" as AstreaI18n

Dialog {
    id: dialog
    modal: true
    focus: true
    dim: true
    width: 1080
    height: 720
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    closePolicy: Popup.NoAutoClose

    property string mode: "open_file" // open_file | save_file | select_folder
    property string startFolder: AppState.currentPath || AppState.homePath
    property string acceptLabel: mode === "save_file"
        ? ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.file_dialog.accept.save"]) || "Save")
        : mode === "select_folder"
            ? ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.file_dialog.accept.select_folder"]) || "Select folder")
            : ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.file_dialog.accept.open"]) || "Open")
    property string dialogTitle: mode === "save_file"
        ? ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.file_dialog.title.save"]) || "Save file")
        : mode === "select_folder"
            ? ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.file_dialog.title.select_folder"]) || "Select folder")
            : ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.file_dialog.title.open"]) || "Open file")
    property string initialViewMode: "icon"
    property string selectedName: ""
    property var nameFilters: []
    property bool allowMultiple: false
    signal fileChosen(string filePath, string fileUrl)
    signal filesChosen(var files)

    Shortcut {
        sequence: "Escape"
        onActivated: dialog.reject()
    }

    background: Rectangle {
        radius: UI.Theme.cornerRadiusLarge
        color: UI.Theme.windowBackground
        border.color: UI.Theme.windowBorder
        border.width: 1
    }

    Overlay.modal: Rectangle {
        color: "#99000000"
    }

    function extractPatterns(filters) {
        var patterns = []
        if (!filters)
            return patterns

        for (var i = 0; i < filters.length; i++) {
            var filter = filters[i] || ""
            var match = /\(([^)]*)\)/.exec(filter)
            if (!match || !match[1])
                continue

            var tokens = match[1].split(/\s+/)
            for (var j = 0; j < tokens.length; j++) {
                var token = tokens[j].trim()
                if (!token)
                    continue
                patterns.push(token)
            }
        }

        return patterns
    }

    function selectedDialogItem() {
        return AppState.selectedItem()
    }

    function selectedDialogItems(onlyFiles) {
        var names = AppState.selectedFiles || []
        if (names.length === 0)
            return []

        var selected = {}
        for (var n = 0; n < names.length; n++)
            selected[names[n]] = true

        var items = []
        for (var i = 0; i < AppState.fileModel.count; i++) {
            var item = AppState.fileModel.get(i)
            if (!item || !selected[item.fileName])
                continue
            if (onlyFiles && item.fileIsDir)
                continue
            items.push({
                filePath: item.filePath,
                fileUrl: item.fileUrl,
                fileName: item.fileName,
                fileIsDir: item.fileIsDir
            })
        }
        return items
    }

    function selectedDialogFileItems() {
        return selectedDialogItems(true)
    }

    function selectionSummary() {
        if (mode === "select_folder")
            return AppState.currentPath
        if (allowMultiple && mode === "open_file") {
            var files = selectedDialogFileItems()
            if (files.length > 1)
                return files.length + " itens selecionados"
        }
        return selectedName !== "" ? selectedName : "Nenhum item selecionado"
    }

    function updateSelectedNameFromState() {
        var item = selectedDialogItem()
        if (mode === "save_file") {
            if (item && !item.fileIsDir)
                selectedName = item.fileName
            return
        }

        selectedName = item ? item.fileName : ""
    }

    function canAccept() {
        var item = selectedDialogItem()
        if (mode === "select_folder")
            return !!AppState.currentPath
        if (mode === "save_file")
            return selectedName.trim() !== ""
        if (allowMultiple)
            return selectedDialogFileItems().length > 0
        return !!item && !item.fileIsDir
    }

    function buildResult() {
        var item = selectedDialogItem()
        if (mode === "select_folder") {
            var folderPath = item && item.fileIsDir ? item.filePath : AppState.currentPath
            return {
                filePath: folderPath,
                fileUrl: AppState.fileUrlForPath(folderPath)
            }
        }

        if (mode === "save_file") {
            var baseDir = item && item.fileIsDir ? item.filePath : AppState.currentPath
            var filePath = AppState.joinPath(baseDir, selectedName.trim())
            return {
                filePath: filePath,
                fileUrl: AppState.fileUrlForPath(filePath)
            }
        }

        if (allowMultiple) {
            var files = selectedDialogFileItems()
            if (files.length === 0)
                return null
            return {
                files: files,
                filePath: files[0].filePath,
                fileUrl: files[0].fileUrl
            }
        }

        if (!item || item.fileIsDir)
            return null

        return {
            filePath: item.filePath,
            fileUrl: item.fileUrl
        }
    }

    function chooseCurrentSelection() {
        var result = buildResult()
        if (!result)
            return
        if (result.files && result.files.length > 1)
            filesChosen(result.files)
        else
            fileChosen(result.filePath, result.fileUrl)
        close()
    }

    function openDialog() {
        AppState.dialogActive = true
        AppState.dialogMode = mode
        AppState.dialogFilePatterns = extractPatterns(nameFilters)
        AppState.clearSelection()
        if (AppState.isPortalDialog)
            AppState.viewMode = initialViewMode === "list" ? "list" : "icon"
        if (mode !== "save_file")
            selectedName = ""

        if (AppState.currentPath !== startFolder)
            AppState.navigateTo(startFolder)
        else
            AppState.refreshCurrentFolder()

        open()
    }

    onAboutToHide: {
        AppState.dialogActive = false
        AppState.dialogMode = "browse"
        AppState.dialogFilePatterns = []
        AppState.clearSelection()
    }

    onOpened: {
        if (mode === "save_file")
            saveNameField.focusField(true)
    }

    onSelectedNameChanged: {
        if (mode === "save_file" && saveNameField.text !== selectedName)
            saveNameField.text = selectedName
    }

    Connections {
        target: AppState

        function onSelectedFileChanged() {
            dialog.updateSelectedNameFromState()
        }

        function onDialogFileActivated(path, fileUrl) {
            if (dialog.mode === "save_file") {
                var name = path.split("/").pop()
                if (name)
                    dialog.selectedName = name
            }
            dialog.fileChosen(path, fileUrl)
            dialog.close()
        }
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: UI.Theme.cardBg

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                UI.TextLabel {
                    text: dialog.dialogTitle
                    textColor: UI.Theme.textPrimary
                    font.pixelSize: UI.Theme.fontSizeLarge
                    font.weight: UI.Theme.fontWeightDemiBold
                }

                Item { Layout.fillWidth: true }

                UI.Button {
                    text: ""
                    iconText: "×"
                    flat: true
                    controlWidth: 34
                    controlHeight: 34
                    minWidth: 34
                    iconSize: 20
                    onClicked: dialog.reject()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            LayoutComponents.Sidebar {
                Layout.fillHeight: true
                Layout.preferredWidth: 256
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: UI.Theme.windowBackground

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    LayoutComponents.Toolbar {
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: UI.Theme.windowBackground

                        Loader {
                            anchors.fill: parent
                            sourceComponent: AppState.viewMode === "list" ? listComp : iconComp
                        }

                        UI.TextLabel {
                            anchors.centerIn: parent
                            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.file_dialog.text.pasta_vazia"]) || "Empty folder")
                            textColor: UI.Theme.textTertiary
                            font.pixelSize: UI.Theme.fontSizeLarge
                            visible: !AppState.loadingDir && AppState.fileModel.count === 0 && AppState.loadError === ""
                        }

                        UI.TextLabel {
                            anchors.centerIn: parent
                            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.file_dialog.text.carregando"]) || "Loading...")
                            textColor: UI.Theme.textTertiary
                            font.pixelSize: UI.Theme.fontSizeLarge
                            visible: AppState.loadingDir
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: mode === "save_file" ? 92 : 58
            color: UI.Theme.cardBg
            border.width: 1
            border.color: UI.Theme.cardBorder

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    visible: dialog.mode === "save_file"
                    spacing: 10

                    UI.TextLabel {
                        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.file_dialog.text.nome"]) || "Name:")
                        textColor: UI.Theme.textTertiary
                        font.pixelSize: UI.Theme.fontSizeSmall
                        Layout.alignment: Qt.AlignVCenter
                    }

                    UI.SearchField {
                        id: saveNameField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        showSearchIcon: false
                        showClearButton: false
                        controlHeight: 38
                        text: dialog.selectedName
                        placeholderText: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.file_dialog.placeholderText.arquivo"]) || "file")
                        onTextEdited: dialog.selectedName = text
                        onAccepted: if (dialog.canAccept()) dialog.chooseCurrentSelection()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    UI.TextLabel {
                        Layout.fillWidth: true
                        text: dialog.selectionSummary()
                        textColor: UI.Theme.textTertiary
                        font.pixelSize: UI.Theme.fontSizeSmall
                        elide: Text.ElideMiddle
                    }

                    UI.Button {
                        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.file_dialog.text.cancelar"]) || "Cancel")
                        flat: true
                        controlHeight: 34
                        onClicked: dialog.reject()
                    }

                    UI.Button {
                        text: dialog.acceptLabel
                        primary: true
                        controlHeight: 34
                        enabled: dialog.canAccept()
                        onClicked: dialog.chooseCurrentSelection()
                    }
                }
            }
        }
    }

    Component { id: listComp; ViewComponents.FileListView {} }
    Component { id: iconComp; ViewComponents.FileIconView {} }
}
