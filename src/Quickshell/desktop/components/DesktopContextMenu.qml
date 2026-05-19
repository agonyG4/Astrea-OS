import QtQuick
import "../AstreaFiles" as AstreaFiles
import "../../AstreaI18n" as AstreaI18n

AstreaFiles.FileContextMenu {
    id: menu

    property var desktopRoot: null
    property var desktopWindow: null
    property var clipboardProxy: null
    property bool appLoadRunning: false
    property bool createFolderRunning: false
    property bool menuVisible: false

    menuWidth: 216
    menuOpen: menuVisible

    onMenuOpenChanged: menuVisible = menuOpen
    onMenuVisibleChanged: {
        if (menuVisible !== menuOpen)
            menuOpen = menuVisible
    }

    AstreaFiles.ContextMenuAction {
        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.desktop.components.desktop_context_menu.label.abrir"]) || "Open")
        visible: !menu.desktopRoot.contextIsBackground
        actionEnabled: menu.desktopRoot.contextApp !== null
        onTriggered: {
            menu.desktopRoot.openDesktopItem(menu.desktopRoot.contextApp)
            menu.desktopWindow.closeContext()
        }
    }

    AstreaFiles.ContextMenuAction {
        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.desktop.components.desktop_context_menu.label.copiar_nome"]) || "Copy Name")
        visible: !menu.desktopRoot.contextIsBackground
        actionEnabled: menu.desktopRoot.contextApp !== null
        onTriggered: {
            menu.clipboardProxy.copyText(menu.desktopRoot.contextApp.name)
            menu.desktopWindow.closeContext()
        }
    }

    AstreaFiles.ContextMenuAction {
        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.desktop.components.desktop_context_menu.label.copiar_caminho"]) || "Copy Path")
        visible: !menu.desktopRoot.contextIsBackground
        actionEnabled: menu.desktopRoot.contextApp !== null
        onTriggered: {
            menu.clipboardProxy.copyText(menu.desktopRoot.contextApp.desktop)
            menu.desktopWindow.closeContext()
        }
    }

    AstreaFiles.ContextMenuAction {
        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.desktop.components.desktop_context_menu.label.abrir_pasta"]) || "Open Folder")
        visible: !menu.desktopRoot.contextIsBackground
        actionEnabled: menu.desktopRoot.contextApp !== null
        onTriggered: {
            menu.desktopRoot.openPath(menu.desktopRoot.directoryForPath(menu.desktopRoot.contextApp.desktop))
            menu.desktopWindow.closeContext()
        }
    }

    AstreaFiles.ContextMenuAction {
        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.desktop.components.desktop_context_menu.label.abrir_arquivo"]) || "Open File")
        visible: !menu.desktopRoot.contextIsBackground && menu.desktopRoot.contextApp !== null && menu.desktopRoot.contextApp.kind !== "folder"
        actionEnabled: menu.desktopRoot.contextApp !== null
        onTriggered: {
            menu.desktopRoot.openPath(menu.desktopRoot.contextApp.desktop)
            menu.desktopWindow.closeContext()
        }
    }

    AstreaFiles.ContextMenuAction {
        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.desktop.components.desktop_context_menu.label.excluir_da_area_de_trabalho"]) || "Remove from Desktop")
        visible: !menu.desktopRoot.contextIsBackground
        actionEnabled: menu.desktopRoot.contextApp !== null
        onTriggered: {
            menu.desktopRoot.deleteDesktopShortcut(menu.desktopRoot.contextApp.desktop)
            menu.desktopWindow.closeContext()
        }
    }

    AstreaFiles.ContextMenuDivider {
        visible: !menu.desktopRoot.contextIsBackground
    }

    AstreaFiles.ContextMenuAction {
        label: menu.desktopRoot.iconsHidden ? "Mostrar Icones" : "Ocultar Icones"
        visible: menu.desktopRoot.contextIsBackground
        actionEnabled: true
        onTriggered: {
            menu.desktopRoot.setIconsHidden(!menu.desktopRoot.iconsHidden)
            menu.desktopWindow.closeContext()
        }
    }

    AstreaFiles.ContextMenuAction {
        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.desktop.components.desktop_context_menu.label.atualizar_apps"]) || "Refresh Apps")
        visible: menu.desktopRoot.contextIsBackground && !menu.desktopRoot.iconsHidden
        actionEnabled: !menu.appLoadRunning
        onTriggered: {
            menu.desktopRoot.refreshApps()
            menu.desktopWindow.closeContext()
        }
    }

    AstreaFiles.ContextMenuDivider {
        visible: menu.desktopRoot.contextIsBackground
    }

    AstreaFiles.ContextMenuAction {
        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.desktop.components.desktop_context_menu.label.criar_pasta"]) || "Create Folder")
        visible: menu.desktopRoot.contextIsBackground
        actionEnabled: !menu.createFolderRunning
        onTriggered: {
            menu.desktopRoot.createDesktopFolder()
            menu.desktopWindow.closeContext()
        }
    }

    AstreaFiles.ContextMenuAction {
        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.desktop.components.desktop_context_menu.label.ordenar_por_nome"]) || "Sort by Name")
        visible: menu.desktopRoot.contextIsBackground && !menu.desktopRoot.iconsHidden
        actionEnabled: menu.desktopRoot.sortMode !== "name"
        onTriggered: {
            menu.desktopRoot.setSortMode("name")
            menu.desktopWindow.closeContext()
        }
    }

    AstreaFiles.ContextMenuAction {
        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.desktop.components.desktop_context_menu.label.ordenar_por_tipo"]) || "Sort by Kind")
        visible: menu.desktopRoot.contextIsBackground && !menu.desktopRoot.iconsHidden
        actionEnabled: menu.desktopRoot.sortMode !== "kind"
        onTriggered: {
            menu.desktopRoot.setSortMode("kind")
            menu.desktopWindow.closeContext()
        }
    }

    AstreaFiles.ContextMenuAction {
        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.desktop.components.desktop_context_menu.label.ordenar_por_caminho"]) || "Sort by Path")
        visible: menu.desktopRoot.contextIsBackground && !menu.desktopRoot.iconsHidden
        actionEnabled: menu.desktopRoot.sortMode !== "path"
        onTriggered: {
            menu.desktopRoot.setSortMode("path")
            menu.desktopWindow.closeContext()
        }
    }

    AstreaFiles.ContextMenuDivider {
        visible: menu.desktopRoot.contextIsBackground && !menu.desktopRoot.iconsHidden
    }

    AstreaFiles.ContextMenuAction {
        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.desktop.components.desktop_context_menu.label.icones_pequenos"]) || "Small Icons")
        visible: menu.desktopRoot.contextIsBackground && !menu.desktopRoot.iconsHidden
        actionEnabled: menu.desktopRoot.iconPreset !== "small"
        onTriggered: {
            menu.desktopRoot.setIconPreset("small")
            menu.desktopWindow.closeContext()
        }
    }

    AstreaFiles.ContextMenuAction {
        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.desktop.components.desktop_context_menu.label.icones_medios"]) || "Medium Icons")
        visible: menu.desktopRoot.contextIsBackground && !menu.desktopRoot.iconsHidden
        actionEnabled: menu.desktopRoot.iconPreset !== "medium"
        onTriggered: {
            menu.desktopRoot.setIconPreset("medium")
            menu.desktopWindow.closeContext()
        }
    }

    AstreaFiles.ContextMenuAction {
        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.desktop.components.desktop_context_menu.label.icones_grandes"]) || "Large Icons")
        visible: menu.desktopRoot.contextIsBackground && !menu.desktopRoot.iconsHidden
        actionEnabled: menu.desktopRoot.iconPreset !== "large"
        onTriggered: {
            menu.desktopRoot.setIconPreset("large")
            menu.desktopWindow.closeContext()
        }
    }

    AstreaFiles.ContextMenuDivider {
        visible: menu.desktopRoot.contextIsBackground && !menu.desktopRoot.iconsHidden
    }

    AstreaFiles.ContextMenuAction {
        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.desktop.components.desktop_context_menu.label.reorganizar_grade"]) || "Reorganize Grid")
        visible: (menu.desktopRoot.contextIsBackground && !menu.desktopRoot.iconsHidden) || menu.desktopRoot.hasGridPositions()
        actionEnabled: true
        onTriggered: {
            menu.desktopRoot.clearGridPositions()
            menu.desktopWindow.closeContext()
        }
    }

    AstreaFiles.ContextMenuAction {
        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.desktop.components.desktop_context_menu.label.limpar_selecao"]) || "Clear Selection")
        actionEnabled: menu.desktopRoot.selectedDesktop !== ""
        onTriggered: {
            menu.desktopRoot.selectedDesktop = ""
            menu.desktopWindow.closeContext()
        }
    }
}
