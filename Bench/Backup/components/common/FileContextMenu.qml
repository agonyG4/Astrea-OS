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
        if (!isFinite(value) || value <= 0)
            return "Indisponivel"

        var date = new Date(value * 1000)
        return Qt.formatDateTime(date, "dd/MM/yyyy HH:mm")
    }

    function openAt(x, y, path, isDir, url) {
        itemPath = path
        itemIsDir = isDir
        itemUrl = url
        menuX = Math.max(10, Math.min(x, width - menuCard.width - 10))
        menuY = Math.max(10, Math.min(y, height - menuCard.height - 10))
        menuOpen = true
    }

    function closeMenu() {
        menuOpen = false
    }

    function closeProperties() {
        propertiesOpen = false
        propertiesLoading = false
    }

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
        if (isBackgroundTarget)
            return

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
        propertiesSizeText = "Carregando..."
        propertiesModifiedText = "Carregando..."
        propertiesAccessedText = "Carregando..."
        propertiesPermissionsText = "Carregando..."
        propertiesContainsText = itemIsDir ? "Carregando..." : ""
        propertiesProcess.running = false
        propertiesProcess.running = true
    }

    function confirmCreateFolder() {
        var trimmed = pendingFolderName.trim()
        if (trimmed === "")
            return

        pendingFolderName = trimmed
        createFolderProcess.running = false
        createFolderProcess.running = true
        creatingFolder = false
    }

    function confirmRename() {
        var trimmed = pendingRenameName.trim()
        var currentName = itemPath.split("/").pop()
        if (trimmed === "" || trimmed === currentName)
            return

        renameProcess.running = false
        renameProcess.running = true
        renamingItem = false
    }

    function runDelete() {
        if (!AppState.isSelected(itemPath.split('/').pop())) {
            AppState.handleSelection(itemPath.split('/').pop(), -1, false, false)
        }
        AppState.deleteSelected()
        closeMenu()
    }

    MouseArea {
        anchors.fill: parent
        enabled: menuRoot.menuOpen
        onClicked: menuRoot.closeMenu()
    }

    Rectangle {
        id: menuCard
        visible: menuRoot.menuOpen
        x: menuRoot.menuX
        y: menuRoot.menuY
        width: 196
        height: menuColumn.implicitHeight + 12
        radius: 14
        color: Qt.rgba(0.12, 0.13, 0.16, 0.96)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.08) }
                GradientStop { position: 0.15; color: "transparent" }
                GradientStop { position: 1.0; color: "transparent" }
            }
            opacity: 0.7
        }

        Column {
            id: menuColumn
            anchors.fill: parent
            anchors.margins: 6
            spacing: 4

            MenuAction {
                label: "Abrir"
                shortcut: "Enter"
                visible: !menuRoot.isBackgroundTarget
                onTriggered: menuRoot.runOpen()
            }

            MenuAction {
                label: "Nova pasta"
                shortcut: ""
                onTriggered: menuRoot.runCreateFolder()
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            MenuAction {
                label: "Copiar localização"
                shortcut: "Cmd+C"
                onTriggered: menuRoot.runCopyPath()
            }

            MenuAction {
                label: "Renomear"
                shortcut: ""
                visible: !menuRoot.isBackgroundTarget
                onTriggered: menuRoot.runRename()
            }

            MenuAction {
                label: "Propriedades"
                shortcut: ""
                onTriggered: menuRoot.runShowProperties()
            }

            MenuAction {
                label: "Mover para lixeira"
                shortcut: ""
                visible: !menuRoot.isBackgroundTarget && !menuRoot.itemIsDir
                destructive: true
                onTriggered: menuRoot.runDelete()
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: propertiesOpen
        color: Qt.rgba(0, 0, 0, 0.28)
        z: 1000

        MouseArea {
            anchors.fill: parent
            onClicked: menuRoot.closeProperties()
        }

        Rectangle {
            width: 380
            height: propertiesColumn.implicitHeight + 24
            anchors.centerIn: parent
            radius: 14
            color: Qt.rgba(0.12, 0.13, 0.16, 0.98)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)

            Column {
                id: propertiesColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Text {
                    text: "Propriedades"
                    color: Theme.text
                    font { pixelSize: 14; weight: Font.DemiBold }
                }

                Text {
                    text: menuRoot.itemPath.split("/").pop() || menuRoot.itemPath
                    color: Theme.text
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideMiddle
                    width: parent.width
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 8

                    InfoLabel { label: "Caminho" }
                    InfoValue { value: menuRoot.itemPath }

                    InfoLabel { label: "Tipo" }
                    InfoValue { value: menuRoot.propertiesType || (menuRoot.itemIsDir ? "Pasta" : "Arquivo") }

                    InfoLabel { label: "Tamanho" }
                    InfoValue { value: menuRoot.propertiesSizeText }

                    InfoLabel { label: "Modificado" }
                    InfoValue { value: menuRoot.propertiesModifiedText }

                    InfoLabel { label: "Acessado" }
                    InfoValue { value: menuRoot.propertiesAccessedText }

                    InfoLabel { label: "Permissoes" }
                    InfoValue { value: menuRoot.propertiesPermissionsText }

                    InfoLabel {
                        visible: menuRoot.itemIsDir
                        label: "Conteudo"
                    }
                    InfoValue {
                        visible: menuRoot.itemIsDir
                        value: menuRoot.propertiesContainsText
                    }
                }

                Text {
                    visible: menuRoot.propertiesError !== ""
                    text: menuRoot.propertiesError
                    color: "#ff8b8b"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                Row {
                    spacing: 8

                    Rectangle {
                        width: 92
                        height: 34
                        radius: 8
                        color: closePropertiesMouse.containsMouse ? Theme.hover : Theme.toolbar

                        Text {
                            anchors.centerIn: parent
                            text: "Fechar"
                            color: Theme.text
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: closePropertiesMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: menuRoot.closeProperties()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: creatingFolder
        color: Qt.rgba(0, 0, 0, 0.28)
        z: 1000

        MouseArea {
            anchors.fill: parent
            onClicked: menuRoot.creatingFolder = false
        }

        Rectangle {
            width: 320
            height: createColumn.implicitHeight + 24
            anchors.centerIn: parent
            radius: 14
            color: Qt.rgba(0.12, 0.13, 0.16, 0.98)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)

            Column {
                id: createColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Text {
                    text: "Nova pasta"
                    color: Theme.text
                    font { pixelSize: 14; weight: Font.DemiBold }
                }

                TextField {
                    id: nameField
                    width: parent.width
                    text: menuRoot.pendingFolderName
                    color: Theme.text
                    placeholderText: "Digite o nome da pasta"
                    placeholderTextColor: Theme.textTer
                    selectByMouse: true
                    background: Rectangle {
                        radius: 8
                        color: Theme.bg
                        border.color: nameField.activeFocus ? Theme.accent : Theme.border
                        border.width: 1
                    }
                    onTextChanged: menuRoot.pendingFolderName = text
                    onAccepted: menuRoot.confirmCreateFolder()
                }

                Row {
                    spacing: 8

                    Rectangle {
                        width: 92
                        height: 34
                        radius: 8
                        color: cancelMouse.containsMouse ? Theme.hover : Theme.toolbar

                        Text {
                            anchors.centerIn: parent
                            text: "Cancelar"
                            color: Theme.text
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: cancelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: menuRoot.creatingFolder = false
                        }
                    }

                    Rectangle {
                        width: 92
                        height: 34
                        radius: 8
                        color: createMouse.containsMouse ? Theme.accentSoft : Theme.accentLight

                        Text {
                            anchors.centerIn: parent
                            text: "Criar"
                            color: Theme.text
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: createMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: menuRoot.confirmCreateFolder()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: renamingItem
        color: Qt.rgba(0, 0, 0, 0.28)
        z: 1000

        MouseArea {
            anchors.fill: parent
            onClicked: menuRoot.renamingItem = false
        }

        Rectangle {
            width: 320
            height: renameColumn.implicitHeight + 24
            anchors.centerIn: parent
            radius: 14
            color: Qt.rgba(0.12, 0.13, 0.16, 0.98)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)

            Column {
                id: renameColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Text {
                    text: "Renomear"
                    color: Theme.text
                    font { pixelSize: 14; weight: Font.DemiBold }
                }

                TextField {
                    id: renameField
                    width: parent.width
                    text: menuRoot.pendingRenameName
                    color: Theme.text
                    placeholderText: "Digite o novo nome"
                    placeholderTextColor: Theme.textTer
                    selectByMouse: true
                    background: Rectangle {
                        radius: 8
                        color: Theme.bg
                        border.color: renameField.activeFocus ? Theme.accent : Theme.border
                        border.width: 1
                    }
                    onTextChanged: menuRoot.pendingRenameName = text
                    onAccepted: menuRoot.confirmRename()
                }

                Row {
                    spacing: 8

                    Rectangle {
                        width: 92
                        height: 34
                        radius: 8
                        color: cancelRenameMouse.containsMouse ? Theme.hover : Theme.toolbar

                        Text {
                            anchors.centerIn: parent
                            text: "Cancelar"
                            color: Theme.text
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: cancelRenameMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: menuRoot.renamingItem = false
                        }
                    }

                    Rectangle {
                        width: 92
                        height: 34
                        radius: 8
                        color: applyRenameMouse.containsMouse ? Theme.accentSoft : Theme.accentLight

                        Text {
                            anchors.centerIn: parent
                            text: "Renomear"
                            color: Theme.text
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: applyRenameMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: menuRoot.confirmRename()
                        }
                    }
                }
            }
        }
    }

    Process {
        id: createFolderProcess
        command: [
            "bash",
            "-lc",
            "base=\"$1\"; name=\"$2\"; target=\"$base/$name\"; n=2; while [ -e \"$target\" ]; do target=\"$base/$name $n\"; n=$((n+1)); done; mkdir -- \"$target\"",
            "_",
            AppState.currentPath,
            pendingFolderName
        ]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0)
                AppState.refreshCurrentFolder()
        }
    }

    Process {
        id: renameProcess
        command: [
            "bash",
            "-lc",
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
            "bash",
            "-lc",
            "target=\"$1\"; " +
            "[ -e \"$target\" ] || { echo 'ERROR|Arquivo nao encontrado'; exit 1; }; " +
            "meta=$(stat -Lc '%F|%s|%Y|%X|%A' -- \"$target\" 2>/dev/null) || { echo 'ERROR|Nao foi possivel ler os metadados'; exit 1; }; " +
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
                    menuRoot.propertiesError = "Nao foi possivel carregar as propriedades."
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
                menuRoot.propertiesPermissionsText = parts[5] || "Indisponivel"
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



    component MenuAction: Item {
        id: actionRoot
        property string label: ""
        property string shortcut: ""
        property bool destructive: false
        signal triggered()

        width: parent ? parent.width : 184
        height: 34

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: actionHover.containsMouse
                   ? (actionRoot.destructive ? Qt.rgba(0.8, 0.24, 0.24, 0.24) : Qt.rgba(0.24, 0.5, 0.95, 0.24))
                   : "transparent"
            border.width: actionHover.containsMouse ? 1 : 0
            border.color: actionHover.containsMouse
                          ? (actionRoot.destructive ? Qt.rgba(1, 0.65, 0.65, 0.2) : Qt.rgba(0.75, 0.87, 1, 0.16))
                          : "transparent"

            Behavior on color { ColorAnimation { duration: 90 } }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
                text: actionRoot.label
                color: actionRoot.destructive ? "#ff8b8b" : Theme.text
                font { pixelSize: 13; weight: Font.Medium }
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: 1; height: 1 }

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

    component InfoLabel: Text {
        property string label: ""
        text: label
        color: Theme.textTer
        font.pixelSize: 12
        width: 96
        wrapMode: Text.WordWrap
    }

    component InfoValue: Text {
        property string value: ""
        text: value
        color: Theme.text
        font.pixelSize: 12
        width: propertiesColumn.width - 96 - 12
        wrapMode: Text.WrapAnywhere
    }
}
