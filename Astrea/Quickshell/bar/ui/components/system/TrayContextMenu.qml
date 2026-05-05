import Quickshell
import QtQuick
import "../astrea" as Astrea
import "../../.."

TopbarPopup {
    id: control

    property var trayItem: null
    property var trayMenu: null
    property real pendingAnchorX: screen.width / 2
    readonly property string trayTitle: trayItem ? (trayItem.tooltipTitle || trayItem.title || trayItem.id || "Tray item") : "Tray item"

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
            source: control.trayItem ? (control.trayItem.icon || "") : ""
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 28
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: control.trayTitle
            color: Theme.textActive
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
            width: parent.width
            active: true
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
                        : modelData.icon || ""
                    text: modelData.text || "Item"
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
        text: "No actions exposed"
        color: Theme.textSecondary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font {
            family: Theme.fontFamily
            pixelSize: Theme.fontSizeSmall
        }
    }
}
