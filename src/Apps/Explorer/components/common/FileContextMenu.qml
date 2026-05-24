import QtQuick 2.15
import QtQuick.Controls 2.15
import Quickshell.Io
import "../.."
import "." as Common
import "../../AstreaFiles" as AstreaFiles
import "../../AstreaI18n" as AstreaI18n

Item {
    id: menuRoot
    anchors.fill: parent
    visible: menuFrame.menuOpen || creatingFolder || renamingItem
    z: 999

    property string itemPath: ""
    property string itemUrl: ""
    property bool itemIsDir: false
    property var clipboardProxy
    property string menuOwner: "file-context"
    property bool creatingFolder: false
    property bool renamingItem: false
    property bool compressionSubmenuOpen: false
    property bool rarAvailable: false
    property real compressionSubmenuX: 0
    property real compressionSubmenuY: 0
    property string pendingFolderName: ""
    property string pendingRenameName: ""
    readonly property bool isBackgroundTarget: itemPath === AppState.currentPath && itemIsDir
    readonly property bool isArchiveTarget: !itemIsDir && /\.(zip|tar|tgz|tar\.gz|tar\.bz2|tbz2|tar\.xz|txz|7z|rar)$/i.test(itemPath)
    readonly property bool isAppImageTarget: !itemIsDir && AppState.isAppImageFileName(itemPath)
    readonly property bool isWallpaperImageTarget: !itemIsDir && !isBackgroundTarget && !AppState.inTrashView && AppState.isWallpaperImageFileName(itemPath)
    readonly property bool canCompressTarget: itemIsDir && !isBackgroundTarget && !AppState.inTrashView
    readonly property bool canToggleSidebarFavorite: itemIsDir && !isBackgroundTarget && !AppState.inTrashView && AppState.canPinSidebarFavorite(itemPath)
    readonly property var compressionFormats: [
        { "label": "ZIP", "format": "zip" },
        { "label": "RAR", "format": "rar" },
        { "label": "TAR", "format": "tar" },
        { "label": "TAR.GZ", "format": "tar.gz" },
        { "label": "TAR.XZ", "format": "tar.xz" }
    ]

    function dismissTransientUi() {
        menuFrame.closeMenu()
        compressionSubmenuOpen = false
        creatingFolder = false
        renamingItem = false
    }

    function openAt(x, y, path, isDir, url) {
        AppState.announceContextMenuOpening(menuOwner)
        itemPath = path
        itemIsDir = isDir
        itemUrl = url
        compressionSubmenuOpen = false
        menuFrame.openAt(x, y)
    }

    function closeMenu() {
        compressionSubmenuOpen = false
        menuFrame.closeMenu()
    }

    Shortcut {
        sequence: "Esc"
        enabled: menuRoot.visible
        onActivated: menuRoot.dismissTransientUi()
    }

    Connections {
        target: AppState
        function onContextMenuOpening(owner) {
            if (owner !== menuRoot.menuOwner)
                menuRoot.closeMenu()
        }
    }

    Component.onCompleted: rarProbe.running = true

    function runOpen() {
        closeMenu()
        AppState.openItem(itemPath, itemIsDir, itemUrl)
    }

    function runOpenWith() {
        if (isBackgroundTarget)
            return
        var point = menuRoot.mapToItem(openWithMenu, menuFrame.menuX + menuFrame.menuWidth - 8, menuFrame.menuY + 4)
        closeMenu()
        openWithMenu.openAt(point.x, point.y, itemPath)
    }

    function runCopyPath() {
        if (clipboardProxy && itemPath !== "")
            clipboardProxy.copyPath(itemPath)
        closeMenu()
    }

    function runToggleSidebarFavorite() {
        if (!canToggleSidebarFavorite)
            return
        var name = itemPath.split("/").filter(Boolean).pop() || itemPath
        if (AppState.isSidebarFavorite(itemPath))
            AppState.removeSidebarFavorite(itemPath)
        else
            AppState.pinSidebarFavorite(itemPath, name, AppState.fileIconName(name, true, false))
        closeMenu()
    }

    function runCreateFolder() {
        closeMenu()
        pendingFolderName = "Nova pasta"
        creatingFolder = true
        Qt.callLater(function() { nameField.forceActiveFocus(); nameField.selectAll() })
    }

    function runRename() {
        if (isBackgroundTarget) return
        closeMenu()
        pendingRenameName = itemPath.split("/").pop()
        renamingItem = true
        Qt.callLater(function() { renameField.forceActiveFocus(); renameField.selectAll() })
    }

    function extractionFolderName() {
        var name = itemPath.split("/").pop()
        return name
            .replace(/\.tar\.gz$/i, "")
            .replace(/\.tgz$/i, "")
            .replace(/\.tar\.bz2$/i, "")
            .replace(/\.tbz2$/i, "")
            .replace(/\.tar\.xz$/i, "")
            .replace(/\.txz$/i, "")
            .replace(/\.(zip|tar|7z|rar)$/i, "")
    }

    function runExtract() {
        if (!isArchiveTarget)
            return
        closeMenu()
        AppState.startArchiveExtraction(itemPath, extractionFolderName())
    }

    function openCompressionSubmenu(anchorItem) {
        if (!canCompressTarget)
            return
        compressionCloseTimer.stop()
        var submenuWidth = compressionSubmenu.width
        var submenuHeight = compressionFormats.length * 32 + 8
        var rightPoint = anchorItem.mapToItem(menuRoot, anchorItem.width - 4, 0)
        var leftPoint = anchorItem.mapToItem(menuRoot, -submenuWidth + 4, 0)
        var prefersRight = rightPoint.x + submenuWidth <= menuRoot.width - 10
        compressionSubmenuX = Math.max(10, Math.min(prefersRight ? rightPoint.x : leftPoint.x, menuRoot.width - submenuWidth - 10))
        compressionSubmenuY = Math.max(10, Math.min(rightPoint.y - 4, menuRoot.height - submenuHeight - 10))
        compressionSubmenuOpen = true
    }

    function scheduleCompressionSubmenuClose() {
        compressionCloseTimer.restart()
    }

    function runCompress(format) {
        if (!canCompressTarget)
            return
        closeMenu()
        AppState.startFolderCompression(itemPath, format)
    }

    function runInstallAppImage() {
        if (!isAppImageTarget || AppState.appImageInstallRunning)
            return
        closeMenu()
        AppState.installAppImage(itemPath)
    }

    function runSetAsWallpaper() {
        if (!isWallpaperImageTarget || AppState.wallpaperApplyRunning)
            return
        closeMenu()
        AppState.setAsWallpaper(itemPath)
    }

    function runShowProperties() {
        closeMenu()
        var selected = AppState.selectedFiles
        var inSelection = AppState.isSelected(itemPath.split('/').pop())

        if (inSelection && selected.length > 1) {
            propertiesWin.isMulti = true
            propertiesWin.targetPaths = selected.map(function(n) { return AppState.joinPath(AppState.currentPath, n) })
            propertiesWin.targetPath = ""
            propertiesWin.targetIsDir = false
        } else {
            propertiesWin.isMulti = false
            propertiesWin.targetPath = itemPath
            propertiesWin.targetIsDir = itemIsDir
            propertiesWin.targetPaths = []
        }

        propertiesWin.show()
        propertiesWin.raise()
        propertiesWin.requestActivate()
    }

    function confirmCreateFolder() {
        var trimmed = pendingFolderName.trim()
        if (trimmed === "") return
        pendingFolderName = trimmed
        createFolderProcess.running = false
        createFolderProcess.running = true
        creatingFolder = false
    }

    function confirmRename() {
        var trimmed = pendingRenameName.trim()
        var currentName = itemPath.split("/").pop()
        if (trimmed === "" || trimmed === currentName) return
        renameProcess.running = false
        renameProcess.running = true
        renamingItem = false
    }

    function runDelete() {
        if (!AppState.isSelected(itemPath.split('/').pop()))
            AppState.handleSelection(itemPath.split('/').pop(), -1, false, false)
        AppState.deleteSelected()
        closeMenu()
    }

    function runRestore() {
        if (!AppState.inTrashView || menuRoot.isBackgroundTarget)
            return
        if (!AppState.isSelected(itemPath.split('/').pop()))
            AppState.handleSelection(itemPath.split('/').pop(), -1, false, false)
        AppState.restoreSelected()
        closeMenu()
    }

    AstreaFiles.FileContextMenu {
        id: menuFrame
        anchors.fill: parent

        Common.ContextMenuAction {
            label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.abrir"]) || "Open")
            actionEnabled: true
            visible: !menuRoot.isBackgroundTarget
            onTriggered: menuRoot.runOpen()
        }
        Common.ContextMenuAction {
            label: "Abrir com"
            actionEnabled: true
            visible: !menuRoot.isBackgroundTarget
            onTriggered: menuRoot.runOpenWith()
        }
        Common.ContextMenuAction {
            label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.nova_pasta"]) || "New Folder")
            actionEnabled: true
            onTriggered: menuRoot.runCreateFolder()
        }
        Common.ContextMenuDivider {}
        Common.ContextMenuAction {
            label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.copiar_caminho"]) || "Copy Path")
            actionEnabled: true
            onTriggered: menuRoot.runCopyPath()
        }
        Common.ContextMenuAction {
            label: AppState.isSidebarFavorite(menuRoot.itemPath) ? "Remover dos Favoritos" : "Fixar na sidebar"
            actionEnabled: true
            visible: menuRoot.canToggleSidebarFavorite
            destructive: AppState.isSidebarFavorite(menuRoot.itemPath)
            onTriggered: menuRoot.runToggleSidebarFavorite()
        }
        Common.ContextMenuAction {
            label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.renomear"]) || "Rename")
            actionEnabled: true
            visible: !menuRoot.isBackgroundTarget
            onTriggered: menuRoot.runRename()
        }
        Common.ContextMenuAction {
            id: compressAction
            label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.compactar"]) || "Compress")
            actionEnabled: true
            hasSubmenu: true
            visible: menuRoot.canCompressTarget
            onHoveredChanged: {
                if (hovered)
                    menuRoot.openCompressionSubmenu(compressAction)
                else
                    menuRoot.scheduleCompressionSubmenuClose()
            }
            onTriggered: menuRoot.openCompressionSubmenu(compressAction)
        }
        Common.ContextMenuAction {
            label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.extrair"]) || "Extract")
            actionEnabled: true
            visible: menuRoot.isArchiveTarget
            onTriggered: menuRoot.runExtract()
        }
        Common.ContextMenuAction {
            label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.install"]) || "Install")
            actionEnabled: !AppState.appImageInstallRunning
            visible: menuRoot.isAppImageTarget
            onTriggered: menuRoot.runInstallAppImage()
        }
        Common.ContextMenuAction {
            label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.definir_como_wallpaper"]) || "Definir como wallpaper")
            actionEnabled: !AppState.wallpaperApplyRunning
            visible: menuRoot.isWallpaperImageTarget
            onTriggered: menuRoot.runSetAsWallpaper()
        }
        Common.ContextMenuAction {
            label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.restaurar"]) || "Restore")
            actionEnabled: true
            visible: AppState.inTrashView && !menuRoot.isBackgroundTarget
            onTriggered: menuRoot.runRestore()
        }
        Common.ContextMenuAction {
            label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.propriedades"]) || "Properties")
            actionEnabled: true
            onTriggered: menuRoot.runShowProperties()
        }
        Common.ContextMenuDivider { visible: !menuRoot.isBackgroundTarget }
        Common.ContextMenuAction {
            label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.mover_para_lixeira"]) || "Move to Trash")
            actionEnabled: true
            visible: !menuRoot.isBackgroundTarget && !AppState.inTrashView
            destructive: true
            onTriggered: menuRoot.runDelete()
        }
    }

    Timer {
        id: compressionCloseTimer
        interval: 180
        repeat: false
        onTriggered: {
            if (!compressionSubmenuHover.hovered && !compressAction.hovered)
                menuRoot.compressionSubmenuOpen = false
        }
    }

    Rectangle {
        id: compressionSubmenu
        visible: menuFrame.menuOpen && menuRoot.compressionSubmenuOpen
        x: menuRoot.compressionSubmenuX
        y: menuRoot.compressionSubmenuY
        width: 144
        height: compressionColumn.implicitHeight + 8
        radius: 10
        color: "#1e1e20"
        border.width: 1
        border.color: "#3a3a3c"
        z: menuFrame.z + 1

        HoverHandler {
            id: compressionSubmenuHover
            onHoveredChanged: {
                if (hovered)
                    compressionCloseTimer.stop()
                else
                    menuRoot.scheduleCompressionSubmenuClose()
            }
        }

        Column {
            id: compressionColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 4
            }
            spacing: 0

            Repeater {
                model: menuRoot.compressionFormats

                Common.ContextMenuAction {
                    label: modelData.label
                    actionEnabled: modelData.format !== "rar" || menuRoot.rarAvailable
                    onTriggered: menuRoot.runCompress(modelData.format)
                }
            }
        }
    }

    Process {
        id: rarProbe
        command: ["python3", AppState.helperPath, "which", "rar"]
        running: false
        onExited: function(exitCode) {
            menuRoot.rarAvailable = exitCode === 0
        }
    }

    Common.OpenWithMenu {
        id: openWithMenu
        anchors.fill: parent
    }

    Window {
        id: propertiesWin
        title: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.propriedades"]) || "Properties")
        width: 440
        minimumWidth: 380
        minimumHeight: 300
        color: "#1c1c1e"
        flags: Qt.Window | Qt.Dialog

        property string targetPath: ""
        property bool targetIsDir: false
        property bool isMulti: false
        property var targetPaths: []
        property bool isLoading: false
        property string errorText: ""
        property string propType: ""
        property string propSize: ""
        property string propModified: ""
        property string propAccessed: ""
        property string propPerms: ""
        property string propContains: ""

        readonly property bool isImageFile: {
            if (isMulti) return false
            var ext = targetPath.split(".").pop().toLowerCase()
            return ["jpg","jpeg","png","gif","bmp","webp","svg"].indexOf(ext) !== -1
        }

        height: isImageFile ? 520 : 340

        function fmtDate(epochSeconds) {
            var v = Number(epochSeconds)
            if (!isFinite(v) || v <= 0) return "--"
            return Qt.formatDateTime(new Date(v * 1000), "dd/MM/yyyy  HH:mm")
        }

        onVisibilityChanged: {
            if (!visible) return
            isLoading = true
            errorText = ""
            propType = ""
            propSize = "Carregando..."
            propModified = "Carregando..."
            propAccessed = "Carregando..."
            propPerms = "Carregando..."
            propContains = targetIsDir ? "Carregando..." : ""
            propProcess.command = [
                "bash", "-lc",
                "if [ \"$1\" = \"--multi\" ]; then " +
                "  shift; total_size=0; count=$#; " +
                "  for f in \"$@\"; do " +
                "    [ -e \"$f\" ] || continue; " +
                "    s=$(du -sb -- \"$f\" 2>/dev/null | cut -f1); " +
                "    total_size=$((total_size + s)); " +
                "  done; " +
                "  printf 'OK|%s itens|%s|—|—|—|%s\\n' \"$count\" \"$total_size\" \"$count\"; " +
                "else " +
                "  target=\"$1\"; " +
                "  [ -e \"$target\" ] || { echo 'ERROR|Arquivo nao encontrado'; exit 1; }; " +
                "  meta=$(stat -Lc '%F|%s|%Y|%X|%A' -- \"$target\" 2>/dev/null) || { echo 'ERROR|Erro ao ler metadados'; exit 1; }; " +
                "  IFS='|' read -r kind bytes modified accessed perms <<EOF\n$meta\nEOF\n" +
                "  if [ -d \"$target\" ]; then " +
                "    size=$(du -sb -- \"$target\" 2>/dev/null | cut -f1); " +
                "    count=$(find \"$target\" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l); " +
                "    printf 'OK|%s|%s|%s|%s|%s|%s\\n' \"$kind\" \"${size:-0}\" \"$modified\" \"$accessed\" \"$perms\" \"$count\"; " +
                "  else " +
                "    printf 'OK|%s|%s|%s|%s|%s|\\n' \"$kind\" \"$bytes\" \"$modified\" \"$accessed\" \"$perms\"; " +
                "  fi; " +
                "fi",
                "_"
            ].concat(propertiesWin.isMulti ? ["--multi"].concat(propertiesWin.targetPaths) : [propertiesWin.targetPath])
            propProcess.running = false
            propProcess.running = true
        }

        Rectangle {
            id: propTitleBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 44
            color: "#252527"

            Text {
                anchors {
                    left: parent.left; leftMargin: 16
                    right: parent.right; rightMargin: 16
                    verticalCenter: parent.verticalCenter
                }
                text: propertiesWin.isMulti
                    ? (propertiesWin.targetPaths.length + " itens selecionados")
                    : (propertiesWin.targetPath.split("/").pop() || propertiesWin.targetPath)
                color: "#f2f2f7"
                font { pixelSize: 13; weight: Font.DemiBold }
                elide: Text.ElideMiddle
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: "#2c2c2c"
            }
        }

        Rectangle {
            id: propPreview
            anchors { top: propTitleBar.bottom; left: parent.left; right: parent.right }
            height: propertiesWin.isImageFile ? 160 : 0
            visible: propertiesWin.isImageFile
            color: "#141416"

            Image {
                anchors { fill: parent; margins: 8 }
                source: propertiesWin.visible && propertiesWin.isImageFile
                    ? AppState.fileUrlForPath(propertiesWin.targetPath) : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
                cache: false
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: "#2c2c2c"
            }
        }

        Item {
            anchors {
                top: propPreview.bottom
                left: parent.left; right: parent.right
                bottom: propFooter.top
            }

            Column {
                id: infoCol
                anchors {
                    top: parent.top; topMargin: 16
                    left: parent.left; leftMargin: 16
                    right: parent.right; rightMargin: 16
                }
                spacing: 10

                Repeater {
                    id: infoRepeater
                    model: {
                        var rows = [
                            { lbl: propertiesWin.isMulti ? "Local" : "Caminho", val: propertiesWin.isMulti ? AppState.currentPath : propertiesWin.targetPath },
                            { lbl: "Tipo", val: propertiesWin.propType },
                            { lbl: "Tamanho", val: propertiesWin.propSize }
                        ]
                        if (propertiesWin.targetIsDir || (propertiesWin.isMulti && propertiesWin.targetPaths.length > 0))
                            rows.push({ lbl: propertiesWin.isMulti ? "Itens" : "Conteudo", val: propertiesWin.propContains })
                        if (!propertiesWin.isMulti) {
                            rows.push({ lbl: "Modificado", val: propertiesWin.propModified })
                            rows.push({ lbl: "Permissoes", val: propertiesWin.propPerms })
                        }
                        return rows
                    }

                    Row {
                        width: infoCol.width
                        spacing: 12

                        Text {
                            text: modelData.lbl
                            color: "#8e8e93"
                            font.pixelSize: 12
                            width: 90
                        }

                        Text {
                            text: modelData.val
                            color: "#f2f2f7"
                            font.pixelSize: 12
                            width: infoCol.width - 90 - 12
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }

                Text {
                    visible: propertiesWin.errorText !== ""
                    text: propertiesWin.errorText
                    color: "#ff6b6b"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    width: infoCol.width
                }
            }
        }

        Rectangle {
            id: propFooter
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 48
            color: "#252527"

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1; color: "#2c2c2c"
            }

            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                width: 80; height: 30; radius: 7
                color: propCloseMouse.containsMouse ? "#3a3a3c" : "#2c2c2e"
                border.color: "#48484a"; border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.text.fechar"]) || "Close")
                    color: "#f2f2f7"
                    font.pixelSize: 13
                }

                MouseArea {
                    id: propCloseMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: propertiesWin.close()
                }
            }
        }

        Process {
            id: propProcess
            command: []
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    var raw = text.trim()
                    if (!raw) {
                        propertiesWin.isLoading = false
                        propertiesWin.errorText = "Sem resposta do sistema."
                        return
                    }
                    var parts = raw.split("|")
                    if (parts[0] !== "OK") {
                        propertiesWin.isLoading = false
                        propertiesWin.errorText = parts.length > 1 ? parts.slice(1).join("|") : "Erro ao carregar."
                        return
                    }
                    propertiesWin.errorText = ""
                    propertiesWin.propType = parts[1] || (propertiesWin.targetIsDir ? "Pasta" : "Arquivo")
                    propertiesWin.propSize = AppState.formatSize(Number(parts[2] || 0))
                    propertiesWin.propModified = propertiesWin.fmtDate(parts[3])
                    propertiesWin.propAccessed = propertiesWin.fmtDate(parts[4])
                    propertiesWin.propPerms = parts[5] || "--"
                    if (propertiesWin.targetIsDir) {
                        var cnt = Number(parts[6] || 0)
                        propertiesWin.propContains = cnt + (cnt === 1 ? " item" : " itens")
                    }
                    propertiesWin.isLoading = false
                }
            }
            onExited: function(exitCode) {
                if (exitCode !== 0 && propertiesWin.isLoading) {
                    propertiesWin.isLoading = false
                    if (!propertiesWin.errorText)
                        propertiesWin.errorText = "Falha ao consultar propriedades."
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: creatingFolder
        color: Qt.rgba(0, 0, 0, 0.5)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: function(mouse) {
                mouse.accepted = true
                menuRoot.creatingFolder = false
            }
        }

        Rectangle {
            id: createDialog
            width: 320
            anchors.centerIn: parent
            height: createCol.implicitHeight + 24
            radius: 10
            color: "#1e1e20"
            border.color: "#3a3a3c"; border.width: 1

            Column {
                id: createCol
                anchors { fill: parent; margins: 16 }
                spacing: 12

                Text {
                    text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.nova_pasta"]) || "New Folder")
                    color: "#f2f2f7"
                    font { pixelSize: 14; weight: Font.DemiBold }
                }

                TextField {
                    id: nameField
                    width: parent.width
                    text: menuRoot.pendingFolderName
                    color: "#f2f2f7"
                    placeholderText: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.placeholderText.nome_da_pasta"]) || "Folder name")
                    placeholderTextColor: "#636366"
                    selectByMouse: true
                    font.pixelSize: 13
                    background: Rectangle {
                        radius: 7; color: "#2c2c2e"
                        border.color: nameField.activeFocus ? "#636366" : "#3a3a3c"; border.width: 1
                    }
                    onTextChanged: menuRoot.pendingFolderName = text
                    onAccepted: menuRoot.confirmCreateFolder()
                }

                Row {
                    spacing: 8
                    FlatButton { id: cancelCreate; label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.cancelar"]) || "Cancel"); onClicked: menuRoot.creatingFolder = false }
                    FlatButton { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.criar"]) || "Create"); primary: true; onClicked: menuRoot.confirmCreateFolder() }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: renamingItem
        color: Qt.rgba(0, 0, 0, 0.5)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: function(mouse) {
                mouse.accepted = true
                menuRoot.renamingItem = false
            }
        }

        Rectangle {
            width: 320
            anchors.centerIn: parent
            height: renameCol.implicitHeight + 24
            radius: 10
            color: "#1e1e20"
            border.color: "#3a3a3c"; border.width: 1

            Column {
                id: renameCol
                anchors { fill: parent; margins: 16 }
                spacing: 12

                Text {
                    text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.renomear"]) || "Rename")
                    color: "#f2f2f7"
                    font { pixelSize: 14; weight: Font.DemiBold }
                }

                TextField {
                    id: renameField
                    width: parent.width
                    text: menuRoot.pendingRenameName
                    color: "#f2f2f7"
                    placeholderText: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.placeholderText.novo_nome"]) || "New name")
                    placeholderTextColor: "#636366"
                    selectByMouse: true
                    font.pixelSize: 13
                    background: Rectangle {
                        radius: 7; color: "#2c2c2e"
                        border.color: renameField.activeFocus ? "#636366" : "#3a3a3c"; border.width: 1
                    }
                    onTextChanged: menuRoot.pendingRenameName = text
                    onAccepted: menuRoot.confirmRename()
                }

                Row {
                    spacing: 8
                    FlatButton { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.cancelar"]) || "Cancel"); onClicked: menuRoot.renamingItem = false }
                    FlatButton { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.renomear"]) || "Rename"); primary: true; onClicked: menuRoot.confirmRename() }
                }
            }
        }
    }

    Process {
        id: createFolderProcess
        command: ["python3", AppState.helperPath, "create-folder", AppState.currentPath, pendingFolderName]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) AppState.refreshCurrentFolder()
        }
    }

    Process {
        id: renameProcess
        command: ["python3", AppState.helperPath, "rename", itemPath, pendingRenameName]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) {
                AppState.refreshCurrentFolder()
                if (AppState.selectedFile === itemPath.split('/').pop())
                    AppState.selectedFile = pendingRenameName
            }
        }
    }

    component FlatButton: Rectangle {
        id: fbRoot
        property string label: ""
        property bool primary: false
        signal clicked()

        width: 88; height: 30; radius: 7
        color: fbMouse.containsMouse
            ? "#3a3a3c"
            : (primary ? "#2c2c2e" : "#232325")
        border.color: "#3a3a3c"; border.width: 1
        Behavior on color { ColorAnimation { duration: 60 } }

        Text {
            anchors.centerIn: parent
            text: fbRoot.label
            color: "#f2f2f7"
            font { pixelSize: 13; weight: fbRoot.primary ? Font.DemiBold : Font.Normal }
        }

        MouseArea {
            id: fbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: fbRoot.clicked()
        }
    }

}
