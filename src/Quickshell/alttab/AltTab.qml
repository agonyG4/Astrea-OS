import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "../components"

ShellRoot {
    id: root

    HyprlandFocusGrab {
        id: focusGrab
        active: switcher.open
    }

    GlobalShortcut {
        name: "alt_tab_next"
        onPressed: switcher.step(1)
    }

    GlobalShortcut {
        name: "alt_tab_previous"
        onPressed: switcher.step(-1)
    }

    GlobalShortcut {
        name: "alt_tab_commit"
        onPressed: switcher.commit()
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: win
            required property var modelData

            screen: modelData
            visible: switcher.open && modelData === Quickshell.screens[0]
            color: "transparent"

            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true

            WlrLayershell.namespace: "astrea-alt-tab"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusiveZone: -1

            FocusScope {
                id: focusScope
                anchors.fill: parent
                focus: switcher.open
                activeFocusOnTab: true

                Keys.onEscapePressed: switcher.cancel()
                Keys.onReturnPressed: switcher.commit()
                Keys.onEnterPressed: switcher.commit()
                Keys.onRightPressed: switcher.step(1)
                Keys.onLeftPressed: switcher.step(-1)
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Alt || event.key === Qt.Key_AltGr) {
                        event.accepted = true
                        switcher.commit()
                    }
                }

                Component.onCompleted: if (switcher.open) forceActiveFocus()
                onVisibleChanged: if (visible) forceActiveFocus()

                MouseArea {
                    anchors.fill: parent
                    onClicked: switcher.cancel()
                }

                Rectangle {
                    id: panel
                    anchors.centerIn: parent
                    width: Math.min(Math.max(220, appRow.implicitWidth + 34), parent.width - 120)
                    height: 116
                    radius: 26
                    color: "#80323232"
                    border.color: "#30FFFFFF"
                    border.width: 1
                    clip: true

                    scale: switcher.open ? 1 : 0.96
                    opacity: switcher.open ? 1 : 0

                    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 90 } }

                    Row {
                        id: appRow
                        anchors.centerIn: parent
                        spacing: 12

                        Repeater {
                            model: switcher.clients

                            delegate: Rectangle {
                                required property int index
                                required property var modelData

                                width: 92
                                height: 92
                                radius: 22
                                color: index === switcher.currentIndex ? "#347DFF" : "transparent"
                                border.color: index === switcher.currentIndex ? "#88FFFFFF" : "transparent"
                                border.width: 1
                                scale: index === switcher.currentIndex ? 1.06 : 1.0

                                Behavior on color { ColorAnimation { duration: 90 } }
                                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                                AppIcon {
                                    anchors.centerIn: parent
                                    width: 74
                                    height: 74
                                    entry: modelData
                                    fallbackRadius: 18
                                    fallbackColor: "#24FFFFFF"
                                    fallbackFontSize: 27
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: switcher.preview(index)
                                    onClicked: switcher.commitIndex(index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    QtObject {
        id: switcher

        readonly property string fontFamily: "SF Pro Display"
        property bool open: false
        property int currentIndex: 0
        property var clients: []
        property int pendingDirection: 1

        function step(direction) {
            pendingDirection = direction

            if (!open) {
                openWithClients(direction)
                return
            }

            cycle(direction)
        }

        function openWithClients(direction) {
            clients = collectClients()

            if (clients.length === 0) {
                cancel()
                return
            }

            const activeAddress = Hyprland.activeToplevel ? Hyprland.activeToplevel.address : ""
            let activeIndex = clients.findIndex(client => client.address === activeAddress)
            if (activeIndex < 0) activeIndex = 0

            currentIndex = clients.length > 1
                ? (activeIndex + direction + clients.length) % clients.length
                : 0
            open = true
        }

        function cycle(direction) {
            if (clients.length === 0) return
            currentIndex = (currentIndex + direction + clients.length) % clients.length
        }

        function preview(index) {
            if (index < 0 || index >= clients.length) return
            currentIndex = index
        }

        function commitIndex(index) {
            if (index < 0 || index >= clients.length) return
            currentIndex = index
            commit()
        }

        function commit() {
            if (clients.length === 0 || currentIndex < 0 || currentIndex >= clients.length) {
                cancel()
                return
            }

            const client = clients[currentIndex]
            open = false
            clients = []

            if (client.workspaceId !== undefined && client.workspaceId !== null) {
                Hyprland.dispatch("workspace " + client.workspaceId)
            }
            Hyprland.dispatch("focuswindow address:" + focusAddress(client.address))
        }

        function cancel() {
            open = false
            clients = []
        }

        function collectClients() {
            Hyprland.refreshToplevels()

            let filtered = []
            const toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : []

            for (let toplevel of toplevels) {
                if (!toplevel) continue

                const ipc = toplevel.lastIpcObject || {}
                const workspace = toplevel.workspace || ipc.workspace || {}
                const address = toplevel.address || ipc.address || ""
                const appClass = ipc.class || ipc.initialClass || ""
                const title = toplevel.title || ipc.title || ipc.initialTitle || appClass || "App"
                const workspaceId = Number(workspace.id || 0)

                if (!address || ipc.hidden || workspaceId <= 0) continue

                filtered.push({
                    address: address,
                    className: appClass,
                    title: title,
                    name: displayNameFromMetadata(appClass, title),
                    workspaceId: workspaceId,
                    workspaceName: workspace.name || String(workspaceId),
                    focusHistoryID: Number(ipc.focusHistoryID || 999999),
                    icon: iconNameForClient(appClass, title)
                })
            }

            filtered.sort((a, b) => {
                if (a.focusHistoryID !== b.focusHistoryID) return a.focusHistoryID - b.focusHistoryID
                return (a.name || "").localeCompare(b.name || "")
            })
            return filtered
        }

        function focusAddress(address) {
            const text = String(address || "")
            return text.startsWith("0x") ? text : "0x" + text
        }

        function displayNameFromMetadata(className, title) {
            const cls = (className || "").trim()
            const windowTitle = (title || "").trim()
            if (cls.length > 0 && cls !== "org.quickshell") return titleCase(cls)
            return windowTitle || "App"
        }

        function iconNameForClient(className, title) {
            const cls = String(className || "").toLowerCase()
            const text = String(title || "").toLowerCase()

            if (cls.indexOf("zen") >= 0) return "zen-browser"
            if (cls.indexOf("kitty") >= 0) return "kitty"
            if (cls.indexOf("code") >= 0 || cls.indexOf("cursor") >= 0) return "visual-studio-code"
            if (cls.indexOf("spotify") >= 0) return "spotify"
            if (cls.indexOf("discord") >= 0) return "discord"
            if (cls.indexOf("steam") >= 0) return "steam"
            if (text.indexOf("finder") >= 0) return "folder"
            if (text.indexOf("settings") >= 0 || text.indexOf("configura") >= 0) return "preferences-system"
            if (text.indexOf("weather") >= 0 || text.indexOf("clima") >= 0) return "weather-clear"
            if (text.indexOf("screen") >= 0 && text.indexOf("time") >= 0) return "preferences-system-time"
            if (cls.indexOf("org.quickshell") >= 0) return "application-x-executable"
            return cls
        }

        function titleCase(text) {
            return (text || "App").replace(/[-_.]+/g, " ").replace(/\b\w/g, c => c.toUpperCase())
        }


    }
}
