import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../AstreaComponents"
import "../../AstreaI18n" as AstreaI18n

ScrollPage {
    id: root

    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color cardBg: Theme.cardBg
    readonly property color cardBorder: Theme.cardBorder
    readonly property color accent: Theme.accent
    readonly property color popupBg: Theme.popupBg
    readonly property color errorColor: Theme.errorColor

    readonly property string scriptPath: (Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")) + "/Core/bridge/apps/manager.py"

    property bool loading: true
    property string errorMessage: ""
    property string searchText: ""
    property string _appsBuf: ""
    property string _detailsBuf: ""
    property string _actionBuf: ""
    property string actionMessage: ""
    property bool actionError: false
    property string selectedAppId: ""
    property var selectedAppData: ({})
    property string detailsAppId: ""
    property bool detailsLoading: false
    property string detailsError: ""
    property real savedListScrollY: 0
    property var appsData: ({ apps: [], total: 0 })
    property var detailsData: ({})

    readonly property var filteredApps: appsData.apps.filter(function(app) {
        const q = root.searchText.trim().toLowerCase()
        if (q === "")
            return true
        const hay = [
            app.name || "",
            app.comment || "",
            app.id || ""
        ].join(" ").toLowerCase()
        return hay.indexOf(q) !== -1
    })

    function reloadApps() {
        if (appsProc.running)
            return
        root.loading = true
        root.errorMessage = ""
        root._appsBuf = ""
        appsProc.running = true
    }

    function appIdentifier(app) {
        return app ? (app.desktop_file || app.id || "") : ""
    }

    function isProtectedApp(app) {
        if (!app)
            return false
        return app.protected === true || (app.id || "") === "astrea-settings.desktop"
    }

    function toggleExpanded(app) {
        root.openAppPage(app)
    }

    function currentScrollY() {
        return root.contentItem && root.contentItem.contentY !== undefined ? root.contentItem.contentY : 0
    }

    function setScrollY(y) {
        if (!root.contentItem || root.contentItem.contentY === undefined)
            return
        const maxY = Math.max(0, root.contentItem.contentHeight - root.contentItem.height)
        root.contentItem.contentY = Math.max(0, Math.min(y, maxY))
    }

    function restoreListScrollY() {
        const y = root.savedListScrollY
        Qt.callLater(function() {
            root.setScrollY(y)
            Qt.callLater(function() {
                root.setScrollY(y)
            })
        })
    }

    function openAppPage(app) {
        const id = root.appIdentifier(app)
        if (!id)
            return
        root.savedListScrollY = root.currentScrollY()
        root.setScrollY(0)
        root.selectedAppId = id
        root.selectedAppData = app
        root.loadDetails(app)
        root.setScrollY(0)
        Qt.callLater(function() {
            root.setScrollY(0)
        })
    }

    function closeAppPage() {
        root.selectedAppId = ""
        root.selectedAppData = ({})
        root.detailsError = ""
        root.actionMessage = ""
        root.actionError = false
        root.restoreListScrollY()
    }

    function detailApp(app) {
        if (root.detailsAppId === root.appIdentifier(app) && root.detailsData && root.detailsData.app)
            return root.detailsData.app
        return app
    }

    function permissionFor(id) {
        const app = root.detailApp(root.selectedAppData)
        const permissions = app.permissions || []
        for (let i = 0; i < permissions.length; i++) {
            if (permissions[i].id === id)
                return permissions[i]
        }
        if (id === "microphone")
            return ({ id: "microphone", name: "Microfone", description: "Carregando permissão do app...", blocked: false, supported: false })
        if (id === "camera")
            return ({ id: "camera", name: "Câmera", description: "Carregando permissão do app...", blocked: false, supported: false })
        return ({ id: id, name: "", description: "", blocked: false, supported: false })
    }

    function uninstallState() {
        if (root.isProtectedApp(root.selectedAppData))
            return ({ can: false, label: "Settings protegido", reason: "Settings é protegido e não pode ser desinstalado." })
        if (root.detailsLoading)
            return ({ can: false, label: "Verificando...", reason: "" })
        const app = root.detailApp(root.selectedAppData)
        if (app.uninstall)
            return app.uninstall
        return ({ can: false, label: "Desinstalar", reason: "Não foi possível verificar a forma de remoção deste app." })
    }

    function loadDetails(app) {
        const id = root.appIdentifier(app)
        if (!id || detailsProc.running)
            return
        root.detailsAppId = id
        root.detailsLoading = true
        root.detailsError = ""
        root.detailsData = ({})
        root._detailsBuf = ""
        detailsProc.targetAppId = id
        detailsProc.command = ["python3", root.scriptPath, "details", id]
        detailsProc.running = true
    }

    function runAction(action, app, permissionId, blocked) {
        if (!app || actionProc.running)
            return

        root.actionMessage = ""
        root.actionError = false
        root._actionBuf = ""
        actionProc.currentAction = action
        let command = ["python3", root.scriptPath, action, root.appIdentifier(app)]
        if (action === "set-permission")
            command = command.concat([permissionId || "", blocked ? "blocked" : "allowed"])
        actionProc.command = command
        actionProc.running = true
    }

    Component.onCompleted: reloadApps()

    Connections {
        target: AstreaI18n.I18n
        function onLanguageChanged() {
            root.reloadApps()
        }
    }

    Process {
        id: appsProc
        command: ["python3", root.scriptPath]
        running: false
        stdout: SplitParser {
            onRead: line => root._appsBuf += line
        }
        onExited: code => {
            root.loading = false
            if (code !== 0) {
                root.errorMessage = "Não foi possível ler os apps instalados"
                return
            }

            try {
                root.appsData = JSON.parse(root._appsBuf || "{}")
            } catch (e) {
                root.errorMessage = "Erro lendo lista de apps: " + e
            }
            root._appsBuf = ""
        }
    }

    Process {
        id: detailsProc
        property string targetAppId: ""
        command: []
        running: false
        stdout: SplitParser {
            onRead: line => root._detailsBuf += line
        }
        onExited: code => {
            if (targetAppId !== root.selectedAppId)
                return

            root.detailsLoading = false
            let payload = ({})
            try {
                payload = JSON.parse(root._detailsBuf || "{}")
            } catch (e) {
                payload = ({ ok: false, message: "Erro lendo detalhes do app: " + e })
            }

            if (code !== 0 || payload.ok === false) {
                root.detailsError = payload.message || "Não foi possível ler as configurações do app"
                root.detailsData = ({})
            } else {
                root.detailsData = payload
            }
            root._detailsBuf = ""
        }
    }

    Process {
        id: actionProc
        property string currentAction: ""
        command: []
        running: false
        stdout: SplitParser {
            onRead: line => root._actionBuf += line
        }
        onExited: code => {
            let payload = ({})
            try {
                payload = JSON.parse(root._actionBuf || "{}")
            } catch (e) {
                payload = ({ message: "Erro lendo resposta da ação: " + e })
            }

            root.actionError = code !== 0 || payload.ok === false
            root.actionMessage = payload.message || (root.actionError ? "Ação falhou" : "Ação concluída")
            root._actionBuf = ""

            if (!root.actionError && (currentAction === "create-shortcut" || currentAction === "uninstall"))
                root.reloadApps()
            if (!root.actionError && currentAction === "uninstall")
                root.closeAppPage()
            if (!root.actionError && currentAction === "set-permission") {
                if (payload.app)
                    root.detailsData = ({ ok: true, app: payload.app })
                else if (root.selectedAppId !== "")
                    root.loadDetails({ desktop_file: root.selectedAppId, id: root.selectedAppId })
            }
        }
    }

    component AppRow: Item {
        id: rowItem
        required property var modelData
        required property int index
        required property bool isLast

        implicitWidth: parent ? parent.width : 200
        readonly property bool hasComment: !!(modelData.comment && modelData.comment !== "")
        readonly property int baseHeight: hasComment ? 68 : 56
        implicitHeight: baseHeight

        Rectangle {
            anchors {
                fill: parent
                leftMargin: 8
                rightMargin: 8
                topMargin: 6
                bottomMargin: 6
            }
            radius: 12
            color: rowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
            border.width: rowArea.containsMouse ? 1 : 0
            border.color: Qt.rgba(1, 1, 1, 0.04)
            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on border.color { ColorAnimation { duration: 180 } }
        }

        Item {
            id: rowContent
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 22
                rightMargin: 22
                top: parent.top
                topMargin: rowItem.hasComment ? 13 : 10
            }
            height: parent.hasComment ? 42 : 36

            AppIcon {
                id: iconBox
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                appData: modelData
                iconSize: 42
                iconRadius: 10
                fallbackColor: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                fallbackBorderColor: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                fallbackTextColor: root.textPrimary
                fallbackFontFamily: Theme.fontFamily
            }

            Column {
                anchors {
                    left: iconBox.right
                    leftMargin: 14
                    right: parent.right
                    rightMargin: 28
                    verticalCenter: parent.verticalCenter
                }
                spacing: rowItem.hasComment ? 2 : 0

                Text {
                    width: parent.width
                    text: modelData.name || modelData.id
                    color: root.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    visible: rowItem.hasComment
                    width: parent.width
                    text: modelData.comment || ""
                    color: root.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
            }

            Text {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                text: "›"
                color: root.textSecondary
                font.pixelSize: 20
            }
        }

        Rectangle {
            visible: !isLast
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: 22
                rightMargin: 22
            }
            height: 1
            color: root.cardBorder
        }

        MouseArea {
            id: rowArea
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: rowItem.baseHeight
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: root.toggleExpanded(rowItem.modelData)
        }
    }

    component InfoPill: Rectangle {
        id: pill
        property string label: ""
        property string value: ""

        implicitHeight: 48
        radius: 10
        color: Qt.rgba(1, 1, 1, 0.045)
        border.width: 1
        border.color: root.cardBorder

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 2

            Text {
                width: parent.width
                text: pill.label
                color: root.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: pill.value
                color: root.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }
    }

    component InfoLine: RowLayout {
        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        spacing: 8

        Text {
            text: label
            color: root.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 11
            Layout.preferredWidth: 58
            elide: Text.ElideRight
        }

        Text {
            text: value
            color: root.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: 11
            Layout.fillWidth: true
            elide: Text.ElideMiddle
        }
    }

    component PermissionRow: Rectangle {
        id: permissionRow
        required property var permission
        required property var appData
        readonly property bool canEdit: permission && permission.supported === true && !actionProc.running

        implicitHeight: Math.max(60, permissionText.implicitHeight + 22)
        radius: 10
        color: Qt.rgba(1, 1, 1, 0.035)
        border.width: 1
        border.color: root.cardBorder

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12

            ColumnLayout {
                id: permissionText
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: permission ? (permission.name || "") : ""
                    color: root.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: permission ? (permission.description || "") : ""
                    color: root.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            ToggleSwitch {
                checked: permission && permission.blocked === true
                enabled: permissionRow.canEdit
                onToggled: targetChecked => root.runAction("set-permission", permissionRow.appData, permissionRow.permission.id, targetChecked)
            }
        }
    }

    component ActionChip: Rectangle {
        id: chip
        property string label: ""
        property bool destructive: false
        signal triggered()

        implicitHeight: 34
        radius: 9
        color: chip.enabled
            ? (chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.055))
            : Qt.rgba(1, 1, 1, 0.035)
        border.width: 1
        border.color: chip.enabled && chip.destructive
            ? Qt.rgba(root.errorColor.r, root.errorColor.g, root.errorColor.b, 0.38)
            : root.cardBorder
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            width: parent.width - 20
            text: chip.label
            color: !chip.enabled
                ? root.textSecondary
                : (chip.destructive ? root.errorColor : root.textPrimary)
            opacity: chip.enabled ? 1 : 0.55
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            enabled: chip.enabled
            hoverEnabled: true
            cursorShape: chip.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: chip.triggered()
        }
    }

    Item {
        Layout.alignment: Qt.AlignHCenter
        visible: root.loading
        width: 48
        height: 48
        BusyIndicator {
            anchors.fill: parent
            running: root.loading
        }
    }

    ColumnLayout {
        width: parent.width
        spacing: 0
        visible: !root.loading && root.selectedAppId === ""

        SectionHeader {
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.apps.apps.text.apps"]) || "APPS")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 24
            radius: 12
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder
            implicitHeight: topCol.implicitHeight + 32

            ColumnLayout {
                id: topCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.apps.apps.text.installed_applications"]) || "Installed applications")
                        color: root.textPrimary
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: root.filteredApps.length + " apps visíveis de " + appsData.total + " instalados"
                        color: root.textSecondary
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: root.cardBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: "⌕"
                            color: root.textSecondary
                            font.pixelSize: 14
                        }

                        TextField {
                            Layout.fillWidth: true
                            text: root.searchText
                            placeholderText: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.apps.apps.placeholderText.buscar_por_nome_comentario_ou_desktop_id"]) || "Search by name, comment, or desktop id")
                            color: root.textPrimary
                            placeholderTextColor: root.textSecondary
                            background: Item {}
                            onTextChanged: root.searchText = text
                        }
                    }
                }

                Text {
                    visible: root.errorMessage !== ""
                    text: root.errorMessage
                    color: root.errorColor
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                Text {
                    visible: root.actionMessage !== ""
                    text: root.actionMessage
                    color: root.actionError ? root.errorColor : root.textSecondary
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 28
            radius: 12
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder
            implicitHeight: root.filteredApps.length === 0 ? 96 : appsCol.implicitHeight + 10

            Text {
                anchors.centerIn: parent
                visible: root.filteredApps.length === 0
                text: root.searchText.trim() === ""
                    ? "Nenhum app encontrado"
                    : "Nenhum app corresponde à busca"
                color: root.textSecondary
                font.pixelSize: 12
            }

            ColumnLayout {
                id: appsCol
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    topMargin: 4
                    bottom: parent.bottom
                    bottomMargin: 6
                }
                spacing: 0
                visible: root.filteredApps.length > 0

                Repeater {
                    model: root.filteredApps
                    delegate: AppRow {
                        isLast: index === root.filteredApps.length - 1
                    }
                }
            }
        }
    }

    ColumnLayout {
        width: parent.width
        spacing: 0
        visible: !root.loading && root.selectedAppId !== ""

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 16
            spacing: 10

            ActionChip {
                Layout.preferredWidth: 92
                label: "‹ Voltar"
                enabled: true
                onTriggered: root.closeAppPage()
            }

            Text {
                Layout.fillWidth: true
                text: "Apps"
                color: root.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 18
            radius: 12
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder
            implicitHeight: appHeader.implicitHeight + 32

            RowLayout {
                id: appHeader
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                AppIcon {
                    appData: root.detailApp(root.selectedAppData)
                    iconSize: 64
                    iconRadius: 16
                    fallbackColor: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                    fallbackBorderColor: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                    fallbackTextColor: root.textPrimary
                    fallbackFontFamily: Theme.fontFamily
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: root.detailApp(root.selectedAppData).name || root.detailApp(root.selectedAppData).id || "App"
                        color: root.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.detailApp(root.selectedAppData).comment || root.detailApp(root.selectedAppData).generic || root.detailApp(root.selectedAppData).id || ""
                        color: root.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.detailsError !== ""
            text: root.detailsError
            color: root.errorColor
            font.family: Theme.fontFamily
            font.pixelSize: 12
            wrapMode: Text.Wrap
            Layout.bottomMargin: 12
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 18
            radius: 12
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder
            implicitHeight: infoCol.implicitHeight + 32

            ColumnLayout {
                id: infoCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: "Informações"
                    color: root.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 10

                    InfoPill {
                        Layout.fillWidth: true
                        label: "Tipo"
                        value: root.detailApp(root.selectedAppData).install_type || (root.selectedAppData.source === "user" ? "Usuário" : "Sistema")
                    }

                    InfoPill {
                        Layout.fillWidth: true
                        label: "Tamanho"
                        value: root.detailsLoading
                            ? "Calculando..."
                            : (root.detailApp(root.selectedAppData).size ? root.detailApp(root.selectedAppData).size.label : "Não disponível")
                    }
                }

                InfoLine {
                    label: "ID"
                    value: root.detailApp(root.selectedAppData).flatpak_id || root.detailApp(root.selectedAppData).id || ""
                }

                InfoLine {
                    label: "Arquivo"
                    value: root.detailApp(root.selectedAppData).desktop_file || ""
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 18
            radius: 12
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder
            implicitHeight: permissionsCol.implicitHeight + 32

            ColumnLayout {
                id: permissionsCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: "Privacidade"
                    color: root.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                PermissionRow {
                    Layout.fillWidth: true
                    permission: root.permissionFor("microphone")
                    appData: root.selectedAppData
                }

                PermissionRow {
                    Layout.fillWidth: true
                    permission: root.permissionFor("camera")
                    appData: root.selectedAppData
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 28
            radius: 12
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder
            implicitHeight: actionsCol.implicitHeight + 32

            ColumnLayout {
                id: actionsCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: "Ações"
                    color: root.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ActionChip {
                        Layout.fillWidth: true
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.apps.apps.label.criar_atalho"]) || "Create shortcut")
                        enabled: !actionProc.running
                        onTriggered: root.runAction("create-shortcut", root.selectedAppData)
                    }

                    ActionChip {
                        Layout.fillWidth: true
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.apps.apps.label.abrir_local"]) || "Open location")
                        enabled: !actionProc.running
                        onTriggered: root.runAction("open-location", root.selectedAppData)
                    }
                }

                ActionChip {
                    Layout.fillWidth: true
                    label: root.uninstallState().label || "Desinstalar"
                    destructive: root.uninstallState().can === true
                    enabled: root.uninstallState().can === true && !actionProc.running
                    onTriggered: root.runAction("uninstall", root.selectedAppData)
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.uninstallState().can !== true && (root.uninstallState().reason || "") !== ""
                    text: root.uninstallState().reason || ""
                    color: root.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.actionMessage !== ""
                    text: root.actionMessage
                    color: root.actionError ? root.errorColor : root.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
