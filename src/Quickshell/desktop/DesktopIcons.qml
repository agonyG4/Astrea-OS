import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
// TODO(design-system): desktop temporarily imports the bar module only for Theme tokens;
// move Quickshell surfaces to a shared shell theme module before removing this dependency.
import "../bar"
import "AstreaFiles" as AstreaFiles

Item {
    id: root

    property var apps: []
    readonly property int cellWidth: iconPreset === "large" ? 118 : iconPreset === "small" ? 82 : 96
    readonly property int cellHeight: iconPreset === "large" ? 126 : iconPreset === "small" ? 88 : 104
    readonly property int iconSize: iconPreset === "large" ? 66 : iconPreset === "small" ? 42 : 52
    readonly property int highlightWidth: iconPreset === "large" ? 106 : iconPreset === "small" ? 74 : 86
    readonly property int highlightHeight: iconPreset === "large" ? 112 : iconPreset === "small" ? 78 : 92
    property string selectedDesktop: ""
    property var contextApp: null
    property bool contextIsBackground: true
    property string sortMode: "name"
    property string iconPreset: "medium"
    property bool iconsHidden: false
    property bool stateLoaded: false
    property var gridPositions: ({})
    property int layoutVersion: 0
    property string appLoadStatus: ""
    property string desktopSignature: ""
    readonly property string modulePath: localPath(Qt.resolvedUrl("."))
    readonly property string scriptPath: modulePath + "/app_index.py"
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
        var index = (path || "").lastIndexOf("/")
        return index > 0 ? path.slice(0, index) : path
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
                av = a.generic || ""
                bv = b.generic || ""
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

        gridPositions = next
        var sourceSlot = next[desktop] !== undefined ? next[desktop] : indexForDesktop(desktop)
        var owner = slotOwnerIn(next, targetSlot, desktop)

        if (swapWithOwner && owner !== "" && targetSlot !== sourceSlot) {
            next[desktop] = targetSlot
            next[owner] = sourceSlot
        } else {
            next[desktop] = nearestFreeSlot(targetSlot, desktop)
        }

        gridPositions = next
        normalizeGridPositions()
        layoutVersion += 1
        saveState()
    }

    function clearGridPositions() {
        gridPositions = ({})
        normalizeGridPositions()
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
        iconsHidden = hidden
        layoutVersion += 1
        saveState()
    }

    function normalizeGridPositions() {
        var items = orderedApps()
        var next = {}
        var used = {}

        for (var i = 0; i < items.length; i++) {
            var desktop = items[i].desktop
            if (!desktop)
                continue

            var desired = gridPositions[desktop] !== undefined ? Number(gridPositions[desktop]) : i
            if (!isFinite(desired) || desired < 0)
                desired = i

            var slot = Math.max(0, Math.round(desired))
            while (used[slot])
                slot += 1

            used[slot] = true
            next[desktop] = slot
        }

        gridPositions = next
    }

    function saveState() {
        saveStateDebounce.restart()
    }

    function refreshApps() {
        if (appLoadProcess.running)
            appLoadProcess.running = false
        appLoadStatus = "Atualizando..."
        appLoadProcess.command = ["python3", scriptPath, "--json", "--write"]
        appLoadProcess.running = true
    }

    function checkDesktopSignature() {
        if (!desktopSignatureProcess.running)
            desktopSignatureProcess.running = true
    }

    Timer {
        id: saveStateDebounce
        interval: 120
        repeat: false
        onTriggered: {
            stateSaveProcess.running = false
            stateSaveProcess.command = [
                "python3",
                "-c",
                "import pathlib,sys; p=pathlib.Path(sys.argv[1]); p.parent.mkdir(parents=True, exist_ok=True); p.write_text(sys.argv[2], encoding='utf-8')",
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
            "-c",
            "import pathlib,sys; paths=[pathlib.Path(p) for p in sys.argv[1:]]; print(next((p.read_text(encoding='utf-8') for p in paths if p.exists()), '{}'))",
            root.statePath,
            root.legacyStatePath
        ]
        running: false
        stdout: StdioCollector { id: stateLoadStdout }
        onExited: function(exitCode) {
            if (exitCode !== 0)
                return

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
            } catch (error) {
                root.stateLoaded = true
            }
        }
    }

    Process {
        id: appLoadProcess
        command: []
        running: false
        stdout: StdioCollector { id: appLoadStdout }
        onExited: function(exitCode) {
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
        refreshApps()
        checkDesktopSignature()
    }

    function launchDesktop(path) {
        if (!path)
            return

        launcher.running = false
        launcher.command = ["gio", "launch", path]
        launcher.running = true
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
        opener.command = ["gio", "open", path]
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
        deleteDesktopProcess.command = ["gio", "trash", path]
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

    Timer {
        id: desktopSignatureTimer
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.checkDesktopSignature()
    }

    Timer {
        id: refreshDebounce
        interval: 120
        repeat: false
        onTriggered: root.refreshApps()
    }

    Process {
        id: desktopSignatureProcess
        command: [
            "python3",
            "-c",
            "import os,json\nfrom pathlib import Path\ncfg=Path(os.environ.get('XDG_CONFIG_HOME', Path.home()/'.config'))/'user-dirs.dirs'\nd=Path.home()/'Desktop'\ntry:\n    for line in cfg.read_text(encoding='utf-8', errors='ignore').splitlines():\n        line=line.strip()\n        if line.startswith('XDG_DESKTOP_DIR='):\n            d=Path(os.path.expandvars(line.split('=',1)[1].strip().strip('\"').replace('$HOME', str(Path.home()))))\n            break\nexcept Exception:\n    pass\nitems=[]\nif d.exists():\n    for p in sorted(d.glob('*.desktop')):\n        try: items.append([p.name, p.stat().st_mtime_ns, p.stat().st_size])\n        except OSError: pass\nprint(json.dumps(items, ensure_ascii=False))"
        ]
        running: false
        stdout: StdioCollector { id: desktopSignatureStdout }
        onExited: function(exitCode) {
            if (exitCode !== 0)
                return

            var next = desktopSignatureStdout.text || ""
            if (root.desktopSignature === "") {
                root.desktopSignature = next
                return
            }

            if (next !== root.desktopSignature) {
                root.desktopSignature = next
                refreshDebounce.restart()
            }
        }
    }

    TextEdit {
        id: clipboardProxy
        visible: false

        function copyText(value) {
            text = value || ""
            forceActiveFocus()
            select(0, text.length)
            copy()
            text = ""
        }
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
                            desktopWindow.openContextAt(mouse.x + 6, mouse.y + 6, null, true)
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

                        delegate: Item {
                            id: tile
                            required property var modelData
                            readonly property var appData: modelData
                            readonly property int effectiveSlot: tile.appData && root.gridPositions[tile.appData.desktop] !== undefined
                                ? root.gridPositions[tile.appData.desktop]
                                : root.indexForDesktop(tile.appData ? tile.appData.desktop : "")
                            readonly property point targetPosition: desktopWindow.defaultPosition(effectiveSlot)

                            width: root.cellWidth
                            height: root.cellHeight
                            z: tile.dragging ? 20 : tile.selected ? 10 : 1

                            property bool dragging: false
                            property bool suppressClick: false
                            property real pressTileX: 0
                            property real pressTileY: 0
                            property real pressMouseX: 0
                            property real pressMouseY: 0
                            readonly property bool selected: tile.appData && root.selectedDesktop === tile.appData.desktop
                            readonly property bool hovered: tileHover.hovered

                            Binding {
                                target: tile
                                property: "x"
                                value: tile.targetPosition.x
                                when: !tile.dragging
                                restoreMode: Binding.RestoreNone
                            }

                            Binding {
                                target: tile
                                property: "y"
                                value: tile.targetPosition.y
                                when: !tile.dragging
                                restoreMode: Binding.RestoreNone
                            }

                            Behavior on x {
                                enabled: !tile.dragging
                                NumberAnimation { duration: Theme.animationQuick; easing.type: Easing.OutCubic }
                            }

                            Behavior on y {
                                enabled: !tile.dragging
                                NumberAnimation { duration: Theme.animationQuick; easing.type: Easing.OutCubic }
                            }

                            Connections {
                                target: contextHost
                                function onWidthChanged() { if (!tile.dragging) desktopWindow.clampTile(tile) }
                                function onHeightChanged() { if (!tile.dragging) desktopWindow.clampTile(tile) }
                            }

                            Rectangle {
                                id: hl
                                width: root.highlightWidth
                                height: root.highlightHeight
                                x: Math.round((parent.width - width) / 2)
                                y: 3
                                radius: Theme.cornerRadius
                                color: tile.selected ? "#3a3a3c" : tile.hovered ? "#2e2e30" : "transparent"

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animationInstant }
                                }
                            }

                            Image {
                                id: appIcon
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: hl.y + 8
                                width: root.iconSize
                                height: root.iconSize
                                source: tile.appData && tile.appData.icon ? "image://icon/" + tile.appData.icon : "image://icon/application-x-executable"
                                asynchronous: true
                                cache: true
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                            }
                            Text {
                                id: appLabel
                                anchors.top: appIcon.bottom
                                anchors.topMargin: Theme.spacingSmall
                                width: root.cellWidth + 20
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.appData ? tile.appData.name : ""
                                color: "#f8f8f8"
                                font.family: Theme.fontFamily
                                font.pixelSize: iconPreset === "large" ? 13 : iconPreset === "small" ? 12 : 12
                                font.weight: Font.Normal
                                font.hintingPreference: Font.PreferVerticalHinting
                                antialiasing: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignTop
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                style: Text.Raised
                                styleColor: "#99000000"
                            }

                            HoverHandler {
                                id: tileHover
                            }

                            MouseArea {
                                id: pointer
                                anchors.fill: parent
                                z: 1
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                propagateComposedEvents: false

                                function beginDrag() {
                                    if (tile.dragging || !tile.appData)
                                        return

                                    tile.dragging = true
                                    tile.suppressClick = true
                                    desktopWindow.closeContext()
                                }

                                function updateTileFromMouse(mouse) {
                                    const pt = pointer.mapToItem(contextHost, mouse.x, mouse.y)
                                    tile.x = tile.pressTileX + pt.x - tile.pressMouseX
                                    tile.y = tile.pressTileY + pt.y - tile.pressMouseY
                                    desktopWindow.clampTile(tile)
                                }

                                function finishDrag(mouse) {
                                    if (tile.dragging && tile.appData) {
                                        if (mouse)
                                            updateTileFromMouse(mouse)
                                        const center = appIcon.mapToItem(contextHost, appIcon.width / 2, appIcon.height / 2)
                                        const target = desktopWindow.dropTargetForPoint(center.x, center.y, tile.appData.desktop)
                                        root.setDesktopSlot(tile.appData.desktop, target.slot, target.swap)
                                    }

                                    tile.dragging = false
                                    desktopWindow.clampTile(tile)
                                }

                                onPressed: function(mouse) {
                                    if (tile.appData)
                                        root.selectedDesktop = tile.appData.desktop
                                    if (mouse.button === Qt.LeftButton) {
                                        const pt = pointer.mapToItem(contextHost, mouse.x, mouse.y)
                                        tile.pressTileX = tile.x
                                        tile.pressTileY = tile.y
                                        tile.pressMouseX = pt.x
                                        tile.pressMouseY = pt.y
                                        tile.suppressClick = false
                                    }
                                }

                                onPositionChanged: function(mouse) {
                                    if (!(pressedButtons & Qt.LeftButton))
                                        return

                                    const pt = pointer.mapToItem(contextHost, mouse.x, mouse.y)
                                    const dx = pt.x - tile.pressMouseX
                                    const dy = pt.y - tile.pressMouseY
                                    const threshold = 8

                                    if (!tile.dragging && Math.sqrt(dx * dx + dy * dy) >= threshold)
                                        beginDrag()

                                    if (tile.dragging)
                                        updateTileFromMouse(mouse)
                                }

                                onClicked: function(mouse) {
                                    mouse.accepted = true
                                    if (tile.suppressClick) {
                                        tile.suppressClick = false
                                        return
                                    }
                                    if (!tile.appData)
                                        return
                                    root.selectedDesktop = tile.appData.desktop
                                    if (mouse.button === Qt.RightButton) {
                                        const pt = pointer.mapToItem(contextHost, mouse.x, mouse.y)
                                        desktopWindow.openContextAt(pt.x + 6, pt.y + 6, tile.appData, false)
                                    } else {
                                        desktopWindow.closeContext()
                                    }
                                }

                                onDoubleClicked: function(mouse) {
                                    mouse.accepted = true
                                    if (!tile.appData)
                                        return
                                    root.selectedDesktop = tile.appData.desktop
                                    desktopWindow.closeContext()
                                    root.launchDesktop(tile.appData.desktop)
                                }

                                onReleased: function(mouse) {
                                    finishDrag(mouse)
                                }

                                onCanceled: {
                                    finishDrag(null)
                                    tile.suppressClick = false
                                }
                            }
                        }
                    }
                }

                AstreaFiles.FileContextMenu {
                    id: contextMenu
                    anchors.fill: parent
                    z: 1000
                    menuWidth: 216
                    menuOpen: menuVisible

                    property bool menuVisible: false

                    onMenuOpenChanged: menuVisible = menuOpen
                    onMenuVisibleChanged: {
                        if (menuVisible !== menuOpen)
                            menuOpen = menuVisible
                    }

                    AstreaFiles.ContextMenuAction {
                        label: "Abrir"
                        visible: !root.contextIsBackground
                        actionEnabled: root.contextApp !== null
                        onTriggered: {
                            root.launchDesktop(root.contextApp.desktop)
                            desktopWindow.closeContext()
                        }
                    }

                    AstreaFiles.ContextMenuAction {
                        label: "Copiar Nome"
                        visible: !root.contextIsBackground
                        actionEnabled: root.contextApp !== null
                        onTriggered: {
                            clipboardProxy.copyText(root.contextApp.name)
                            desktopWindow.closeContext()
                        }
                    }

                    AstreaFiles.ContextMenuAction {
                        label: "Copiar Caminho"
                        visible: !root.contextIsBackground
                        actionEnabled: root.contextApp !== null
                        onTriggered: {
                            clipboardProxy.copyText(root.contextApp.desktop)
                            desktopWindow.closeContext()
                        }
                    }

                    AstreaFiles.ContextMenuAction {
                        label: "Abrir Pasta"
                        visible: !root.contextIsBackground
                        actionEnabled: root.contextApp !== null
                        onTriggered: {
                            root.openPath(root.directoryForPath(root.contextApp.desktop))
                            desktopWindow.closeContext()
                        }
                    }

                    AstreaFiles.ContextMenuAction {
                        label: "Abrir Arquivo"
                        visible: !root.contextIsBackground
                        actionEnabled: root.contextApp !== null
                        onTriggered: {
                            root.openPath(root.contextApp.desktop)
                            desktopWindow.closeContext()
                        }
                    }

                    AstreaFiles.ContextMenuAction {
                        label: "Excluir da Area de Trabalho"
                        visible: !root.contextIsBackground
                        actionEnabled: root.contextApp !== null
                        onTriggered: {
                            root.deleteDesktopShortcut(root.contextApp.desktop)
                            desktopWindow.closeContext()
                        }
                    }

                    AstreaFiles.ContextMenuDivider {
                        visible: !root.contextIsBackground
                    }

                    AstreaFiles.ContextMenuAction {
                        label: root.iconsHidden ? "Mostrar Icones" : "Ocultar Icones"
                        visible: root.contextIsBackground
                        actionEnabled: true
                        onTriggered: {
                            root.setIconsHidden(!root.iconsHidden)
                            desktopWindow.closeContext()
                        }
                    }

                    AstreaFiles.ContextMenuAction {
                        label: "Atualizar Apps"
                        visible: root.contextIsBackground && !root.iconsHidden
                        actionEnabled: !appLoadProcess.running
                        onTriggered: {
                            root.refreshApps()
                            desktopWindow.closeContext()
                        }
                    }

                    AstreaFiles.ContextMenuDivider {
                        visible: root.contextIsBackground
                    }

                    AstreaFiles.ContextMenuAction {
                        label: "Ordenar por Nome"
                        visible: root.contextIsBackground && !root.iconsHidden
                        actionEnabled: root.sortMode !== "name"
                        onTriggered: {
                            root.setSortMode("name")
                            desktopWindow.closeContext()
                        }
                    }

                    AstreaFiles.ContextMenuAction {
                        label: "Ordenar por Tipo"
                        visible: root.contextIsBackground && !root.iconsHidden
                        actionEnabled: root.sortMode !== "kind"
                        onTriggered: {
                            root.setSortMode("kind")
                            desktopWindow.closeContext()
                        }
                    }

                    AstreaFiles.ContextMenuAction {
                        label: "Ordenar por Caminho"
                        visible: root.contextIsBackground && !root.iconsHidden
                        actionEnabled: root.sortMode !== "path"
                        onTriggered: {
                            root.setSortMode("path")
                            desktopWindow.closeContext()
                        }
                    }

                    AstreaFiles.ContextMenuDivider {
                        visible: root.contextIsBackground && !root.iconsHidden
                    }

                    AstreaFiles.ContextMenuAction {
                        label: "Icones Pequenos"
                        visible: root.contextIsBackground && !root.iconsHidden
                        actionEnabled: root.iconPreset !== "small"
                        onTriggered: {
                            root.setIconPreset("small")
                            desktopWindow.closeContext()
                        }
                    }

                    AstreaFiles.ContextMenuAction {
                        label: "Icones Medios"
                        visible: root.contextIsBackground && !root.iconsHidden
                        actionEnabled: root.iconPreset !== "medium"
                        onTriggered: {
                            root.setIconPreset("medium")
                            desktopWindow.closeContext()
                        }
                    }

                    AstreaFiles.ContextMenuAction {
                        label: "Icones Grandes"
                        visible: root.contextIsBackground && !root.iconsHidden
                        actionEnabled: root.iconPreset !== "large"
                        onTriggered: {
                            root.setIconPreset("large")
                            desktopWindow.closeContext()
                        }
                    }

                    AstreaFiles.ContextMenuDivider {
                        visible: root.contextIsBackground && !root.iconsHidden
                    }

                    AstreaFiles.ContextMenuAction {
                        label: "Reorganizar Grade"
                        visible: (root.contextIsBackground && !root.iconsHidden) || root.hasGridPositions()
                        actionEnabled: true
                        onTriggered: {
                            root.clearGridPositions()
                            desktopWindow.closeContext()
                        }
                    }

                    AstreaFiles.ContextMenuAction {
                        label: "Limpar Selecao"
                        actionEnabled: root.selectedDesktop !== ""
                        onTriggered: {
                            root.selectedDesktop = ""
                            desktopWindow.closeContext()
                        }
                    }
                }
            }
        }
    }
}
