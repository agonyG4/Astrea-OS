import Quickshell
import QtQuick
import "../../astrea" as Astrea
import "../../../.."
import "../popups" as PopupComponents
import "../../../../../AstreaI18n" as AstreaI18n
import "TrayIcon.js" as TrayIcon

PopupComponents.TopbarPopup {
    id: control

    property var trayItem: null
    property var trayMenu: null
    property real pendingAnchorX: screen.width / 2
    readonly property string trayTitle: trayItem ? (trayItem.tooltipTitle || trayItem.title || trayItem.id || "Tray item") : "Tray item"

    function menuEntryText(entry) {
        const text = entry && entry.text ? String(entry.text) : ""
        if (text.indexOf("image://") === 0 || text.indexOf("file://") === 0)
            return ""
        return text.replace(/_/g, "")
    }

    function menuEntryIcon(entry) {
        if (!entry || !entry.icon)
            return ""
        return TrayIcon.source(String(entry.icon))
    }

    popupWidth: 220
    cardPadding: 12
    contentSpacing: 4
    closeOnOutsideClick: true

    function openFor(item, x) {
        close()
        trayItem = item
        trayMenu = item && item.menu ? item.menu : null
        pendingAnchorX = x

        if (trayMenu) {
            opener.menu = trayMenu
        } else {
            opener.menu = null
        }
        openDelay.restart()
    }

    onShownChanged: {
        if (!shown && trayMenu && trayMenu.sendClosed)
            trayMenu.sendClosed()
    }

    Timer {
        id: openDelay
        interval: 80
        repeat: false
        onTriggered: {
            control.showAt(control.pendingAnchorX)
        }
    }

    QsMenuOpener {
        id: opener
    }

    Item {
        width: parent.width
        height: 28

        Image {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            sourceSize: Qt.size(width, height)
            source: TrayIcon.source(control.trayItem ? (control.trayItem.icon || "") : "")
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 28
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: control.trayTitle
            color: Theme.shellTextActive
            elide: Text.ElideRight
            font {
                family: Theme.fontFamily
                pixelSize: Theme.fontSizeBody
                weight: Font.DemiBold
            }
        }
    }

    Astrea.MenuSeparator {
        visible: control.trayMenu !== null
    }

    Repeater {
        model: control.trayMenu !== null ? opener.children : null

        delegate: Loader {
            readonly property string entryText: control.menuEntryText(modelData)
            readonly property bool entryRenderable: modelData.isSeparator || entryText !== "" || modelData.hasChildren

            width: parent.width
            height: entryRenderable && item ? item.height : 0
            visible: entryRenderable
            active: entryRenderable
            sourceComponent: modelData.isSeparator ? separatorComponent : itemComponent

            Component {
                id: separatorComponent
                Astrea.MenuSeparator {}
            }

            Component {
                id: itemComponent

                Astrea.MenuItem {
                    id: menuItem

                    readonly property bool checked: modelData.checkState === Qt.Checked
                    readonly property bool partiallyChecked: modelData.checkState === Qt.PartiallyChecked

                    icon: modelData.hasChildren ? "󰅂"
                        : checked ? "󰄲"
                        : partiallyChecked ? "󰡖"
                        : control.menuEntryIcon(modelData)
                    text: control.menuEntryText(modelData)
                    opacity: modelData.enabled ? 1.0 : 0.45

                    onClicked: {
                        if (!modelData.enabled)
                            return

                        if (modelData.hasChildren) {
                            const win = menuItem.QsWindow.window
                            if (win) {
                                const point = menuItem.mapToGlobal(menuItem.width, menuItem.height / 2)
                                modelData.display(win, point.x, point.y)
                            }
                            return
                        }

                        modelData.triggered()

                        control.close()
                    }
                }
            }
        }
    }

    Text {
        visible: control.trayMenu === null
        width: parent.width
        height: 32
        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.system.tray.tray_context_menu.text.no_actions_exposed"]) || "No actions exposed")
        color: Theme.shellTextSecondary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font {
            family: Theme.fontFamily
            pixelSize: Theme.fontSizeSmall
        }
    }
}
