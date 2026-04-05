import QtQuick 2.15
import QtQuick.Controls 2.15
import Quickshell.Io
import "../.."

Item {
    id: menuRoot
    anchors.fill: parent
    visible: menuOpen || creatingFolder || propertiesOpen || renamingItem
    z: 999

    property string itemPath: ""
    property string itemUrl: ""
    property bool itemIsDir: false
    property var clipboardProxy
    property real menuX: 0
    property real menuY: 0
    property bool menuOpen: false
    property bool creatingFolder: false
    property bool propertiesOpen: false
    property bool renamingItem: false
    property string pendingFolderName: ""
    property string pendingRenameName: ""
    property bool propertiesLoading: false
    property string propertiesError: ""
    property string propertiesType: ""
    property string propertiesSizeText: ""
    property string propertiesModifiedText: ""
    property string propertiesAccessedText: ""
    property string propertiesPermissionsText: ""
    property string propertiesContainsText: ""
    readonly property bool isBackgroundTarget: itemPath === AppState.currentPath && itemIsDir

    function formatDateTime(epochSeconds) {
        var value = Number(epochSeconds)
        if (!isFinite(value) || value <= 0) return "Indisponível"
        var date = new Date(value * 1000)
        return Qt.formatDateTime(date, "dd/MM/yyyy  HH:mm")
    }

    function openAt(x, y, path, isDir, url) {
        itemPath = path
        itemIsDir = isDir
        itemUrl = url
        menuX = Math.max(10, Math.min(x, width - menuCard.width - 10))
        menuY = Math.max(10, Math.min(y, height - menuCard.height - 10))
        menuOpen = true
    }

    function closeMenu() { menuOpen = false }
    function closeProperties() { propertiesOpen = false; propertiesLoading = false }

    function runOpen() {
        closeMenu()
        AppState.openItem(itemPath, itemIsDir, itemUrl)
    }

    function runCopyPath() {
        if (clipboardProxy && itemPath !== "")
            clipboardProxy.copyPath(itemPath)
        closeMenu()
    }

    function runCreateFolder() {
        closeMenu()
        pendingFolderName = "Nova pasta"
        creatingFolder = true
        nameField.forceActiveFocus()
        nameField.selectAll()
    }

    function runRename() {
        if (isBackgroundTarget) return
        closeMenu()
        pendingRenameName = itemPath.split("/").pop()
        renamingItem = true
        renameField.forceActiveFocus()
        renameField.selectAll()
    }

    function runShowProperties() {
        closeMenu()
        propertiesOpen = true
        propertiesLoading = true
        propertiesError = ""
        propertiesType = itemIsDir ? "Pasta" : "Arquivo"
        propertiesSizeText = "Carregando…"
        propertiesModifiedText = "Carregando…"
        propertiesAccessedText = "Carregando…"
        propertiesPermissionsText = "Carregando…"
        propertiesContainsText = itemIsDir ? "Carregando…" : ""
        propertiesProcess.running = false
        propertiesProcess.running = true
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

    // ── Backdrop (closes menu) ────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        enabled: menuRoot.menuOpen
        onClicked: menuRoot.closeMenu()
    }

    // ═══════════════════════════════════════════════════════════════
    // CONTEXT MENU CARD
    // ═══════════════════════════════════════════════════════════════
    Rectangle {
        id: menuCard
        visible: menuRoot.menuOpen
        x: menuRoot.menuX
        y: menuRoot.menuY
        width: 210
        height: menuColumn.implicitHeight + 10
        radius: 14

        // Frosted-glass dark base
        color: Qt.rgba(0.10, 0.10, 0.13, 0.97)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)

        // Inner gradient highlight
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0;  color: Qt.rgba(1, 1, 1, 0.07) }
                GradientStop { position: 0.18; color: "transparent" }
            }
        }

        // Appear animation
        scale: menuRoot.menuOpen ? 1.0 : 0.92
        opacity: menuRoot.menuOpen ? 1.0 : 0.0
        transformOrigin: Item.TopLeft
        Behavior on scale   { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Column {
            id: menuColumn
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: 5
            spacing: 1

            // ── Primary actions ──────────────────────────────
            MenuAction {
                label: "Abrir"
                icon: "↗"
                shortcut: "↵"
                visible: !menuRoot.isBackgroundTarget
                onTriggered: menuRoot.runOpen()
            }

            MenuAction {
                label: "Nova Pasta"
                icon: "+"
                onTriggered: menuRoot.runCreateFolder()
            }

            // ── Separator ────────────────────────────────────
            MenuSeparator {}

            MenuAction {
                label: "Copiar Caminho"
                icon: "⎘"
                onTriggered: menuRoot.runCopyPath()
            }

            MenuAction {
                label: "Renomear"
                icon: "✎"
                visible: !menuRoot.isBackgroundTarget
                onTriggered: menuRoot.runRename()
            }

            MenuAction {
                label: "Propriedades"
                icon: "ℹ"
                onTriggered: menuRoot.runShowProperties()
            }

            // ── Separator ────────────────────────────────────
            MenuSeparator { visible: !menuRoot.isBackgroundTarget && !menuRoot.itemIsDir }

            MenuAction {
                label: "Mover para Lixeira"
                icon: "⌫"
                visible: !menuRoot.isBackgroundTarget && !menuRoot.itemIsDir
                destructive: true
                onTriggered: menuRoot.runDelete()
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // PROPERTIES POPUP
    // ═══════════════════════════════════════════════════════════════
    Popup {
        id: propertiesPopup
        anchors.centerIn: parent
        width: 400
        modal: true
        focus: true
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        visible: menuRoot.propertiesOpen

        onClosed: menuRoot.propertiesOpen = false

        background: Rectangle {
            radius: 16
            color: Qt.rgba(0.10, 0.10, 0.13, 0.99)
            border.color: Qt.rgba(1, 1, 1, 0.10)
            border.width: 1

            // Gradient shimmer at top
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: parent.height * 0.35
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.05) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        contentItem: Column {
            spacing: 0

            // ── Header with icon ─────────────────────────────
            Rectangle {
                width: parent.width
                height: 72
                color: "transparent"
                radius: 16

                Row {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 14

                    // Big file/folder icon
                    Rectangle {
                        width: 44; height: 44; radius: 12
                        color: menuRoot.itemIsDir
                            ? Qt.rgba(0.25, 0.55, 1.0, 0.2)
                            : Qt.rgba(1, 1, 1, 0.08)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: menuRoot.itemIsDir ? "📁" : "📄"
                            font.pixelSize: 22
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            text: menuRoot.itemPath.split("/").pop() || menuRoot.itemPath
                            color: Theme.text
                            font { pixelSize: 14; weight: Font.DemiBold }
                            elide: Text.ElideMiddle
                            width: propertiesPopup.width - 20 - 20 - 14 - 44 - 10
                        }

                        Text {
                            text: menuRoot.propertiesLoading
                                ? "Carregando…"
                                : menuRoot.propertiesType || (menuRoot.itemIsDir ? "Pasta" : "Arquivo")
                            color: Theme.textSec
                            font.pixelSize: 12
                        }
                    }
                }

                // Close button
                Rectangle {
                    anchors { right: parent.right; top: parent.top; margins: 12 }
                    width: 26; height: 26; radius: 13
                    color: closePropHover.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)

                    Behavior on color { ColorAnimation { duration: 80 } }

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: Theme.textSec
                        font.pixelSize: 16
                    }

                    MouseArea {
                        id: closePropHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: menuRoot.closeProperties()
                    }
                }
            }

            // ── Divider ──────────────────────────────────────
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.07) }

            // ── Info grid ────────────────────────────────────
            Column {
                width: parent.width
                spacing: 0
                topPadding: 4
                bottomPadding: 4

                PropRow {
                    label: "Caminho"
                    value: menuRoot.itemPath
                }
                PropRow {
                    label: "Tamanho"
                    value: menuRoot.propertiesSizeText
                }
                PropRow {
                    visible: menuRoot.itemIsDir
                    label: "Conteúdo"
                    value: menuRoot.propertiesContainsText
                }
                PropRow {
                    label: "Modificado"
                    value: menuRoot.propertiesModifiedText
                }
                PropRow {
                    label: "Acessado"
                    value: menuRoot.propertiesAccessedText
                }
                PropRow {
                    label: "Permissões"
                    value: menuRoot.propertiesPermissionsText
                    monospace: true
                }
            }

            // ── Error ─────────────────────────────────────────
            Text {
                visible: menuRoot.propertiesError !== ""
                text: menuRoot.propertiesError
                color: "#ff8b8b"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                width: parent.width
                leftPadding: 20
                rightPadding: 20
                bottomPadding: 8
            }

            // ── Footer ────────────────────────────────────────
            Rectangle {
                width: parent.width; height: 1
                color: Qt.rgba(1, 1, 1, 0.07)
            }

            Item {
                width: parent.width
                height: 58

                // Fechar button
                Rectangle {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 20 }
                    width: 88; height: 34; radius: 9
                    color: closePropBtnMouse.containsMouse
                        ? Qt.rgba(0.25, 0.55, 1.0, 0.25)
                        : Qt.rgba(0.25, 0.55, 1.0, 0.15)
                    border.color: Qt.rgba(0.4, 0.7, 1.0, 0.25)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 80 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Fechar"
                        color: Qt.rgba(0.55, 0.8, 1.0, 1.0)
                        font { pixelSize: 13; weight: Font.Medium }
                    }

                    MouseArea {
                        id: closePropBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: menuRoot.closeProperties()
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // CREATE FOLDER POPUP
    // ═══════════════════════════════════════════════════════════════
    Popup {
        id: createFolderPopup
        anchors.centerIn: parent
        width: 360
        modal: true
        focus: true
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        visible: menuRoot.creatingFolder

        onClosed: menuRoot.creatingFolder = false

        background: Rectangle {
            radius: 16
            color: Qt.rgba(0.10, 0.10, 0.13, 0.99)
            border.color: Qt.rgba(1, 1, 1, 0.10)
            border.width: 1
        }

        contentItem: Column {
            spacing: 0

            // Header
            Item {
                width: parent.width; height: 60

                Text {
                    anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                    text: "Nova Pasta"
                    color: Theme.text
                    font { pixelSize: 16; weight: Font.DemiBold }
                }

                Rectangle {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 }
                    width: 26; height: 26; radius: 13
                    color: cancelFolderClose.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on color { ColorAnimation { duration: 80 } }

                    Text { anchors.centerIn: parent; text: "×"; color: Theme.textSec; font.pixelSize: 16 }
                    MouseArea {
                        id: cancelFolderClose
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: menuRoot.creatingFolder = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }

            // Field
            Item {
                width: parent.width; height: 72

                TextField {
                    id: nameField
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 20; rightMargin: 20 }
                    text: menuRoot.pendingFolderName
                    color: Theme.text
                    placeholderText: "Nome da pasta"
                    placeholderTextColor: Theme.textTer
                    selectByMouse: true
                    font.pixelSize: 14
                    background: Rectangle {
                        radius: 9
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: nameField.activeFocus ? Qt.rgba(0.25, 0.55, 1.0, 0.7) : Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                    }
                    onTextChanged: menuRoot.pendingFolderName = text
                    onAccepted: menuRoot.confirmCreateFolder()
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }

            // Actions
            Item {
                width: parent.width; height: 58

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 20 }
                    spacing: 10

                    Rectangle {
                        width: 88; height: 34; radius: 9
                        color: cancelFolderMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.06)
                        Behavior on color { ColorAnimation { duration: 80 } }

                        Text { anchors.centerIn: parent; text: "Cancelar"; color: Theme.textSec; font.pixelSize: 13 }
                        MouseArea {
                            id: cancelFolderMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: menuRoot.creatingFolder = false
                        }
                    }

                    Rectangle {
                        width: 88; height: 34; radius: 9
                        color: createMouse.containsMouse
                            ? Qt.rgba(0.25, 0.55, 1.0, 0.35)
                            : Qt.rgba(0.25, 0.55, 1.0, 0.22)
                        border.color: Qt.rgba(0.4, 0.7, 1.0, 0.3)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }

                        Text { anchors.centerIn: parent; text: "Criar"; color: Qt.rgba(0.55, 0.8, 1.0, 1.0); font { pixelSize: 13; weight: Font.Medium } }
                        MouseArea {
                            id: createMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: menuRoot.confirmCreateFolder()
                        }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // RENAME POPUP
    // ═══════════════════════════════════════════════════════════════
    Popup {
        id: renamePopup
        anchors.centerIn: parent
        width: 360
        modal: true
        focus: true
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        visible: menuRoot.renamingItem

        onClosed: menuRoot.renamingItem = false

        background: Rectangle {
            radius: 16
            color: Qt.rgba(0.10, 0.10, 0.13, 0.99)
            border.color: Qt.rgba(1, 1, 1, 0.10)
            border.width: 1
        }

        contentItem: Column {
            spacing: 0

            // Header
            Item {
                width: parent.width; height: 60

                Text {
                    anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                    text: "Renomear"
                    color: Theme.text
                    font { pixelSize: 16; weight: Font.DemiBold }
                }

                Rectangle {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 }
                    width: 26; height: 26; radius: 13
                    color: cancelRenameClose.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text { anchors.centerIn: parent; text: "×"; color: Theme.textSec; font.pixelSize: 16 }
                    MouseArea {
                        id: cancelRenameClose
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: menuRoot.renamingItem = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }

            // Field
            Item {
                width: parent.width; height: 72

                TextField {
                    id: renameField
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 20; rightMargin: 20 }
                    text: menuRoot.pendingRenameName
                    color: Theme.text
                    placeholderText: "Novo nome"
                    placeholderTextColor: Theme.textTer
                    selectByMouse: true
                    font.pixelSize: 14
                    background: Rectangle {
                        radius: 9
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: renameField.activeFocus ? Qt.rgba(0.25, 0.55, 1.0, 0.7) : Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                    }
                    onTextChanged: menuRoot.pendingRenameName = text
                    onAccepted: menuRoot.confirmRename()
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }

            // Actions
            Item {
                width: parent.width; height: 58

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 20 }
                    spacing: 10

                    Rectangle {
                        width: 88; height: 34; radius: 9
                        color: cancelRenameMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.06)
                        Behavior on color { ColorAnimation { duration: 80 } }

                        Text { anchors.centerIn: parent; text: "Cancelar"; color: Theme.textSec; font.pixelSize: 13 }
                        MouseArea {
                            id: cancelRenameMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: menuRoot.renamingItem = false
                        }
                    }

                    Rectangle {
                        width: 88; height: 34; radius: 9
                        color: applyRenameMouse.containsMouse
                            ? Qt.rgba(0.25, 0.55, 1.0, 0.35)
                            : Qt.rgba(0.25, 0.55, 1.0, 0.22)
                        border.color: Qt.rgba(0.4, 0.7, 1.0, 0.3)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }

                        Text { anchors.centerIn: parent; text: "Renomear"; color: Qt.rgba(0.55, 0.8, 1.0, 1.0); font { pixelSize: 13; weight: Font.Medium } }
                        MouseArea {
                            id: applyRenameMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: menuRoot.confirmRename()
                        }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // PROCESSES
    // ═══════════════════════════════════════════════════════════════
    Process {
        id: createFolderProcess
        command: [
            "bash", "-lc",
            "base=\"$1\"; name=\"$2\"; target=\"$base/$name\"; n=2; while [ -e \"$target\" ]; do target=\"$base/$name $n\"; n=$((n+1)); done; mkdir -- \"$target\"",
            "_",
            AppState.currentPath,
            pendingFolderName
        ]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) AppState.refreshCurrentFolder()
        }
    }

    Process {
        id: renameProcess
        command: [
            "bash", "-lc",
            "source=\"$1\"; new_name=\"$2\"; base=$(dirname -- \"$source\"); target=\"$base/$new_name\"; [ \"$source\" = \"$target\" ] && exit 0; [ -e \"$target\" ] && exit 1; mv -- \"$source\" \"$target\"",
            "_",
            itemPath,
            pendingRenameName
        ]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) {
                AppState.refreshCurrentFolder()
                if (AppState.selectedFile === itemPath.split('/').pop())
                    AppState.selectedFile = pendingRenameName
            }
        }
    }

    Process {
        id: propertiesProcess
        command: [
            "bash", "-lc",
            "target=\"$1\"; " +
            "[ -e \"$target\" ] || { echo 'ERROR|Arquivo não encontrado'; exit 1; }; " +
            "meta=$(stat -Lc '%F|%s|%Y|%X|%A' -- \"$target\" 2>/dev/null) || { echo 'ERROR|Não foi possível ler os metadados'; exit 1; }; " +
            "IFS='|' read -r kind bytes modified accessed perms <<EOF\n$meta\nEOF\n" +
            "if [ -d \"$target\" ]; then " +
            "  size=$(du -sb -- \"$target\" 2>/dev/null | cut -f1); " +
            "  count=$(find \"$target\" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l); " +
            "  printf 'OK|%s|%s|%s|%s|%s|%s\\n' \"$kind\" \"${size:-0}\" \"$modified\" \"$accessed\" \"$perms\" \"$count\"; " +
            "else " +
            "  printf 'OK|%s|%s|%s|%s|%s|\\n' \"$kind\" \"$bytes\" \"$modified\" \"$accessed\" \"$perms\"; " +
            "fi",
            "_",
            itemPath
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = text.trim()
                if (!raw) {
                    menuRoot.propertiesLoading = false
                    menuRoot.propertiesError = "Não foi possível carregar as propriedades."
                    return
                }

                var parts = raw.split("|")
                if (parts[0] !== "OK") {
                    menuRoot.propertiesLoading = false
                    menuRoot.propertiesError = parts.length > 1 ? parts.slice(1).join("|") : "Erro ao carregar propriedades."
                    return
                }

                menuRoot.propertiesError = ""
                menuRoot.propertiesType = parts[1] || (menuRoot.itemIsDir ? "Pasta" : "Arquivo")
                menuRoot.propertiesSizeText = AppState.formatSize(Number(parts[2] || 0))
                menuRoot.propertiesModifiedText = menuRoot.formatDateTime(parts[3])
                menuRoot.propertiesAccessedText = menuRoot.formatDateTime(parts[4])
                menuRoot.propertiesPermissionsText = parts[5] || "Indisponível"
                if (menuRoot.itemIsDir) {
                    var count = Number(parts[6] || 0)
                    menuRoot.propertiesContainsText = count + (count === 1 ? " item" : " itens")
                }
                menuRoot.propertiesLoading = false
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0 && menuRoot.propertiesLoading) {
                menuRoot.propertiesLoading = false
                if (!menuRoot.propertiesError)
                    menuRoot.propertiesError = "Falha ao consultar propriedades."
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SUB-COMPONENTS
    // ═══════════════════════════════════════════════════════════════

    component MenuAction: Item {
        id: actionRoot
        property string label: ""
        property string icon: ""
        property string shortcut: ""
        property bool destructive: false
        signal triggered()

        width: parent ? parent.width : 200
        height: visible ? 34 : 0

        Rectangle {
            anchors.fill: parent
            radius: 9
            color: {
                if (!actionHover.containsMouse) return "transparent"
                return actionRoot.destructive
                    ? Qt.rgba(0.9, 0.2, 0.2, 0.22)
                    : Qt.rgba(0.25, 0.55, 1.0, 0.22)
            }
            border.width: actionHover.containsMouse ? 1 : 0
            border.color: {
                if (!actionHover.containsMouse) return "transparent"
                return actionRoot.destructive
                    ? Qt.rgba(1, 0.5, 0.5, 0.18)
                    : Qt.rgba(0.6, 0.82, 1.0, 0.18)
            }
            Behavior on color { ColorAnimation { duration: 80 } }
        }

        Row {
            anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 10

            // Icon glyph
            Text {
                text: actionRoot.icon
                color: actionRoot.destructive
                    ? Qt.rgba(1, 0.5, 0.5, 0.9)
                    : actionHover.containsMouse ? Theme.text : Theme.textSec
                font.pixelSize: 13
                width: 16
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
            }

            // Label
            Text {
                text: actionRoot.label
                color: actionRoot.destructive ? "#ff8b8b" : Theme.text
                font { pixelSize: 13; weight: Font.Medium }
                anchors.verticalCenter: parent.verticalCenter
                Layout.fillWidth: true
            }

            Item { width: 1 }

            // Shortcut hint
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: actionRoot.shortcut
                color: Theme.textTer
                font.pixelSize: 11
            }
        }

        MouseArea {
            id: actionHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionRoot.triggered()
        }
    }

    component MenuSeparator: Rectangle {
        width: parent ? parent.width : 200
        height: visible ? 5 : 0
        color: "transparent"

        Rectangle {
            anchors { left: parent.left; right: parent.right; leftMargin: 6; rightMargin: 6; verticalCenter: parent.verticalCenter }
            height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }
    }

    component PropRow: Item {
        property string label: ""
        property string value: ""
        property bool monospace: false

        width: parent ? parent.width : 400
        height: visible ? Math.max(42, propVal.implicitHeight + 16) : 0

        Rectangle {
            anchors.fill: parent
            color: "transparent"

            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 20; rightMargin: 20 }
                height: 1
                color: Qt.rgba(1, 1, 1, 0.05)
            }
        }

        Row {
            anchors { left: parent.left; right: parent.right; leftMargin: 20; rightMargin: 20; verticalCenter: parent.verticalCenter }
            spacing: 12

            Text {
                id: propLbl
                text: parent.parent.parent.label
                color: Theme.textTer
                font { pixelSize: 11; weight: Font.Medium }
                width: 90
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: propVal
                text: parent.parent.parent.value
                color: Theme.text
                font {
                    pixelSize: 12
                    family: parent.parent.parent.monospace ? "monospace" : ""
                }
                width: parent.width - propLbl.width - parent.spacing
                wrapMode: Text.WrapAnywhere
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
