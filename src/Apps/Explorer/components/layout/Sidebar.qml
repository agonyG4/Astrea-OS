import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.impl 2.15
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io
import "../../AstreaFiles/DragDropSupport.js" as DragDropSupport
import "../.."
import "../common" as Common
import "../../AstreaComponents" as UI
import "../../AstreaFiles" as AstreaFiles
import "../../AstreaI18n" as AstreaI18n

// ─────────────────────────────────────────────────────────────────────────────
// Root transparente — serve apenas como âncora de posição na janela.
// O visual da sidebar vive dentro de "floatingCard".
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root
    width: 256          // largura total incluindo margens externas

    // ── Propriedades do drive context-menu (sem alteração) ────────────────────
    property bool   driveMenuOpen:        false
    property real   driveMenuX:           10
    property real   driveMenuY:           10
    property string driveMenuDeviceId:    ""
    property string driveMenuDevicePath:  ""
    property string driveMenuPath:        ""
    property bool   driveMenuMounted:     false
    property bool   driveMenuCanMount:    false
    property bool   driveMenuCanUnmount:  false
    property bool   driveMenuCanRemount:  false
    property bool   driveMenuAutoMount:   false
    property bool   driveMenuBusy:        false
    property bool   sidebarMenuOpen:      false
    property real   sidebarMenuX:         10
    property real   sidebarMenuY:         10
    property string sidebarMenuPath:      ""
    property string sidebarMenuLabel:     ""
    property string sidebarMenuIcon:      "inode-directory"
    property bool   sidebarMenuCanPin:    false
    property bool   sidebarMenuIsFavorite:false
    property string desktopLinkPath:      ""
    property string desktopLinkError:     ""

    readonly property color sidebarIconIdle: Theme.isLight ? UI.Theme.textSecondary : Qt.rgba(1, 1, 1, 0.78)
    readonly property color sidebarIconHover: UI.Theme.textPrimary
    readonly property color sidebarIconActive: UI.Theme.accentForeground
    readonly property var defaultFavoriteItems: [
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.desktop"]) || "Desktop"),    icon: "user-desktop",      path: AppState.homePath + "/Área de trabalho" },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.documentos"]) || "Documents"), icon: "folder-documents",  path: AppState.homePath + "/Documentos" },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.downloads"]) || "Downloads"),  icon: "folder-downloads",  path: AppState.homePath + "/Downloads" },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.imagens"]) || "Pictures"),    icon: "folder-pictures",   path: AppState.homePath + "/Imagens" },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["explorer.sidebar.music"]) || "Music"),    icon: "folder-music",      path: AppState.homePath + "/Músicas" },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["explorer.sidebar.videos"]) || "Videos"),     icon: "folder-videos",     path: AppState.homePath + "/Vídeos" },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["explorer.sidebar.public"]) || "Public"),    icon: "folder-publicshare",path: AppState.homePath + "/Público" },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.modelos"]) || "Templates"),    icon: "folder-templates",  path: AppState.homePath + "/Modelos" }
    ]

    function openDriveMenu(item, mouse) {
        AppState.announceContextMenuOpening("sidebar")
        sidebarMenuOpen = false
        driveMenuDeviceId    = item.deviceId
        driveMenuDevicePath  = item.devicePath
        driveMenuPath        = item.path
        driveMenuMounted     = item.mounted
        driveMenuCanMount    = item.canMount
        driveMenuCanUnmount  = item.canUnmount
        driveMenuCanRemount  = item.canRemount
        driveMenuAutoMount   = item.autoMount
        driveMenuBusy        = item.busy

        var point    = item.mapToItem(driveMenuOverlay, mouse.x, mouse.y)
        driveMenuX   = Math.max(10, Math.min(point.x + 6, driveMenuOverlay.width  - driveMenuCard.width  - 10))
        driveMenuY   = Math.max(10, Math.min(point.y + 6, driveMenuOverlay.height - driveMenuCard.height - 10))
        driveMenuOpen = true
    }

    function closeDriveMenu() {
        driveMenuOpen = false
    }

    function openSidebarMenu(item, mouse) {
        AppState.announceContextMenuOpening("sidebar")
        driveMenuOpen = false
        sidebarMenuPath = item.path
        sidebarMenuLabel = item.label
        sidebarMenuIcon = item.icon
        sidebarMenuCanPin = AppState.canPinSidebarFavorite(item.path)
        sidebarMenuIsFavorite = AppState.isSidebarFavorite(item.path)

        var point = item.mapToItem(driveMenuOverlay, mouse.x, mouse.y)
        sidebarMenuX = Math.max(10, Math.min(point.x + 6, driveMenuOverlay.width - sidebarMenuCard.width - 10))
        sidebarMenuY = Math.max(10, Math.min(point.y + 6, driveMenuOverlay.height - sidebarMenuCard.height - 10))
        sidebarMenuOpen = true
    }

    function closeSidebarMenu() {
        sidebarMenuOpen = false
    }

    function closeMenus() {
        closeDriveMenu()
        closeSidebarMenu()
    }

    function showSidebarProperties() {
        var target = sidebarMenuPath
        closeMenus()
        sidebarProperties.targetPath = target
        sidebarProperties.targetIsDir = true
        sidebarProperties.show()
        sidebarProperties.raise()
        sidebarProperties.requestActivate()
    }

    function putSidebarItemOnDesktop() {
        if (sidebarMenuPath === "" || sidebarMenuPath.indexOf("/") !== 0)
            return
        desktopLinkPath = sidebarMenuPath
        desktopLinkError = ""
        closeMenus()
        desktopLinkProcess.running = false
        desktopLinkProcess.running = true
    }

    function handleDroppedUrls(drop, destinationPath) {
        return DragDropSupport.handleDroppedUrls(AppState, drop, destinationPath)
    }

    Connections {
        target: AppState
        function onContextMenuOpening(owner) {
            if (owner !== "sidebar")
                root.closeMenus()
        }
    }

    // ── Card flutuante principal ───────────────────────────────────────────────
    UI.SidebarFrame {
        id: floatingCard
        anchors {
            fill:           parent
            topMargin:      10
            bottomMargin:   10
            leftMargin:     12
            rightMargin:    8
        }
        backgroundColor: UI.Theme.cardBg
        washColor: UI.Theme.windowWash
        borderColor: UI.Theme.cardBorder
        cornerRadius: 20
        contentTopPadding: 16
        contentBottomPadding: 16
        contentSpacing: 2

        // ── Header ────────────────────────────────────────────────────
        Item {
            width: parent.width - 32
            x: 16
            height: 36

            Text {
                anchors {
                    left: parent.left
                    right: searchBtn.left
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.text.finder"]) || "Finder")
                color: UI.Theme.textPrimary
                font.family: UI.Theme.fontFamily
                font.pixelSize: UI.Theme.fontSizeLarge
                font.weight: UI.Theme.fontWeightDemiBold
                font.letterSpacing: 0
                elide: Text.ElideRight
            }

            Rectangle {
                id: searchBtn
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 28
                height: 28
                radius: 9
                color:  searchHover.containsMouse
                            ? (Theme.isLight ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.10))
                            : (Theme.isLight ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(1, 1, 1, 0.05))
                border.width: 1
                border.color: UI.Theme.cardBorder

                Behavior on color { ColorAnimation { duration: UI.Theme.animationQuick } }

                Image {
                    source: AppState.sidebarIconSource("system-search", 16)
                    width: 14; height: 14
                    anchors.centerIn: parent
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    sourceSize: Qt.size(14, 14)
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 1.0
                        colorizationColor: searchHover.containsMouse ? UI.Theme.textPrimary : UI.Theme.textSecondary
                    }
                }

                MouseArea {
                    id: searchHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AppState.startSearch()
                }
            }
        }

        Rectangle {
            width: parent.width - 32
            x: 16
            height: 1
            color: UI.Theme.cardBorder
        }

        Item { width: 1; height: 8 }

        // ── Pessoal ───────────────────────────────────────────────────
        SidebarSection { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.pessoal"]) || "PERSONAL") }
        SidebarItem { icon: "inode-directory";      label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.pasta_pessoal"]) || "Home Folder"); path: AppState.homePath }
        SidebarItem { icon: "document-open-recent"; label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.recentes"]) || "Recents");      path: AppState.recentVirtualPath }

        Item { width: 1; height: 4 }

        // ── Favoritos ─────────────────────────────────────────────────
        SidebarSection { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.favoritos"]) || "FAVORITES") }
        Repeater {
            model: {
                var revision = AppState.sidebarFavoritesRevision
                return AppState.visibleDefaultSidebarFavorites(root.defaultFavoriteItems)
            }
            SidebarItem { icon: modelData.icon; label: modelData.label; path: modelData.path }
        }
        Repeater {
            model: AppState.sidebarFavorites
            SidebarItem { icon: modelData.icon || "inode-directory"; label: modelData.label || AppState.sidebarLabelForPath(modelData.path); path: modelData.path }
        }

        Item { width: 1; height: 4 }

        // ── Dispositivos ──────────────────────────────────────────────
        SidebarSection { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.dispositivos"]) || "DEVICES") }
        SidebarItem { icon: "drive-harddisk"; label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.sistema"]) || "System"); path: "/" }
        Repeater {
            model: AppState.deviceModel
            DeviceSidebarItem {
                deviceId:    model.id
                icon:        model.icon
                label:       model.title
                subtitle:    model.subtitle
                path:        model.mountPath
                devicePath:  model.devicePath
                mounted:     model.mounted
                canMount:    model.canMount
                canUnmount:  model.canUnmount
                canRemount:  model.canRemount
                autoMount:   model.autoMount
                busy:        model.busy
            }
        }
        SidebarItem {
            icon:   "network-workgroup"
            label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.rede"]) || "Network")
            action: "network"
            path:   AppState.networkRootPath
        }
        Text {
            width: parent.width - 28
            x: 14
            visible: AppState.deviceError !== ""
            text:    AppState.deviceError
            color:   "#ff9a9a"
            wrapMode: Text.WordWrap
            font.pixelSize: 11
        }

        Item { width: 1; height: 4 }

        // ── Outro ─────────────────────────────────────────────────────
        SidebarSection { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.outro"]) || "OTHER") }
        SidebarItem {
            icon:  "user-trash"
            label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.lixeira"]) || "Trash")
            path:  AppState.trashFilesPath
        }

        Item { width: 1; height: 6 }
    }

    // ── Drive context-menu overlay (sem alteração de lógica) ──────────────────
    Item {
        id: driveMenuOverlay
        parent: Overlay.overlay
        x: 0
        y: 0
        width: parent ? parent.width : root.width
        height: parent ? parent.height : root.height
        visible: root.driveMenuOpen || root.sidebarMenuOpen
        z: 999

        MouseArea {
            anchors.fill: parent
            z: 0
            enabled: root.driveMenuOpen || root.sidebarMenuOpen
            acceptedButtons: Qt.AllButtons
            onPressed: function(mouse) {
                mouse.accepted = true
                root.closeMenus()
            }
        }

        Common.ContextMenuPopup {
            id: driveMenuCard
            menuVisible: root.driveMenuOpen
            menuX:       root.driveMenuX
            menuY:       root.driveMenuY
            z:           1

            Common.ContextMenuAction {
                label: root.driveMenuMounted ? (((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.open"]) || "Open")) : (((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.mount"]) || "Mount"))
                actionEnabled: !root.driveMenuBusy && (root.driveMenuMounted || root.driveMenuCanMount)
                onTriggered: {
                    root.closeDriveMenu()
                    if (root.driveMenuMounted)
                        AppState.navigateTo(root.driveMenuPath)
                    else
                        AppState.requestMountDevice(root.driveMenuDevicePath, false, true)
                }
            }

            Common.ContextMenuAction {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.desmontar"]) || "Unmount")
                actionEnabled: !root.driveMenuBusy && root.driveMenuMounted && root.driveMenuCanUnmount
                onTriggered: {
                    root.closeDriveMenu()
                    AppState.requestUnmountDevice(root.driveMenuDevicePath, root.driveMenuPath)
                }
            }

            Common.ContextMenuAction {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.remontar_com_nome"]) || "Remount with name")
                visible: root.driveMenuCanRemount
                actionEnabled: !root.driveMenuBusy && root.driveMenuCanRemount
                onTriggered: {
                    root.closeDriveMenu()
                    AppState.requestRemountDevice(root.driveMenuDevicePath, root.driveMenuPath, true)
                }
            }

            Common.ContextMenuDivider {}

            Common.ContextMenuAction {
                label: root.driveMenuAutoMount ? (((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.do_not_always_mount"]) || "Do not always mount")) : (((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.always_mount"]) || "Always mount"))
                actionEnabled: !root.driveMenuBusy
                onTriggered: {
                    root.closeDriveMenu()
                    AppState.toggleDeviceAutoMount(root.driveMenuDeviceId)
                }
            }
        }

        Common.ContextMenuPopup {
            id: sidebarMenuCard
            menuVisible: root.sidebarMenuOpen
            menuX:       root.sidebarMenuX
            menuY:       root.sidebarMenuY
            menuWidth:   212
            z:           1

            Common.ContextMenuAction {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.open"]) || "Open")
                actionEnabled: root.sidebarMenuPath !== ""
                onTriggered: {
                    root.closeSidebarMenu()
                    if (root.sidebarMenuPath === AppState.networkRootPath)
                        AppState.openNetworkBrowser()
                    else
                        AppState.navigateTo(root.sidebarMenuPath)
                }
            }

            Common.ContextMenuAction {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.open_in_new_tab"]) || "Open in new tab")
                actionEnabled: root.sidebarMenuPath !== "" && root.sidebarMenuPath.indexOf("/") === 0
                onTriggered: {
                    root.closeSidebarMenu()
                    AppState.createTab(root.sidebarMenuPath)
                }
            }

            Common.ContextMenuDivider { visible: root.sidebarMenuCanPin }

            Common.ContextMenuAction {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.pin_to_sidebar"]) || "Pin to sidebar")
                visible: root.sidebarMenuCanPin && !root.sidebarMenuIsFavorite
                actionEnabled: true
                onTriggered: {
                    root.closeSidebarMenu()
                    AppState.pinSidebarFavorite(root.sidebarMenuPath, root.sidebarMenuLabel, root.sidebarMenuIcon)
                }
            }

            Common.ContextMenuDivider {}

            Common.ContextMenuAction {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.create_desktop_shortcut"]) || "Create desktop shortcut")
                actionEnabled: root.sidebarMenuPath !== "" && root.sidebarMenuPath.indexOf("/") === 0
                onTriggered: root.putSidebarItemOnDesktop()
            }

            Common.ContextMenuAction {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.propriedades"]) || "Properties")
                actionEnabled: root.sidebarMenuPath !== ""
                onTriggered: root.showSidebarProperties()
            }

            Common.ContextMenuDivider { visible: root.sidebarMenuCanPin && root.sidebarMenuIsFavorite }

            Common.ContextMenuAction {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.remove_from_favorites"]) || "Remove from favorites")
                visible: root.sidebarMenuCanPin && root.sidebarMenuIsFavorite
                actionEnabled: true
                destructive: true
                onTriggered: {
                    root.closeSidebarMenu()
                    AppState.removeSidebarFavorite(root.sidebarMenuPath)
                }
            }
        }
    }

    Process {
        id: desktopLinkProcess
        command: ["python3", AppState.helperPath, "create-desktop-shortcut", root.desktopLinkPath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var payload = JSON.parse(text || "{}")
                    if (payload.ok !== true)
                        root.desktopLinkError = payload.error || ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.error.failed_to_create_shortcut"]) || "Failed to create shortcut")
                } catch (error) {
                    root.desktopLinkError = ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.error.invalid_shortcut_response"]) || "Invalid shortcut response")
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") root.desktopLinkError = text.trim()
        }
        onExited: function(exitCode) {
            if (exitCode === 0 && AppState.currentPath === AppState.defaultSidebarFavoritePaths[0])
                AppState.refreshCurrentFolder()
            if (exitCode !== 0 && root.desktopLinkError === "")
                root.desktopLinkError = ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.error.failed_to_create_desktop_shortcut"]) || "Failed to create desktop shortcut")
        }
    }

    Text {
        visible: root.desktopLinkError !== ""
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        color: "#ff9a9a"
        font.pixelSize: 11
        text: root.desktopLinkError
        wrapMode: Text.WordWrap
        z: 100
    }

    Window {
        id: sidebarProperties
        title: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.common.file_context_menu.label.propriedades"]) || "Properties")
        width: 440
        height: 340
        minimumWidth: 380
        minimumHeight: 300
        color: "#1c1c1e"
        flags: Qt.Window | Qt.Dialog

        property string targetPath: ""
        property bool targetIsDir: true
        property bool isLoading: false
        property string errorText: ""
        property string propType: ""
        property string propSize: ""
        property string propModified: ""
        property string propPerms: ""
        property string propContains: ""

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
            propSize = ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.text.loading"]) || "Loading...")
            propModified = ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.text.loading"]) || "Loading...")
            propPerms = ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.text.loading"]) || "Loading...")
            propContains = targetIsDir ? ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.text.loading"]) || "Loading...") : ""
            propProcess.command = [
                "bash", "-lc",
                "target=\"$1\"; " +
                "[ -e \"$target\" ] || [ -L \"$target\" ] || { echo 'ERROR|'$2; exit 1; }; " +
                "meta=$(stat -Lc '%F|%s|%Y|%A' -- \"$target\" 2>/dev/null) || { echo 'ERROR|'$3; exit 1; }; " +
                "IFS='|' read -r kind bytes modified perms <<EOF\n$meta\nEOF\n" +
                "if [ -d \"$target\" ]; then " +
                "  size=$(du -sb -- \"$target\" 2>/dev/null | cut -f1); " +
                "  count=$(find \"$target\" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l); " +
                "  printf 'OK|%s|%s|%s|%s|%s\\n' \"$kind\" \"${size:-0}\" \"$modified\" \"$perms\" \"$count\"; " +
                "else " +
                "  printf 'OK|%s|%s|%s|%s|\\n' \"$kind\" \"$bytes\" \"$modified\" \"$perms\"; " +
                "fi",
                "_",
                sidebarProperties.targetPath,
                ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.error.file_not_found"]) || "File not found"),
                ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.error.failed_to_read_metadata"]) || "Failed to read metadata")
            ]
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
                    left: parent.left
                    leftMargin: 16
                    right: parent.right
                    rightMargin: 16
                    verticalCenter: parent.verticalCenter
                }
                text: sidebarProperties.targetPath.split("/").pop() || sidebarProperties.targetPath
                color: "#f2f2f7"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideMiddle
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1
                color: "#2c2c2c"
            }
        }

        Column {
            id: sidebarPropInfo
            anchors {
                top: propTitleBar.bottom
                topMargin: 16
                left: parent.left
                leftMargin: 16
                right: parent.right
                rightMargin: 16
                bottom: propFooter.top
                bottomMargin: 16
            }
            spacing: 10

            Repeater {
                model: [
                    { lbl: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.path"]) || "Path"), val: sidebarProperties.targetPath },
                    { lbl: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.type"]) || "Type"), val: sidebarProperties.propType },
                    { lbl: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.size"]) || "Size"), val: sidebarProperties.propSize },
                    { lbl: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.content"]) || "Content"), val: sidebarProperties.propContains },
                    { lbl: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.modified"]) || "Modified"), val: sidebarProperties.propModified },
                    { lbl: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.label.permissions"]) || "Permissions"), val: sidebarProperties.propPerms }
                ]

                Row {
                    width: sidebarPropInfo.width
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
                        width: sidebarPropInfo.width - 102
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }

            Text {
                visible: sidebarProperties.errorText !== ""
                text: sidebarProperties.errorText
                color: "#ff6b6b"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                width: sidebarPropInfo.width
            }
        }

        Rectangle {
            id: propFooter
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 48
            color: "#252527"

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                color: "#2c2c2c"
            }

            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                width: 80
                height: 30
                radius: 7
                color: propCloseMouse.containsMouse ? "#3a3a3c" : "#2c2c2e"
                border.color: "#48484a"
                border.width: 1

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
                    onClicked: sidebarProperties.close()
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
                        sidebarProperties.errorText = ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.error.no_system_response"]) || "No response from system.")
                        return
                    }
                    var parts = raw.split("|")
                    if (parts[0] !== "OK") {
                        sidebarProperties.errorText = parts.length > 1 ? parts.slice(1).join("|") : ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.sidebar.error.failed_to_load"]) || "Failed to load.")
                        return
                    }
                    sidebarProperties.errorText = ""
                    sidebarProperties.propType = parts[1] || "Item"
                    sidebarProperties.propSize = AppState.formatSize(Number(parts[2] || 0))
                    sidebarProperties.propModified = sidebarProperties.fmtDate(parts[3])
                    sidebarProperties.propPerms = parts[4] || "--"
                    sidebarProperties.propContains = parts[5] ? (parts[5] + (Number(parts[5]) === 1 ? " item" : " itens")) : "--"
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // SUB-COMPONENTES INTERNOS
    // ═════════════════════════════════════════════════════════════════════════

    // ── Label de seção ────────────────────────────────────────────────────────
    component SidebarSection: Item {
        property string label: ""
        width:  parent ? parent.width : 200
        height: 26

        Text {
            anchors {
                left:           parent.left
                leftMargin:     18
                verticalCenter: parent.verticalCenter
            }
            text:  label
            color: UI.Theme.textTertiary
            font.family: UI.Theme.fontFamily
            font.pixelSize: UI.Theme.fontSizeTiny
            font.weight: UI.Theme.fontWeightBold
            font.letterSpacing: 0
        }
    }

    // ── Item de navegação genérico ────────────────────────────────────────────
    component SidebarItem: Rectangle {
        id: sbItem
        property string icon
        property string label
        property string path
        property string action
        readonly property bool acceptsDrop: action === "" && path.indexOf("/") === 0

        readonly property bool active: action === "network"
            ? (AppState.currentPath === AppState.networkRootPath ||
               AppState.currentPath.indexOf(AppState.networkRootPath + "/") === 0)
            : AppState.currentPath === path

        width: parent ? parent.width - 16 : 192
        height: 32
        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
        radius: 0

        color: "transparent"
        readonly property color itemBg: active
            ? Qt.rgba(UI.Theme.accent.r, UI.Theme.accent.g, UI.Theme.accent.b, 0.12)
            : sidebarDropTarget.containsDrag ? Qt.rgba(UI.Theme.accent.r, UI.Theme.accent.g, UI.Theme.accent.b, 0.16)
            : itemHover.hovered ? (Theme.isLight ? Qt.rgba(0, 0, 0, 0.045) : Qt.rgba(1, 1, 1, 0.05)) : "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: sbItem.itemBg
            border.width: (sbItem.active || sidebarDropTarget.containsDrag || itemHover.hovered) ? 1 : 0
            border.color: sbItem.active
                ? Qt.rgba(UI.Theme.accent.r, UI.Theme.accent.g, UI.Theme.accent.b, 0.25)
                : sidebarDropTarget.containsDrag ? Qt.rgba(UI.Theme.accent.r, UI.Theme.accent.g, UI.Theme.accent.b, 0.45)
                : (Theme.isLight ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.05))

            Behavior on color { ColorAnimation { duration: UI.Theme.animationFast; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: UI.Theme.animationFast; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: 2
                height: sbItem.active ? parent.height * 0.5 : 0
                radius: 1.5
                color: UI.Theme.accent
                opacity: sbItem.active ? 1 : 0
                Behavior on height { NumberAnimation { duration: UI.Theme.animationNormal; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: UI.Theme.animationNormal } }
            }
        }

        RowLayout {
            anchors {
                left:           parent.left
                right:          parent.right
                leftMargin:     10
                rightMargin:    10
                verticalCenter: parent.verticalCenter
            }
            spacing: 9

            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                radius: 7
                color: sbItem.active
                    ? UI.Theme.accent
                    : itemHover.hovered ? (Theme.isLight ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.10))
                    : (Theme.isLight ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(1, 1, 1, 0.05))
                border.width: 1
                border.color: Theme.isLight
                    ? Qt.rgba(0, 0, 0, sbItem.active ? 0.08 : 0.05)
                    : Qt.rgba(1, 1, 1, sbItem.active ? 0.20 : 0.08)
                Behavior on color { ColorAnimation { duration: UI.Theme.animationFast; easing.type: Easing.OutCubic } }

                Image {
                    source: AppState.sidebarIconSource(sbItem.icon, 16)
                    width: 16; height: 16
                    anchors.centerIn: parent
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    sourceSize: Qt.size(16, 16)
                    opacity: sbItem.active ? 1.0 : 0.92
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 1.0
                        colorizationColor: sbItem.active ? root.sidebarIconActive
                            : itemHover.hovered ? root.sidebarIconHover
                            : root.sidebarIconIdle
                    }
                }
            }

            // Label
            Text {
                text:  sbItem.label
                color: sbItem.active
                    ? UI.Theme.textPrimary
                    : (itemHover.hovered ? UI.Theme.textPrimary : UI.Theme.textSecondary)
                font.family: UI.Theme.fontFamily
                font.pixelSize: UI.Theme.fontSizeNormal
                font.weight: sbItem.active ? UI.Theme.fontWeightDemiBold : UI.Theme.fontWeightMedium
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: UI.Theme.animationFast } }
            }
        }

        HoverHandler {
            id: itemHover
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            z: 1
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    mouse.accepted = true
                    root.openSidebarMenu(sbItem, mouse)
                }
            }
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton)
                    return
                if (sbItem.action === "network")
                    AppState.openNetworkBrowser()
                else
                    AppState.navigateTo(sbItem.path)
            }
        }

        DropArea {
            id: sidebarDropTarget
            anchors.fill: parent
            z: 0
            enabled: sbItem.acceptsDrop

            onDropped: function(drop) {
                if (drop.accepted)
                    return
                root.handleDroppedUrls(drop, sbItem.path)
            }
        }
    }

    // ── Item de dispositivo ───────────────────────────────────────────────────
    component DeviceSidebarItem: Rectangle {
        id: deviceItem
        property string icon
        property string label
        property string subtitle
        property string path
        property string deviceId
        property string devicePath
        property bool   mounted
        property bool   canMount
        property bool   canUnmount
        property bool   canRemount
        property bool   autoMount
        property bool   busy

        readonly property bool active: mounted && AppState.currentPath === path

        width: parent ? parent.width - 16 : 192
        height: 32
        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
        radius: 10

        color: active
            ? Qt.rgba(0.20, 0.48, 0.95, 0.22)
            : devHover.containsMouse ? Theme.hover : "transparent"

        border.width: active ? 1 : 0
        border.color: active ? Qt.rgba(0.55, 0.78, 1, 0.20) : "transparent"

        Behavior on color        { ColorAnimation { duration: 110 } }
        Behavior on border.color { ColorAnimation { duration: 110 } }

        Row {
            anchors {
                left:           parent.left
                right:          parent.right
                leftMargin:     10
                rightMargin:    10
                verticalCenter: parent.verticalCenter
            }
            spacing: 9

            Rectangle {
                width:  22
                height: 22
                radius: 7
                color: "transparent"
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    source: AppState.sidebarIconSource(deviceItem.icon, 16)
                    width: 16; height: 16
                    anchors.centerIn: parent
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    sourceSize: Qt.size(16, 16)
                    opacity: deviceItem.busy ? 0.40 : (deviceItem.active ? 1.0 : 0.88)
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 1.0
                        colorizationColor: deviceItem.active ? root.sidebarIconActive
                            : devHover.containsMouse ? root.sidebarIconHover
                            : root.sidebarIconIdle
                    }
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                }
            }

            Column {
                width: parent.width - 22 - parent.spacing - (deviceItem.active ? 10 : 0)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    width: parent.width
                    text:  deviceItem.label
                    color: deviceItem.active
                        ? Theme.text
                        : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.78)
                    font {
                        pixelSize: 13
                        weight: deviceItem.active ? Font.DemiBold : Font.Normal
                    }
                    elide: Text.ElideRight
                    opacity: deviceItem.busy ? 0.50 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                }
            }
        }

        MouseArea {
            id: devHover
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            enabled:     !busy
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    mouse.accepted = true
                    root.openDriveMenu(deviceItem, mouse)
                }
            }
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton)
                    return
                if (mounted)
                    AppState.navigateTo(deviceItem.path)
                else if (canMount)
                    AppState.requestMountDevice(deviceItem.devicePath, false, true)
            }
        }
    }
}
