import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "components/common" as Common

ApplicationWindow {
    id: root
    visible: true
    width: 920
    height: 680
    minimumWidth: 540
    minimumHeight: 420
    title: (dirty ? "*" : "") + displayName + " - Notepad"
    color: Theme.bg

    property string currentPath: ""
    property string displayName: "Untitled.html"
    property string lastSavedText: ""
    property bool dirty: editor.text !== lastSavedText
    property bool loadingFile: false
    property bool quitAfterSave: false
    property string pendingDialogMode: ""
    property string pendingDialogResultPath: ""
    property string pendingDialogStdout: ""
    property string statusText: "Pronto"
    property string visibleText: editor.getText(0, editor.length)
    property int wordCount: visibleText.trim().length === 0 ? 0 : visibleText.trim().split(/\s+/).length
    property var textColors: [
        { "name": "Azul", "value": "#0a84ff" },
        { "name": "Verde", "value": "#30d158" },
        { "name": "Amarelo", "value": "#ffd60a" },
        { "name": "Vermelho", "value": "#ff453a" },
        { "name": "Rosa", "value": "#ff2d55" },
        { "name": "Branco", "value": "#f2f2f7" }
    ]

    function closeEditorMenu() {
        editorContextMenu.menuVisible = false
        colorMenu.menuVisible = false
    }

    function showEditorMenu(localX, localY) {
        var mapped = editor.mapToItem(root.contentItem, localX, localY)
        editorContextMenu.menuX = Math.min(mapped.x, root.width - editorContextMenu.menuWidth - 10)
        editorContextMenu.menuY = Math.min(mapped.y, root.height - editorContextMenu.height - 10)
        editorContextMenu.menuVisible = true
    }

    function showCloseMenu() {
        closeConfirmMenu.menuX = Math.round((root.width - closeConfirmMenu.menuWidth) / 2)
        closeConfirmMenu.menuY = Math.round((root.height - closeConfirmMenu.height) / 2)
        closeConfirmMenu.menuVisible = true
    }

    function documentStartFolder() {
        if (currentPath) {
            var slashIndex = currentPath.lastIndexOf("/")
            if (slashIndex > 0)
                return currentPath.slice(0, slashIndex)
        }
        return StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
    }

    function dialogStartFolder(mode) {
        if (mode === "insert_image")
            return StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        return documentStartFolder()
    }

    function openSystemFileDialog(mode) {
        pendingDialogMode = mode
        pendingDialogStdout = ""
        pendingDialogResultPath = "/tmp/notepad_file_dialog_" + Date.now() + "_" + Math.floor(Math.random() * 1000000) + ".json"

        var options = {
            mode: mode,
            title: mode === "save_file" ? "Salvar Nota"
                 : mode === "insert_image" ? "Inserir imagem"
                                            : "Abrir Nota",
            startFolder: dialogStartFolder(mode),
            acceptLabel: mode === "save_file" ? "Salvar"
                       : mode === "insert_image" ? "Inserir"
                                                  : "Abrir",
            currentName: currentPath ? nameFromPath(currentPath) : "Untitled.html",
            filters: mode === "save_file"
                ? ["Notas (*.html *.htm)", "Texto (*.txt)", "Todos os arquivos (*)"]
                : mode === "insert_image"
                    ? ["Imagens (*.png *.jpg *.jpeg *.gif *.webp *.svg)", "Todos os arquivos (*)"]
                    : ["Notas (*.html *.htm)", "Texto (*.txt)", "Todos os arquivos (*)"]
        }

        portalDialogProcess.environment = {
            "BENCH_FILE_DIALOG_OPTIONS": JSON.stringify(options),
            "BENCH_FILE_DIALOG_RESULT_FILE": pendingDialogResultPath
        }
        portalDialogProcess.running = false
        portalDialogProcess.running = true
    }

    function parsePortalPayload(raw) {
        if (!raw)
            return null

        var prefix = "__BENCH_FILE_DIALOG__"
        var prefixIndex = raw.lastIndexOf(prefix)
        if (prefixIndex >= 0)
            raw = raw.slice(prefixIndex + prefix.length)

        raw = raw.trim()
        if (!raw)
            return null

        try {
            return JSON.parse(raw)
        } catch (error) {
            console.error("Failed to parse file dialog result:", error, raw)
            return null
        }
    }

    function handlePortalPayload(payload) {
        if (!payload || !payload.accepted) {
            statusText = "Dialogo cancelado"
            quitAfterSave = false
            return
        }

        if (pendingDialogMode === "open_file")
            openDocument(payload.filePath)
        else if (pendingDialogMode === "save_file")
            saveDocument(payload.filePath)
        else if (pendingDialogMode === "insert_image")
            insertImage(payload.filePath, payload.fileUrl)
    }

    function pathFromUrl(url) {
        var raw = url.toString()
        if (raw.indexOf("file://") === 0)
            raw = raw.slice(7)
        return decodeURIComponent(raw)
    }

    function nameFromPath(path) {
        if (!path)
            return "Untitled.html"
        var parts = path.split("/")
        return parts[parts.length - 1] || "Untitled.html"
    }

    function ensureNotePath(path) {
        if (!path)
            return path
        return /\.[^\/.]+$/.test(path) ? path : path + ".html"
    }

    function escapeHtml(value) {
        return (value || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
    }

    function serializedDocument() {
        if (!editor || editor.length === 0)
            return ""
        return editor.getFormattedText(0, editor.length)
    }

    function replaceSelection(fragment) {
        var start = editor.selectionStart
        var end = editor.selectionEnd
        if (start === end) {
            editor.insert(editor.cursorPosition, fragment)
            return
        }

        editor.remove(start, end)
        editor.insert(start, fragment)
    }

    function wrapSelection(prefix, suffix, placeholder) {
        var selected = escapeHtml(editor.selectedText || placeholder)
        var nextText = prefix + selected + suffix
        replaceSelection(nextText)
        editor.forceActiveFocus()
    }

    function insertHeading(level) {
        var selected = escapeHtml(editor.selectedText || "Titulo")
        var size = level === 1 ? 30 : 22
        var html = "<h" + level + " style=\"font-size:" + size + "px; font-weight:700; margin:0 0 10px 0; color:#f2f2f7;\">" + selected + "</h" + level + "><p><br/></p>"
        replaceSelection(html)
        statusText = level === 1 ? "Titulo inserido" : "Subtitulo inserido"
        editor.forceActiveFocus()
    }

    function applyColor(colorValue) {
        wrapSelection("<span style=\"color:" + colorValue + ";\">", "</span>", "texto colorido")
        statusText = "Cor aplicada"
    }

    function insertImage(path, fileUrl) {
        var name = nameFromPath(path)
        var url = fileUrl || ("file://" + path)
        replaceSelection("<p><img src=\"" + escapeHtml(url) + "\" alt=\"" + escapeHtml(name) + "\" width=\"520\" /></p><p><br/></p>")
        statusText = "Imagem inserida"
        editor.forceActiveFocus()
    }

    function newDocument() {
        currentPath = ""
        displayName = "Untitled.html"
        editor.text = "<h1 style=\"font-size:30px; font-weight:700; margin:0 0 10px 0; color:#f2f2f7;\">Sem Titulo</h1><p><br/></p>"
        lastSavedText = editor.text
        statusText = "Novo documento"
        editor.forceActiveFocus()
    }

    function openDocument(path) {
        loadingFile = true
        currentPath = path
        displayName = nameFromPath(path)
        fileView.path = path
        fileView.reload()
    }

    function saveDocument(path) {
        var targetPath = ensureNotePath(path)
        if (!targetPath) {
            openSystemFileDialog("save_file")
            return
        }

        currentPath = targetPath
        displayName = nameFromPath(targetPath)
        fileView.path = targetPath
        fileView.setText(serializedDocument())
    }

    Component.onCompleted: {
        Qt.application.name = "notepad"
        Qt.application.organization = "agony"
        Qt.application.domain = "local"
        newDocument()
    }

    onClosing: function(close) {
        if (dirty) {
            close.accepted = false
            showCloseMenu()
        } else {
            Qt.quit()
        }
    }

    FileView {
        id: fileView
        path: root.currentPath
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        printErrors: true

        onLoaded: {
            if (!root.loadingFile)
                return
            var loadedText = text()
            root.loadingFile = false
            editor.text = loadedText
            root.lastSavedText = editor.text
            root.statusText = "Aberto: " + root.displayName
            editor.forceActiveFocus()
        }

        onLoadFailed: function(error) {
            root.loadingFile = false
            root.statusText = "Nao foi possivel abrir o arquivo"
        }

        onSaved: {
            root.lastSavedText = editor.text
            root.statusText = "Salvo: " + root.displayName
            if (root.quitAfterSave)
                Qt.quit()
        }

        onSaveFailed: function(error) {
            root.statusText = "Nao foi possivel salvar o arquivo"
        }
    }

    FileView {
        id: portalDialogResult
        path: root.pendingDialogResultPath
        blockLoading: true
        printErrors: false
    }

    Process {
        id: portalDialogProcess
        command: ["/usr/bin/qs", "-p", "/home/agony/.local/share/Astrea/Apps/Explorer/PortalDialog.qml"]
        running: false

        stdout: SplitParser {
            onRead: function(data) {
                root.pendingDialogStdout += data
            }
        }

        onExited: function(exitCode, exitStatus) {
            var payload = null
            if (root.pendingDialogResultPath) {
                portalDialogResult.path = root.pendingDialogResultPath
                payload = root.parsePortalPayload(portalDialogResult.text())
            }
            if (!payload)
                payload = root.parsePortalPayload(root.pendingDialogStdout)
            root.handlePortalPayload(payload)
        }
    }

    Shortcut { sequences: ["Ctrl+N"]; onActivated: root.newDocument() }
    Shortcut { sequences: ["Ctrl+O"]; onActivated: root.openSystemFileDialog("open_file") }
    Shortcut { sequences: ["Ctrl+S"]; onActivated: root.saveDocument(root.currentPath) }
    Shortcut { sequences: ["Ctrl+Shift+S"]; onActivated: root.openSystemFileDialog("save_file") }
    Shortcut { sequences: ["Ctrl+Q"]; onActivated: root.close() }

    background: Rectangle {
        color: Theme.bg
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            height: 46
            color: Theme.bg
            border.color: Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 6

                ToolbarButton {
                    text: "+"
                    tooltip: "Novo"
                    onClicked: root.newDocument()
                }

                ToolbarButton {
                    text: "Open"
                    width: 54
                    tooltip: "Abrir nota"
                    onClicked: root.openSystemFileDialog("open_file")
                }

                ToolbarButton {
                    text: "Save"
                    width: 54
                    enabled: root.dirty || root.currentPath === ""
                    tooltip: "Salvar"
                    onClicked: root.saveDocument(root.currentPath)
                }

                ToolbarButton {
                    text: "Save As"
                    width: 72
                    tooltip: "Salvar como"
                    onClicked: root.openSystemFileDialog("save_file")
                }

                Rectangle {
                    width: 1
                    height: 26
                    color: Theme.border
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                }

                ToolbarButton {
                    text: "H1"
                    width: 38
                    tooltip: "Inserir titulo"
                    onClicked: root.insertHeading(1)
                }

                ToolbarButton {
                    text: "H2"
                    width: 38
                    tooltip: "Inserir subtitulo"
                    onClicked: root.insertHeading(2)
                }

                ToolbarButton {
                    text: "B"
                    tooltip: "Negrito"
                    font.weight: Font.Bold
                    onClicked: root.wrapSelection("**", "**", "negrito")
                }

                ToolbarButton {
                    text: "I"
                    tooltip: "Italico"
                    font.italic: true
                    onClicked: root.wrapSelection("*", "*", "italico")
                }

                ToolbarButton {
                    text: "U"
                    tooltip: "Sublinhado"
                    font.underline: true
                    onClicked: root.wrapSelection("<u>", "</u>", "sublinhado")
                }

                ToolbarButton {
                    text: "Cor"
                    width: 42
                    tooltip: "Cor do texto"
                    onClicked: {
                        var mapped = mapToItem(root.contentItem, 0, height + 6)
                        colorMenu.menuX = mapped.x
                        colorMenu.menuY = mapped.y
                        colorMenu.menuVisible = !colorMenu.menuVisible
                    }
                }

                ToolbarButton {
                    text: "Imagem"
                    width: 68
                    tooltip: "Inserir imagem"
                    onClicked: root.openSystemFileDialog("insert_image")
                }

                Rectangle {
                    width: 1
                    height: 26
                    color: Theme.border
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 10
                    color: Theme.toolbar
                    border.color: Theme.border
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Label {
                            text: root.displayName
                            color: Theme.text
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        Label {
                            Layout.fillWidth: true
                    text: root.currentPath || "Nova nota"
                            elide: Text.ElideMiddle
                            color: Theme.textTer
                            font.pixelSize: 12
                        }
                    }
                }

                Rectangle {
                    width: dirtyBadgeText.implicitWidth + 18
                    height: 26
                    radius: 8
                    color: root.dirty ? Theme.accentLight : Theme.toolbar
                    border.color: root.dirty ? Theme.selectedBdr : Theme.border
                    border.width: 1

                    Label {
                        id: dirtyBadgeText
                        anchors.centerIn: parent
                        text: root.dirty ? "Editado" : "Salvo"
                        color: root.dirty ? Theme.text : Theme.textSec
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.bg

            ScrollView {
                anchors.fill: parent
                anchors.margins: 14
                clip: true

                TextArea {
                    id: editor
                    textFormat: TextEdit.RichText
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    persistentSelection: true
                    tabStopDistance: fontMetrics.advanceWidth("    ")
                    padding: 18
                    color: Theme.text
                    selectedTextColor: Theme.text
                    selectionColor: Theme.selected
                    placeholderText: "Comece a escrever..."
                    placeholderTextColor: Theme.textTer
                    font.pixelSize: 15
                    background: Rectangle {
                        color: Theme.panel
                        border.color: editor.activeFocus ? Theme.selectedBdr : Theme.border
                        border.width: 1
                    }

                    Keys.onPressed: function(event) {
                        root.closeEditorMenu()
                        if (event.key === Qt.Key_Tab) {
                            insert(cursorPosition, "    ")
                            event.accepted = true
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: function(eventPoint, button) {
                            root.showEditorMenu(eventPoint.position.x, eventPoint.position.y)
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: root.closeEditorMenu()
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 28
            color: Theme.statusBar
            border.color: Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 14

                Label {
                    text: root.statusText
                    color: Theme.textSec
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Label {
                    text: root.wordCount + " palavras"
                    color: Theme.textSec
                    font.pixelSize: 12
                }

                Label {
                    text: editor.length + " caracteres"
                    color: Theme.textSec
                    font.pixelSize: 12
                }
            }
        }
    }

    FontMetrics {
        id: fontMetrics
        font: editor.font
    }

    Common.ContextMenuPopup {
        id: colorMenu
        z: 1001
        menuWidth: 170

        Repeater {
            model: root.textColors

            Common.ContextMenuAction {
                label: modelData.name
                onTriggered: {
                    root.applyColor(modelData.value)
                    colorMenu.menuVisible = false
                }
            }
        }
    }

    Common.ContextMenuPopup {
        id: closeConfirmMenu
        z: 1002
        menuWidth: 250

        Item {
            width: parent ? parent.width : 242
            height: 64

            Column {
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 5

                Text {
                    width: parent.width
                    text: "Documento com alteracoes"
                    color: Theme.text
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: "Salvar antes de fechar?"
                    color: Theme.textSec
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }

        Common.ContextMenuDivider {}

        Common.ContextMenuAction {
            label: "Salvar"
            actionEnabled: true
            onTriggered: {
                closeConfirmMenu.menuVisible = false
                root.quitAfterSave = true
                root.saveDocument(root.currentPath)
            }
        }

        Common.ContextMenuAction {
            label: "Descartar"
            destructive: true
            actionEnabled: true
            onTriggered: Qt.quit()
        }

        Common.ContextMenuAction {
            label: "Cancelar"
            actionEnabled: true
            onTriggered: {
                root.quitAfterSave = false
                closeConfirmMenu.menuVisible = false
            }
        }
    }

    Common.ContextMenuPopup {
        id: editorContextMenu
        z: 1000
        menuWidth: 190

        Common.ContextMenuAction {
            label: "Desfazer"
            actionEnabled: editor.canUndo
            onTriggered: {
                editor.undo()
                root.closeEditorMenu()
            }
        }

        Common.ContextMenuAction {
            label: "Refazer"
            actionEnabled: editor.canRedo
            onTriggered: {
                editor.redo()
                root.closeEditorMenu()
            }
        }

        Common.ContextMenuDivider {}

        Common.ContextMenuAction {
            label: "Recortar"
            actionEnabled: editor.selectedText.length > 0
            onTriggered: {
                editor.cut()
                root.closeEditorMenu()
            }
        }

        Common.ContextMenuAction {
            label: "Copiar"
            actionEnabled: editor.selectedText.length > 0
            onTriggered: {
                editor.copy()
                root.closeEditorMenu()
            }
        }

        Common.ContextMenuAction {
            label: "Colar"
            actionEnabled: true
            onTriggered: {
                editor.paste()
                root.closeEditorMenu()
            }
        }

        Common.ContextMenuDivider {}

        Common.ContextMenuAction {
            label: "Inserir Titulo"
            actionEnabled: true
            onTriggered: {
                root.insertHeading(1)
                root.closeEditorMenu()
            }
        }

        Common.ContextMenuAction {
            label: "Negrito"
            actionEnabled: true
            onTriggered: {
                root.wrapSelection("**", "**", "negrito")
                root.closeEditorMenu()
            }
        }

        Common.ContextMenuAction {
            label: "Italico"
            actionEnabled: true
            onTriggered: {
                root.wrapSelection("*", "*", "italico")
                root.closeEditorMenu()
            }
        }

        Common.ContextMenuAction {
            label: "Sublinhado"
            actionEnabled: true
            onTriggered: {
                root.wrapSelection("<u>", "</u>", "sublinhado")
                root.closeEditorMenu()
            }
        }

        Common.ContextMenuAction {
            label: "Texto Azul"
            actionEnabled: true
            onTriggered: {
                root.applyColor("#0a84ff")
                root.closeEditorMenu()
            }
        }

        Common.ContextMenuAction {
            label: "Inserir Imagem"
            actionEnabled: true
            onTriggered: {
                root.openSystemFileDialog("insert_image")
                root.closeEditorMenu()
            }
        }

        Common.ContextMenuDivider {}

        Common.ContextMenuAction {
            label: "Selecionar Tudo"
            actionEnabled: editor.length > 0
            onTriggered: {
                editor.selectAll()
                root.closeEditorMenu()
            }
        }

        Common.ContextMenuAction {
            label: "Limpar Selecao"
            actionEnabled: editor.selectedText.length > 0
            onTriggered: {
                editor.deselect()
                root.closeEditorMenu()
            }
        }
    }

    component ToolbarButton: ToolButton {
        property string tooltip: ""

        width: 32
        height: 32
        font.pixelSize: 13

        contentItem: Text {
            text: parent.text
            font: parent.font
            color: !parent.enabled ? Theme.textTer
                 : parent.hovered ? Theme.text
                                  : Theme.textSec
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: 8
            color: parent.hovered ? Qt.rgba(1, 1, 1, 0.09) : "transparent"
            border.color: "transparent"
            border.width: 1

            Behavior on color {
                ColorAnimation { duration: 80 }
            }
        }

        ToolTip.text: tooltip
        ToolTip.visible: tooltip !== "" && hovered
        ToolTip.delay: 500
    }
}
