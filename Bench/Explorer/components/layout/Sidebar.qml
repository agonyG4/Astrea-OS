import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.impl 2.15
import "/home/agony/.local/share/Astrea/Features/System/DragDropSupport.js" as DragDropSupport
import "../.."
import "../common" as Common
import "file:///home/agony/.local/share/Astrea/Features/System" as AstreaSystem

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

    function openDriveMenu(item, mouse) {
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

    function handleDroppedUrls(drop, destinationPath) {
        DragDropSupport.handleDroppedUrls(AppState, drop, destinationPath)
    }

    // ── Card flutuante principal ───────────────────────────────────────────────
    AstreaSystem.SidebarFrame {
        id: floatingCard
        anchors {
            fill:           parent
            topMargin:      10
            bottomMargin:   10
            leftMargin:     12
            rightMargin:    8
        }
        backgroundColor: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.96)
        washColor: Qt.rgba(1, 1, 1, 0.02)
        borderColor: Qt.rgba(1, 1, 1, 0.09)

        // ── Header ────────────────────────────────────────────────────
        Item {
            width:  parent.width - 28
            x:      14
            height: 36

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter:   parent.verticalCenter
                text:  "Finder"
                color: Theme.text
                font { pixelSize: 22; weight: Font.Bold; letterSpacing: -0.5 }
            }

            Rectangle {
                id: searchBtn
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width:  28
                height: 28
                radius: 9
                color:  searchHover.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.10)
                            : Qt.rgba(1, 1, 1, 0.04)

                Behavior on color { ColorAnimation { duration: 100 } }

                IconImage {
                    name: "system-search"
                    width: 14; height: 14
                    sourceSize: Qt.size(14, 14)
                    anchors.centerIn: parent
                    opacity: 0.55
                    visible: !AppState.isPortalDialog
                }

                Image {
                    source: AppState.portalIconSource("system-search", 16)
                    width: 14; height: 14
                    anchors.centerIn: parent
                    opacity: 0.70
                    visible: AppState.isPortalDialog
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
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

        Item { width: 1; height: 10 }

        // ── Pessoal ───────────────────────────────────────────────────
        SidebarSection { label: "PESSOAL" }
        SidebarItem { icon: "inode-directory";      label: "Pasta Pessoal"; path: "/home/agony" }
        SidebarItem { icon: "document-open-recent"; label: "Recentes";      path: AppState.recentVirtualPath }

        Item { width: 1; height: 4 }

        // ── Favoritos ─────────────────────────────────────────────────
        SidebarSection { label: "FAVORITOS" }
        Repeater {
            model: [
                { label: "Desktop",    icon: "user-desktop",      path: "/home/agony/Área de trabalho" },
                { label: "Documentos", icon: "folder-documents",  path: "/home/agony/Documentos" },
                { label: "Downloads",  icon: "folder-downloads",  path: "/home/agony/Downloads" },
                { label: "Imagens",    icon: "folder-pictures",   path: "/home/agony/Imagens" },
                { label: "Músicas",    icon: "folder-music",      path: "/home/agony/Músicas" },
                { label: "Vídeos",     icon: "folder-videos",     path: "/home/agony/Vídeos" },
                { label: "Público",    icon: "folder-publicshare",path: "/home/agony/Público" },
                { label: "Modelos",    icon: "folder-templates",  path: "/home/agony/Modelos" }
            ]
            SidebarItem { icon: modelData.icon; label: modelData.label; path: modelData.path }
        }

        Item { width: 1; height: 4 }

        // ── Dispositivos ──────────────────────────────────────────────
        SidebarSection { label: "DISPOSITIVOS" }
        SidebarItem { icon: "drive-harddisk"; label: "Sistema"; path: "/" }
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
            label:  "Rede"
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
        SidebarSection { label: "OUTRO" }
        SidebarItem {
            icon:  "user-trash"
            label: "Lixeira"
            path:  "/home/agony/.local/share/Trash/files"
        }

        Item { width: 1; height: 6 }
    }

    // ── Drive context-menu overlay (sem alteração de lógica) ──────────────────
    Item {
        id: driveMenuOverlay
        parent: root.parent ? root.parent : root
        x: 0; y: 0
        width:  parent ? parent.width  : 0
        height: parent ? parent.height : 0
        z: 999

        MouseArea {
            anchors.fill: parent
            enabled: root.driveMenuOpen
            onClicked: root.closeDriveMenu()
        }

        Common.ContextMenuPopup {
            id: driveMenuCard
            menuVisible: root.driveMenuOpen
            menuX:       root.driveMenuX
            menuY:       root.driveMenuY

            Common.ContextMenuAction {
                label: root.driveMenuMounted ? "Abrir" : "Montar"
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
                label: "Desmontar"
                actionEnabled: !root.driveMenuBusy && root.driveMenuMounted && root.driveMenuCanUnmount
                onTriggered: {
                    root.closeDriveMenu()
                    AppState.requestUnmountDevice(root.driveMenuDevicePath, root.driveMenuPath)
                }
            }

            Common.ContextMenuAction {
                label: "Remontar com nome"
                visible: root.driveMenuCanRemount
                actionEnabled: !root.driveMenuBusy && root.driveMenuCanRemount
                onTriggered: {
                    root.closeDriveMenu()
                    AppState.requestRemountDevice(root.driveMenuDevicePath, root.driveMenuPath, true)
                }
            }

            Common.ContextMenuDivider {}

            Common.ContextMenuAction {
                label: root.driveMenuAutoMount ? "Não montar sempre" : "Montar sempre"
                actionEnabled: !root.driveMenuBusy
                onTriggered: {
                    root.closeDriveMenu()
                    AppState.toggleDeviceAutoMount(root.driveMenuDeviceId)
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

        // Linha separadora discreta à esquerda do label
        Rectangle {
            anchors {
                left:           parent.left
                leftMargin:     14
                verticalCenter: parent.verticalCenter
            }
            width:  18
            height: 1
            color:  Qt.rgba(1, 1, 1, 0.10)
            visible: false   // opcional — descomente se quiser a linha
        }

        Text {
            anchors {
                left:           parent.left
                leftMargin:     14
                verticalCenter: parent.verticalCenter
            }
            text:  label
            color: Qt.rgba(Theme.textTer.r, Theme.textTer.g, Theme.textTer.b, 0.55)
            font { pixelSize: 10; weight: Font.Bold; letterSpacing: 1.4 }
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

        width:  parent ? parent.width - 16 : 192
        height: 32
        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
        radius: 10

        // Pill de fundo: ativo = azul suave, hover = branco ultra-sutil
        color: active
            ? Qt.rgba(0.20, 0.48, 0.95, 0.22)
            : sidebarDropTarget.containsDrag ? Qt.rgba(0.49, 0.72, 0.97, 0.18)
            : itemHover.hovered ? Qt.rgba(1, 1, 1, 0.055) : "transparent"

        border.width: (active || sidebarDropTarget.containsDrag) ? 1 : 0
        border.color: active
            ? Qt.rgba(0.55, 0.78, 1, 0.20)
            : sidebarDropTarget.containsDrag ? Qt.rgba(0.49, 0.72, 0.97, 0.45) : "transparent"

        Behavior on color       { ColorAnimation { duration: 110 } }
        Behavior on border.color{ ColorAnimation { duration: 110 } }

        Row {
            anchors {
                left:           parent.left
                right:          parent.right
                leftMargin:     10
                rightMargin:    10
                verticalCenter: parent.verticalCenter
            }
            spacing: 9

            // Ícone com fundo pill
            Rectangle {
                width:  22
                height: 22
                radius: 7
                color: active
                    ? Qt.rgba(1, 1, 1, 0.13)
                    : itemHover.hovered ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.05)
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color { ColorAnimation { duration: 110 } }

                Image {
                    source: AppState.portalIconSource(sbItem.icon, 16)
                    width: 14; height: 14
                    anchors.centerIn: parent
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    sourceSize: Qt.size(14, 14)
                    opacity: sbItem.active ? 0.98 : 0.74
                }
            }

            // Label
            Text {
                text:  sbItem.label
                color: sbItem.active
                    ? Theme.text
                    : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.78)
                font {
                    pixelSize: 13
                    weight: sbItem.active ? Font.DemiBold : Font.Normal
                }
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                // Reserva espaço para o dot indicador quando ativo
                width: parent.width - 22 - parent.spacing - (sbItem.active ? 10 : 0)
            }

            // Dot indicador de item ativo
            Rectangle {
                width:  5
                height: 5
                radius: 2.5
                color:  Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.85)
                visible: sbItem.active
                anchors.verticalCenter: parent.verticalCenter

                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
        }

        HoverHandler {
            id: itemHover
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            z: 1
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
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

        width:  parent ? parent.width - 16 : 192
        height: 32
        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
        radius: 10

        color: active
            ? Qt.rgba(0.20, 0.48, 0.95, 0.22)
            : devHover.containsMouse ? Qt.rgba(1, 1, 1, 0.055) : "transparent"

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
                color: active
                    ? Qt.rgba(1, 1, 1, 0.13)
                    : devHover.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.05)
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color { ColorAnimation { duration: 110 } }

                Image {
                    source: AppState.portalIconSource(deviceItem.icon, 16)
                    width: 14; height: 14
                    anchors.centerIn: parent
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    sourceSize: Qt.size(14, 14)
                    opacity: deviceItem.busy ? 0.40 : (deviceItem.active ? 0.98 : 0.70)
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
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    root.openDriveMenu(deviceItem, mouse)
                    return
                }
                if (mounted)
                    AppState.navigateTo(deviceItem.path)
                else if (canMount)
                    AppState.requestMountDevice(deviceItem.devicePath, false, true)
            }
        }
    }
}
