import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
// TODO(design-system): desktop temporarily imports the bar module only for Theme tokens;
// move Quickshell surfaces to a shared shell theme module before removing this dependency.
import "../bar"
import "./components" as DesktopComponents

Item {
    id: root

    property var apps: []
    readonly property int cellWidth: iconPreset === "large" ? 118 : iconPreset === "small" ? 82 : 96
    readonly property int cellHeight: iconPreset === "large" ? 126 : iconPreset === "small" ? 88 : 104
    readonly property int iconSize: iconPreset === "large" ? 66 : iconPreset === "small" ? 42 : 52
    readonly property int highlightWidth: iconPreset === "large" ? 106 : iconPreset === "small" ? 74 : 86
    readonly property int highlightHeight: iconPreset === "large" ? 112 : iconPreset === "small" ? 78 : 92
    readonly property int labelWidth: iconPreset === "large" ? 110 : iconPreset === "small" ? 78 : 92
    readonly property int labelHeight: iconPreset === "large" ? 38 : iconPreset === "small" ? 30 : 34
    property string selectedDesktop: ""
    property var contextApp: null
    property bool contextIsBackground: true
    property string sortMode: "name"
    property string iconPreset: "medium"
    property bool iconsHidden: false
    property bool performancePaused: false
    property bool stateLoaded: false
    property var gridPositions: ({})
    property int layoutVersion: 0
    property string appLoadStatus: ""
    property string desktopSignature: ""
    readonly property string modulePath: localPath(Qt.resolvedUrl("."))
    readonly property string scriptPath: modulePath + "/app_index.py"
    readonly property string homePath: Quickshell.env("HOME") || ""
    readonly property string astreaRoot: (Quickshell.env("ASTREA_ROOT") || (homePath + "/.local/share/Astrea")) + ""
    readonly property string astreaLaunch: astreaRoot + "/bin/astrea-launch"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/Astrea/desktop-icons"
    readonly property string statePath: stateDir + "/state.json"
    readonly property string legacyStatePath: modulePath + "/state.json"

    function localPath(url) {
        var path = decodeURIComponent(String(url))
        if (path.indexOf("file://") === 0)
            path = path.slice(7)
        if (path.length > 1 && path.endsWith("/"))
            path = path.slice(0, -1)
        return path
    }

    function directoryForPath(path) {
        path = expandHomePath(path)
        var index = (path || "").lastIndexOf("/")
        return index > 0 ? path.slice(0, index) : path
    }

    function expandHomePath(path) {
        if (!path)
            return path
        if (path === "$HOME")
            return homePath
        if (path.indexOf("$HOME/") === 0)
            return homePath + "/" + path.slice(6)
        return path
    }

    function sortedApps() {
        var items = apps.slice()
        items.sort(function(a, b) {
            var av = ""
            var bv = ""

            if (sortMode === "path") {
                av = a.desktop || ""
                bv = b.desktop || ""
            } else if (sortMode === "kind") {
                av = a.kind || a.generic || ""
                bv = b.kind || b.generic || ""
            } else {
                av = a.name || ""
                bv = b.name || ""
            }

            var cmp = av.localeCompare(bv, Qt.locale().name, { sensitivity: "base" })
            if (cmp !== 0)
                return cmp
            return (a.name || "").localeCompare(b.name || "", Qt.locale().name, { sensitivity: "base" })
        })
        return items
    }

    function orderedApps() {
        return sortedApps()
    }

    function visibleApps() {
        return iconsHidden ? [] : orderedApps()
    }

    function indexForDesktop(desktop) {
        var items = orderedApps()
        for (var i = 0; i < items.length; i++) {
            if (items[i].desktop === desktop)
                return i
        }
        return 0
    }

    function hasGridPositions() {
        for (var key in gridPositions)
            return true
        return false
    }

    function slotOwner(slot, exceptDesktop) {
        var items = orderedApps()

        for (var i = 0; i < items.length; i++) {
            var desktop = items[i].desktop
            var itemSlot = gridPositions[desktop] !== undefined ? gridPositions[desktop] : i
            if (desktop !== exceptDesktop && itemSlot === slot)
                return desktop
        }

        for (var key in gridPositions) {
            if (key !== exceptDesktop && gridPositions[key] === slot)
                return key
        }
        return ""
    }

    function occupiedSlot(slot, exceptDesktop) {
        return slotOwner(slot, exceptDesktop) !== ""
    }

    function slotOwnerIn(positions, slot, exceptDesktop) {
        for (var key in positions) {
            if (key !== exceptDesktop && positions[key] === slot)
                return key
        }
        return ""
    }

    function occupiedSlotIn(positions, slot, exceptDesktop) {
        return slotOwnerIn(positions, slot, exceptDesktop) !== ""
    }

    function nearestFreeSlotIn(positions, preferredSlot, exceptDesktop) {
        var maxSlots = orderedApps().length + 80
        var start = Math.max(0, preferredSlot)

        for (var distance = 0; distance < maxSlots; distance++) {
            var forward = start + distance
            if (!occupiedSlotIn(positions, forward, exceptDesktop))
                return forward

            var backward = start - distance
            if (backward >= 0 && !occupiedSlotIn(positions, backward, exceptDesktop))
                return backward
        }

        return start
    }

    function currentGridPositions() {
        var next = {}
        var items = orderedApps()

        for (var i = 0; i < items.length; i++) {
            var itemDesktop = items[i].desktop
            if (itemDesktop)
                next[itemDesktop] = gridPositions[itemDesktop] !== undefined ? gridPositions[itemDesktop] : i
        }

        for (var key in gridPositions) {
            if (next[key] === undefined)
                next[key] = gridPositions[key]
        }

        return next
    }

    function defaultGridPositions() {
        var next = {}
        var items = orderedApps()

        for (var i = 0; i < items.length; i++) {
            var desktop = items[i].desktop
            if (desktop)
                next[desktop] = i
        }

        return next
    }

    function normalizedPositions(positions) {
        var items = orderedApps()
        var next = {}
        var used = {}

        for (var i = 0; i < items.length; i++) {
            var desktop = items[i].desktop
            if (!desktop)
                continue

            var desired = positions[desktop] !== undefined ? Number(positions[desktop]) : i
            if (!isFinite(desired) || desired < 0)
                desired = i

            var slot = Math.max(0, Math.round(desired))
            while (used[slot])
                slot += 1

            used[slot] = true
            next[desktop] = slot
        }

        return next
    }

    function nearestFreeSlot(preferredSlot, exceptDesktop) {
        var maxSlots = orderedApps().length + 80
        var start = Math.max(0, preferredSlot)

        for (var distance = 0; distance < maxSlots; distance++) {
            var forward = start + distance
            if (!occupiedSlot(forward, exceptDesktop))
                return forward

            var backward = start - distance
            if (backward >= 0 && !occupiedSlot(backward, exceptDesktop))
                return backward
        }

        return start
    }

    function setDesktopSlot(desktop, slot, swapWithOwner) {
        if (!desktop)
            return

        var targetSlot = Math.max(0, Math.round(Number(slot) || 0))
        var next = currentGridPositions()
        var sourceSlot = next[desktop] !== undefined ? next[desktop] : indexForDesktop(desktop)
        var owner = slotOwnerIn(next, targetSlot, desktop)

        if (swapWithOwner && owner !== "" && targetSlot !== sourceSlot) {
            next[desktop] = targetSlot
            next[owner] = sourceSlot
        } else {
            next[desktop] = nearestFreeSlotIn(next, targetSlot, desktop)
        }

        gridPositions = normalizedPositions(next)
        layoutVersion += 1
        saveState()
    }

    function clearGridPositions() {
        gridPositions = defaultGridPositions()
        layoutVersion += 1
        saveState()
    }

    function setSortMode(mode) {
        sortMode = mode
        clearGridPositions()
    }

    function setIconPreset(preset) {
        iconPreset = preset
        clearGridPositions()
    }

    function setIconsHidden(hidden) {
        if (iconsHidden === hidden)
            return

        iconsHidden = hidden
        saveState()
    }

    function stopDesktopIconWork() {
        refreshDebounce.stop()
        if (appLoadProcess.running)
            appLoadProcess.running = false
        if (desktopSignatureProbe.running)
            desktopSignatureProbe.running = false
    }

    function unloadDesktopIcons() {
        stopDesktopIconWork()
        apps = []
        desktopSignature = ""
        selectedDesktop = ""
        contextApp = null
        appLoadStatus = "Oculto"
        layoutVersion += 1
    }

    function loadDesktopIconsIfVisible() {
        if (!stateLoaded || iconsHidden || performancePaused)
            return

        refreshApps()
        refreshDesktopSignature()
    }

    function normalizeGridPositions() {
        gridPositions = normalizedPositions(gridPositions)
    }

    function saveState() {
        saveStateDebounce.restart()
    }

    function refreshApps() {
        if (iconsHidden) {
            unloadDesktopIcons()
            return
        }

        if (appLoadProcess.running)
            appLoadProcess.running = false
        appLoadStatus = "Atualizando..."
        appLoadProcess.command = ["python3", scriptPath, "--json", "--write"]
        appLoadProcess.running = true
    }

    function applyDesktopSignature(next) {
        if (iconsHidden)
            return
        if (!next)
            return

        if (root.desktopSignature === "") {
            root.desktopSignature = next
            return
        }

        if (next !== root.desktopSignature) {
            root.desktopSignature = next
            refreshDebounce.restart()
        }
    }

    function refreshDesktopSignature() {
        if (performancePaused || iconsHidden)
            return
        if (!desktopSignatureProbe.running)
            desktopSignatureProbe.running = true
    }

    Timer {
        id: saveStateDebounce
        interval: 120
        repeat: false
        onTriggered: {
            stateSaveProcess.running = false
            stateSaveProcess.command = [
                "python3",
                root.scriptPath,
                "--save-state",
                root.statePath,
                JSON.stringify({
                    "sortMode": root.sortMode,
                    "iconPreset": root.iconPreset,
                    "positions": root.gridPositions,
                    "iconsHidden": root.iconsHidden
                })
            ]
            stateSaveProcess.running = true
        }
    }

    Process {
        id: stateSaveProcess
        command: []
        running: false
    }

    Process {
        id: stateLoadProcess
        command: [
            "python3",
            root.scriptPath,
            "--load-state",
            root.statePath,
            root.legacyStatePath
        ]
        running: false
        stdout: StdioCollector { id: stateLoadStdout }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.stateLoaded = true
                root.loadDesktopIconsIfVisible()
                return
            }

            try {
                var state = JSON.parse(stateLoadStdout.text || "{}")
                if (state.sortMode)
                    root.sortMode = state.sortMode
                if (state.iconPreset)
                    root.iconPreset = state.iconPreset
                root.iconsHidden = state.iconsHidden === true
                if (state.positions) {
                    var next = {}
                    for (var key in state.positions) {
                        var pos = state.positions[key]
                        if (typeof pos === "number")
                            next[key] = pos
                        else if (pos && pos.slot !== undefined)
                            next[key] = pos.slot
                    }
                    root.gridPositions = next
                }
                root.stateLoaded = true
                root.normalizeGridPositions()
                root.layoutVersion += 1
                if (root.iconsHidden)
                    root.unloadDesktopIcons()
                else
                    root.loadDesktopIconsIfVisible()
            } catch (error) {
                root.stateLoaded = true
                root.loadDesktopIconsIfVisible()
            }
        }
    }

    Process {
        id: appLoadProcess
        command: []
        running: false
        stdout: StdioCollector { id: appLoadStdout }
        onExited: function(exitCode) {
            if (root.iconsHidden) {
                root.unloadDesktopIcons()
                return
            }

            if (exitCode !== 0) {
                root.appLoadStatus = "Falha ao atualizar"
                return
            }

            try {
                var parsed = JSON.parse(appLoadStdout.text || "[]")
                root.apps = Array.isArray(parsed) ? parsed : []
                if (root.stateLoaded)
                    root.normalizeGridPositions()
                root.layoutVersion += 1
                root.appLoadStatus = root.apps.length + " apps"
            } catch (error) {
                root.appLoadStatus = "Lista invalida"
            }
        }
    }

    Component.onCompleted: {
        stateLoadProcess.running = true
    }

    function launchDesktop(path) {
        if (!path)
            return

        launcher.running = false
        launcher.command = [astreaLaunch, "--desktop", expandHomePath(path)]
        launcher.running = true
    }

    function openDesktopItem(item) {
        if (!item || !item.desktop)
            return
        if (item.kind === "folder")
            openPath(item.desktop)
        else
            launchDesktop(item.desktop)
    }

    Process {
        id: launcher
        command: []
        running: false
        onExited: function() {
            running = false
        }
    }

    function openPath(path) {
        if (!path)
            return

        opener.running = false
        opener.command = [astreaLaunch, "--file", expandHomePath(path)]
        opener.running = true
    }

    Process {
        id: opener
        command: []
        running: false
        onExited: function() {
            running = false
        }
    }

    function deleteDesktopShortcut(path) {
        if (!path)
            return

        deleteDesktopProcess.running = false
        deleteDesktopProcess.command = ["gio", "trash", expandHomePath(path)]
        deleteDesktopProcess.running = true
    }

    Process {
        id: deleteDesktopProcess
        command: []
        running: false
        onExited: function() {
            running = false
            root.selectedDesktop = ""
            root.contextApp = null
            root.refreshApps()
        }
    }

    function createDesktopFolder() {
        createFolderProcess.running = false
        createFolderProcess.command = ["python3", scriptPath, "--create-folder"]
        createFolderProcess.running = true
    }

    Process {
        id: createFolderProcess
        command: []
        running: false
        onExited: function(exitCode) {
            running = false
            if (exitCode === 0)
                root.refreshApps()
        }
    }

    Timer {
        id: refreshDebounce
        interval: 120
        repeat: false
        onTriggered: root.refreshApps()
    }

    Process {
        id: desktopSignatureProbe
        command: ["python3", root.scriptPath, "--signature"]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.applyDesktopSignature(data.trim())
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.stateLoaded && !root.performancePaused && !root.iconsHidden
        onTriggered: root.refreshDesktopSignature()
    }

    onPerformancePausedChanged: {
        if (!performancePaused)
            loadDesktopIconsIfVisible()
        else
            stopDesktopIconWork()
    }

    onIconsHiddenChanged: {
        if (iconsHidden)
            unloadDesktopIcons()
        else
            loadDesktopIconsIfVisible()
    }

    DesktopComponents.ClipboardProxy {
        id: clipboardProxy
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: desktopWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            visible: true

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            WlrLayershell.namespace: "astrea-desktop-icons"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            function openContextAt(x, y, app, background) {
                root.contextApp = app
                root.contextIsBackground = background
                contextMenu.openAt(x, y)
            }

            function closeContext() {
                contextMenu.menuVisible = false
            }

            function defaultPosition(index) {
                var left = 8
                var top = 58
                var bottom = 6
                var slot = Math.max(0, Number(index) || 0)
                var usableHeight = Math.max(root.cellHeight, contextHost.height - top - bottom)
                var rows = Math.max(1, Math.ceil(usableHeight / root.cellHeight))
                var rowStep = rows > 1 ? (usableHeight - root.cellHeight) / (rows - 1) : root.cellHeight
                var col = Math.floor(slot / rows)
                var row = slot % rows
                return Qt.point(left + col * root.cellWidth, top + Math.round(row * rowStep))
            }

            function slotIndexFor(x, y) {
                var left = 8
                var top = 58
                var bottom = 6
                var usableHeight = Math.max(root.cellHeight, contextHost.height - top - bottom)
                var rows = Math.max(1, Math.ceil(usableHeight / root.cellHeight))
                var rowStep = rows > 1 ? (usableHeight - root.cellHeight) / (rows - 1) : root.cellHeight
                var col = Math.max(0, Math.floor((x - left) / root.cellWidth))
                var row = Math.max(0, Math.floor((y - top) / rowStep))
                row = Math.min(row, rows - 1)
                return col * rows + row
            }

            function pointInsideSlotHitbox(slot, x, y) {
                var pos = defaultPosition(slot)
                var side = root.iconSize
                var centerX = pos.x + root.cellWidth / 2
                var centerY = pos.y + 3 + 8 + root.iconSize / 2

                return Math.abs(x - centerX) <= side / 2
                    && Math.abs(y - centerY) <= side / 2
            }

            function occupiedHitboxSlotForPoint(x, y, exceptDesktop) {
                var items = root.orderedApps()

                for (var i = 0; i < items.length; i++) {
                    var desktop = items[i].desktop
                    if (!desktop || desktop === exceptDesktop)
                        continue

                    var slot = root.gridPositions[desktop] !== undefined ? root.gridPositions[desktop] : i
                    if (pointInsideSlotHitbox(slot, x, y))
                        return slot
                }

                return -1
            }

            function dropTargetForPoint(x, y, desktop) {
                var hitSlot = occupiedHitboxSlotForPoint(x, y, desktop)
                if (hitSlot >= 0)
                    return { slot: hitSlot, swap: true }

                return { slot: slotIndexFor(x, y), swap: false }
            }

            function clampTile(tile) {
                tile.x = Math.max(0, Math.min(tile.x, contextHost.width - tile.width))
                tile.y = Math.max(48, Math.min(tile.y, contextHost.height - tile.height))
            }

            Rectangle {
                id: contextHost
                anchors.fill: parent
                color: "transparent"

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            if (contextMenu.menuVisible) {
                                desktopWindow.closeContext()
                                return
                            }

                            root.selectedDesktop = ""
                            desktopWindow.openContextAt(mouse.x, mouse.y, null, true)
                        } else if (mouse.button === Qt.LeftButton) {
                            root.selectedDesktop = ""
                            desktopWindow.closeContext()
                        }
                    }
                }

                Item {
                    id: iconLayer
                    anchors.fill: parent

                    Repeater {
                        id: iconRepeater
                        model: {
                            root.layoutVersion
                            contextHost.width
                            contextHost.height
                            return root.visibleApps()
                        }

                        delegate: DesktopComponents.DesktopIconTile {
                            entry: modelData
                            desktopState: root
                            hostWindow: desktopWindow
                            hostItem: contextHost
                        }
                    }
                }

                DesktopComponents.DesktopContextMenu {
                    id: contextMenu
                    anchors.fill: parent
                    z: 1000
                    desktopRoot: root
                    desktopWindow: desktopWindow
                    clipboardProxy: clipboardProxy
                    appLoadRunning: appLoadProcess.running
                    createFolderRunning: createFolderProcess.running
                }
            }
        }
    }
}
