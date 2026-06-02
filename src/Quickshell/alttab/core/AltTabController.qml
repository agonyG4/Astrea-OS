import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Item {
    id: root

    property bool open: false
    property int currentIndex: 0
    property var clients: []
    property int pendingDirection: 1
    property int pendingOpenOffset: 0
    property bool loadingClients: false
    property bool openRequestActive: false
    property bool commitAfterLoad: false
    property var resolvedIconCache: ({})
    readonly property string iconResolverScript:
        (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Core/bridge/system/app_icons.py"

    Component.onCompleted: iconPrewarmTimer.restart()

    GlobalShortcut {
        name: "alt_tab_next"
        onPressed: root.step(1)
    }

    GlobalShortcut {
        name: "alt_tab_previous"
        onPressed: root.step(-1)
    }

    GlobalShortcut {
        name: "alt_tab_commit"
        onPressed: root.commit()
    }

    function step(direction) {
        pendingDirection = direction

        if (!open) {
            openWithClients(direction)
            return
        }

        cycle(direction)
    }

    function openWithClients(direction) {
        if (clientRefreshProc.running) {
            if (openRequestActive)
                pendingOpenOffset += direction
            else {
                pendingOpenOffset = direction
                openRequestActive = true
            }
            return
        }

        pendingOpenOffset = direction
        loadingClients = true
        openRequestActive = true
        clientRefreshProc.running = true
    }

    function finishOpenWithClients(collectedClients) {
        clients = collectedClients

        if (clients.length === 0) {
            cancel()
            return
        }

        const activeAddress = Hyprland.activeToplevel ? Hyprland.activeToplevel.address : ""
        let activeIndex = clients.findIndex(client => client.focusHistoryID === 0)
        if (activeIndex < 0)
            activeIndex = clients.findIndex(client => client.address === activeAddress)
        if (activeIndex < 0) activeIndex = 0

        currentIndex = clients.length > 1
            ? (activeIndex + pendingOpenOffset + clients.length) % clients.length
            : 0
        pendingOpenOffset = 0
        openRequestActive = false
        open = true
        refreshDeepIconsIfNeeded()

        if (commitAfterLoad) {
            commitAfterLoad = false
            commit()
        }
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
        if (loadingClients || openRequestActive) {
            commitAfterLoad = true
            return
        }

        if (clients.length === 0 || currentIndex < 0 || currentIndex >= clients.length) {
            cancel()
            return
        }

        const client = clients[currentIndex]
        open = false
        clients = []

        if (client.workspaceId !== undefined && client.workspaceId !== null)
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + client.workspaceId + " })")
        Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + focusAddress(client.address) + "\" })")
    }

    function clientNeedsDeepIcon(client) {
        const text = String([
            client.className || "",
            client.initialClass || "",
            client.title || "",
            client.initialTitle || ""
        ].join(" ")).toLowerCase()
        return text.indexOf(".exe") >= 0
            || text.indexOf("wine") >= 0
            || text.indexOf("proton") >= 0
            || text.indexOf("pressure-vessel") >= 0
            || text.indexOf("steam_app_") >= 0
    }

    function iconCacheKeys(address, pid, className, title, initialClass, initialTitle) {
        let keys = []
        const addr = String(address || "")
        const pidText = String(pid || "")
        if (addr.length > 0)
            keys.push("address:" + addr)
        if (pidText.length > 0 && Number(pidText) > 0)
            keys.push("pid:" + pidText)
        keys.push("meta:" + [
            className || "",
            initialClass || "",
            title || "",
            initialTitle || ""
        ].join("|").toLowerCase())
        return keys
    }

    function cachedIconForClient(address, pid, className, title, initialClass, initialTitle) {
        const keys = iconCacheKeys(address, pid, className, title, initialClass, initialTitle)
        for (let key of keys) {
            const cached = resolvedIconCache[key]
            if (cached && (cached.icon || cached.astreaIcon || cached.astreaIconName))
                return cached
        }
        return null
    }

    function resolvedIconForClient(address, pid, className, title, initialClass, initialTitle, astreaIcon, astreaIconName) {
        if (astreaIcon || astreaIconName)
            return astreaIcon || astreaIconName

        const cached = cachedIconForClient(address, pid, className, title, initialClass, initialTitle)
        if (cached)
            return cached.astreaIcon || cached.astreaIconName || cached.icon || ""

        const candidate = {
            className: className || "",
            initialClass: initialClass || "",
            title: title || "",
            initialTitle: initialTitle || ""
        }
        if (clientNeedsDeepIcon(candidate))
            return ""

        return iconNameForClient(className, title)
    }

    function iconMetadataForClient(ipc, appClass, title) {
        const cached = cachedIconForClient(ipc.address || "", Number(ipc.pid || 0), appClass, title, ipc.initialClass || "", ipc.initialTitle || "")
        return {
            astreaIcon: ipc.astreaIcon || (cached ? cached.astreaIcon || "" : ""),
            astreaIconName: ipc.astreaIconName || (cached ? cached.astreaIconName || "" : "")
        }
    }

    function cacheResolvedIcons(resolvedClients) {
        let changed = false
        let nextCache = Object.assign({}, resolvedIconCache)
        for (let client of resolvedClients) {
            if (!client)
                continue
            const icon = client.astreaIcon || client.astreaIconName || client.icon || ""
            if (!icon)
                continue

            const cached = {
                icon: icon,
                astreaIcon: client.astreaIcon || "",
                astreaIconName: client.astreaIconName || ""
            }
            const keys = iconCacheKeys(client.address || "", client.pid || "", client.className || client.class || "", client.title || "", client.initialClass || "", client.initialTitle || "")
            for (let key of keys) {
                if (!nextCache[key] || nextCache[key].icon !== cached.icon) {
                    nextCache[key] = cached
                    changed = true
                }
            }
        }
        if (changed)
            resolvedIconCache = nextCache
    }

    function refreshDeepIconsIfNeeded() {
        if (!open || iconRefreshProc.running)
            return
        for (let client of clients) {
            if (clientNeedsDeepIcon(client) && !client.astreaIcon && !client.astreaIconName && !client.icon) {
                iconRefreshProc.running = true
                return
            }
        }
    }

    function mergeResolvedIcons(resolvedClients) {
        if (!Array.isArray(resolvedClients) || resolvedClients.length === 0)
            return

        cacheResolvedIcons(resolvedClients)

        if (!open)
            return

        let byAddress = ({})
        for (let client of resolvedClients) {
            if (client && client.address)
                byAddress[client.address] = client
        }

        let changed = false
        let nextClients = []
        for (let client of clients) {
            const resolved = byAddress[client.address]
            if (resolved && resolved.icon && resolved.icon !== client.icon) {
                let next = Object.assign({}, client)
                next.icon = resolved.icon
                next.astreaIcon = resolved.astreaIcon || ""
                next.astreaIconName = resolved.astreaIconName || ""
                nextClients.push(next)
                changed = true
            } else {
                nextClients.push(client)
            }
        }
        if (changed)
            clients = nextClients
    }

    function cancel() {
        open = false
        clients = []
        pendingOpenOffset = 0
        loadingClients = false
        openRequestActive = false
        commitAfterLoad = false
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

            const iconMeta = iconMetadataForClient(ipc, appClass, title)
            const icon = resolvedIconForClient(address, Number(ipc.pid || 0), appClass, title, ipc.initialClass || "", ipc.initialTitle || "", iconMeta.astreaIcon, iconMeta.astreaIconName)
            const needsDeepIcon = clientNeedsDeepIcon({
                className: appClass,
                initialClass: ipc.initialClass || "",
                title: title,
                initialTitle: ipc.initialTitle || ""
            })

            filtered.push({
                address: address,
                className: appClass,
                initialClass: ipc.initialClass || "",
                title: title,
                initialTitle: ipc.initialTitle || "",
                name: displayNameFromMetadata(appClass, title),
                pid: Number(ipc.pid || 0),
                workspaceId: workspaceId,
                workspaceName: workspace.name || String(workspaceId),
                focusHistoryID: Number(ipc.focusHistoryID || 999999),
                icon: icon,
                astreaIcon: iconMeta.astreaIcon,
                astreaIconName: iconMeta.astreaIconName,
                hideIconFallback: needsDeepIcon && !icon
            })
        }

        filtered.sort((a, b) => {
            if (a.focusHistoryID !== b.focusHistoryID) return a.focusHistoryID - b.focusHistoryID
            return (a.name || "").localeCompare(b.name || "")
        })
        return filtered
    }

    function collectClientsFromHyprctl(payload) {
        let parsed = []
        try {
            parsed = JSON.parse(payload || "[]")
        } catch (error) {
            return collectClients()
        }

        if (!Array.isArray(parsed)) return collectClients()

        let filtered = []
        for (let ipc of parsed) {
            if (!ipc) continue

            const workspace = ipc.workspace || {}
            const address = ipc.address || ""
            const appClass = ipc.class || ipc.initialClass || ""
            const title = ipc.title || ipc.initialTitle || appClass || "App"
            const workspaceId = Number(workspace.id || 0)

            if (!address || ipc.hidden || workspaceId <= 0) continue

            const iconMeta = iconMetadataForClient(ipc, appClass, title)
            const icon = resolvedIconForClient(address, Number(ipc.pid || 0), appClass, title, ipc.initialClass || "", ipc.initialTitle || "", iconMeta.astreaIcon, iconMeta.astreaIconName)
            const needsDeepIcon = clientNeedsDeepIcon({
                className: appClass,
                initialClass: ipc.initialClass || "",
                title: title,
                initialTitle: ipc.initialTitle || ""
            })

            filtered.push({
                address: address,
                className: appClass,
                initialClass: ipc.initialClass || "",
                title: title,
                initialTitle: ipc.initialTitle || "",
                name: displayNameFromMetadata(appClass, title),
                pid: Number(ipc.pid || 0),
                workspaceId: workspaceId,
                workspaceName: workspace.name || String(workspaceId),
                focusHistoryID: Number(ipc.focusHistoryID || 999999),
                icon: icon,
                astreaIcon: iconMeta.astreaIcon,
                astreaIconName: iconMeta.astreaIconName,
                hideIconFallback: needsDeepIcon && !icon
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
        if (cls.toLowerCase().indexOf("steam_app_") === 0 && windowTitle.length > 0)
            return windowTitle
        if (cls.length > 0 && cls !== "org.quickshell") return titleCase(cls)
        return windowTitle || "App"
    }

    function iconNameForClient(className, title) {
        const rawClass = String(className || "").trim()
        const cls = String(className || "").toLowerCase()
        const text = String(title || "").toLowerCase()

        if (cls === "org.vinegarhq.sober") return "org.vinegarhq.Sober"
        if (cls.indexOf("zen") >= 0) return "zen-browser"
        if (cls.indexOf("kitty") >= 0) return "kitty"
        if (cls.indexOf("code") >= 0 || cls.indexOf("cursor") >= 0) return "visual-studio-code"
        if (cls.indexOf("spotify") >= 0) return "spotify"
        if (cls.indexOf("discord") >= 0) return "discord"
        const steamGame = cls.match(/^steam_app_(\d+)$/)
        if (steamGame) return "steam_icon_" + steamGame[1]
        if (cls === "steam_app_default") return ""
        if (cls.indexOf("steam") >= 0) return "steam"
        const desktopIcon = desktopIconForClient(cls, text)
        if (desktopIcon.length > 0) return desktopIcon
        if (text.indexOf("finder") >= 0) return "folder"
        if (text.indexOf("settings") >= 0 || text.indexOf("configura") >= 0) return "preferences-system"
        if (text.indexOf("weather") >= 0 || text.indexOf("clima") >= 0) return "weather-clear"
        if (text.indexOf("screen") >= 0 && text.indexOf("time") >= 0) return "preferences-system-time"
        if (cls.indexOf("org.quickshell") >= 0) return "application-x-executable"
        return rawClass.indexOf(".") >= 0 ? "" : cls
    }

    function desktopIconForClient(className, title) {
        if (typeof DesktopEntries === "undefined") return ""
        const apps = DesktopEntries.applications ? DesktopEntries.applications.values : []
        let bestIcon = ""
        let bestScore = 0

        for (let entry of apps) {
            if (!entry || entry.noDisplay || !entry.icon) continue
            const entryName = String(entry.name || "").toLowerCase()
            const entryId = String(entry.id || entry.desktopId || entry.fileName || "").toLowerCase()
            const entryExec = String(entry.exec || entry.execString || "").toLowerCase()
            const hay = entryName + " " + entryId + " " + entryExec
            let score = 0

            if (className.length > 0 && (hay.indexOf(className) >= 0 || hay.indexOf(className.replace("-bin", "")) >= 0))
                score = 3
            if (title.length > 0 && entryName.length > 0 && (title.indexOf(entryName) >= 0 || entryName.indexOf(title) >= 0))
                score = Math.max(score, className === "org.quickshell" ? 4 : 2)
            if (title.length > 0 && entryName === title)
                score = Math.max(score, 6)
            if (score > 0 && entryId.indexOf("astrea-") >= 0)
                score += 1

            if (score > bestScore) {
                bestScore = score
                bestIcon = entry.icon
            }
        }
        return bestIcon
    }

    function titleCase(text) {
        return (text || "App").replace(/[-_.]+/g, " ").replace(/\b\w/g, c => c.toUpperCase())
    }

    Process {
        id: clientRefreshProc
        command: ["hyprctl", "clients", "-j"]
        running: false
        stdout: StdioCollector { id: clientRefreshOut }
        onExited: function(exitCode) {
            const collectedClients = exitCode === 0 ? root.collectClientsFromHyprctl(clientRefreshOut.text) : root.collectClients()
            root.loadingClients = false
            if (!root.openRequestActive)
                return
            root.finishOpenWithClients(collectedClients)
        }
    }

    Process {
        id: iconRefreshProc
        command: ["python3", root.iconResolverScript, "hypr-clients"]
        running: false
        stdout: StdioCollector { id: iconRefreshOut }
        onExited: function(exitCode) {
            if (exitCode !== 0)
                return
            root.mergeResolvedIcons(root.collectClientsFromHyprctl(iconRefreshOut.text))
        }
    }

    Timer {
        id: iconPrewarmTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (!iconRefreshProc.running)
                iconRefreshProc.running = true
        }
    }
}
