import QtQuick 2.15
import Quickshell
import Quickshell.Io
import "../AstreaI18n" as AstreaI18n

QtObject {
    id: navigation

    property QtObject app
    property string currentPath: ""
    property var history: []
    property int historyIdx: -1
    property var tabs: []
    property int activeTabIndex: 0
    property int nextTabId: 1
    property var breadcrumbParts: [{ label: "/", path: "/" }]
    property bool loadingDir: false
    property string loadError: ""
    property bool dialogActive: false
    property string dialogMode: "browse"
    property var dialogFilePatterns: []
    property string activeDirectoryRequestPath: ""
    property bool searchActive: false
    property bool searchVisible: false
    property string searchQuery: ""
    property string searchRootPath: ""
    property string activeRequestMode: "list"
    property bool remoteDirectoryActive: false
    property string remoteDirectoryReason: ""
    property ListModel fileModel: ListModel {}
    property int fileModelRevision: 0
    property bool fileModelFilling: false
    property string watchedDirectoryPath: ""

    function initialize() {
        var requestedPath = Quickshell.env("ASTREA_EXPLORER_START_PATH") || ""
        var homePath = requestedPath || app.homePath
        tabs = [{ id: 0, path: homePath, history: [homePath], historyIdx: 0 }]
        activeTabIndex = 0
        nextTabId = 1
        history = [homePath]
        historyIdx = 0
        currentPath = homePath
        rebuildBreadcrumbs()
        loadDirectory()
    }

    function _syncTabState() {
        var t = tabs.slice()
        if (activeTabIndex >= 0 && activeTabIndex < t.length) {
            t[activeTabIndex].path = currentPath
            t[activeTabIndex].history = history
            t[activeTabIndex].historyIdx = historyIdx
            tabs = t
        }
    }

    function createTab(initialPath) {
        var path = initialPath || currentPath || app.homePath
        var t = tabs.slice()
        t.push({ id: nextTabId++, path: path, history: [path], historyIdx: 0 })
        tabs = t
        switchTab(t.length - 1)
    }

    function closeTab(index) {
        if (tabs.length <= 1) return
        var t = tabs.slice()
        var wasActive = (index === activeTabIndex)
        t.splice(index, 1)
        tabs = t

        if (wasActive) {
            var newIdx = Math.min(index, t.length - 1)
            activeTabIndex = -1
            switchTab(newIdx)
        } else if (activeTabIndex > index) {
            activeTabIndex--
        }
    }

    function tabIndexById(tabId) {
        for (var i = 0; i < tabs.length; i++) {
            if (tabs[i].id === tabId)
                return i
        }
        return -1
    }

    function closeTabById(tabId) {
        closeTab(tabIndexById(tabId))
    }

    function switchTabById(tabId) {
        switchTab(tabIndexById(tabId))
    }

    function activeTabId() {
        if (activeTabIndex < 0 || activeTabIndex >= tabs.length)
            return -1
        return tabs[activeTabIndex].id
    }

    function moveTab(fromIndex, toIndex) {
        if (fromIndex < 0 || fromIndex >= tabs.length)
            return
        if (toIndex < 0)
            toIndex = 0
        if (toIndex >= tabs.length)
            toIndex = tabs.length - 1
        if (fromIndex === toIndex)
            return

        _syncTabState()

        var t = tabs.slice()
        var activeId = activeTabIndex >= 0 && activeTabIndex < t.length
            ? t[activeTabIndex].id : -1
        var moved = t.splice(fromIndex, 1)[0]
        t.splice(toIndex, 0, moved)
        tabs = t

        for (var i = 0; i < t.length; i++) {
            if (t[i].id === activeId) {
                activeTabIndex = i
                break
            }
        }
    }

    function switchTab(index) {
        if (index < 0 || index >= tabs.length || index === activeTabIndex) return
        _resetSearchState()
        activeTabIndex = index
        var t = tabs[index]
        history = t.history.slice()
        historyIdx = t.historyIdx
        currentPath = t.path
        app.clearSelection()
        loadDirectory()
    }

    function navigateTo(path) {
        if (path === currentPath && history.length > 0 && historyIdx !== -1) return
        _resetSearchState()
        var newHist = (history.length === 0 || historyIdx === -1) ? [] : history.slice(0, historyIdx + 1)
        newHist.push(path)
        history = newHist
        historyIdx = newHist.length - 1
        currentPath = path
        _syncTabState()
        app.clearSelection()
        loadDirectory()
    }

    function goBack() {
        if (historyIdx > 0)
            _jump(historyIdx - 1)
    }

    function goForward() {
        if (historyIdx < history.length - 1)
            _jump(historyIdx + 1)
    }

    function _jump(idx) {
        _resetSearchState()
        historyIdx = idx
        currentPath = history[idx]
        _syncTabState()
        app.clearSelection()
        loadDirectory()
    }

    function rebuildBreadcrumbs() {
        if (app.isRecentPath(currentPath)) {
            breadcrumbParts = [{ label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.state.navigation_state.label.recentes"]) || "Recents"), path: app.recentVirtualPath }]
            return
        }

        var parts = currentPath.split("/").filter(Boolean)
        var result = []
        var acc = ""
        var startIndex = 0

        if (app.homePath && currentPath.indexOf(app.homePath) === 0) {
            result.push({ label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.state.navigation_state.label.pasta_pessoal"]) || "Home folder"), path: app.homePath })
            acc = app.homePath
            var homeParts = app.homePath.split("/").filter(Boolean)
            startIndex = homeParts.length
        } else {
            result.push({ label: "/", path: "/" })
        }

        for (var i = startIndex; i < parts.length; i++) {
            acc += "/" + parts[i]
            result.push({ label: parts[i], path: acc })
        }
        breadcrumbParts = result
    }

    function pathComponents() {
        return breadcrumbParts
    }

    function refreshCurrentFolder() {
        if (!currentPath)
            return
        loadDirectory()
    }

    function stopDirectoryWatch() {
        watchedDirectoryPath = ""
        directoryWatchProcess.running = false
        directoryRefreshDebounce.stop()
    }

    function startDirectoryWatch(path) {
        if (!path || app.isRecentPath(path) || searchActive || remoteDirectoryActive || remotePathReason(path) !== "") {
            stopDirectoryWatch()
            return
        }
        if (watchedDirectoryPath === path && directoryWatchProcess.running)
            return
        watchedDirectoryPath = path
        directoryWatchProcess.running = false
        directoryWatchProcess.command = ["python3", app.helperPath, "monitor-dir", path]
        directoryWatchProcess.running = true
    }

    function _resetSearchState() {
        searchActive = false
        searchVisible = false
        searchQuery = ""
        searchRootPath = ""
    }

    function startSearch() {
        if (!currentPath)
            return
        searchRootPath = currentPath
        searchVisible = true
    }

    function hideSearch() {
        searchVisible = false
    }

    function submitSearch(query) {
        var trimmed = (query || "").trim()
        searchQuery = trimmed
        searchVisible = false

        if (trimmed === "") {
            if (searchActive) {
                searchActive = false
                searchRootPath = ""
                loadDirectory()
            }
            return
        }

        if (!searchRootPath)
            searchRootPath = currentPath

        searchActive = true
        updateRemoteStateFromItems([])
        stopDirectoryWatch()
        loadingDir = true
        loadError = ""
        app.previewsEnabled = false
        activeRequestMode = "search"
        activeDirectoryRequestPath = searchRootPath
        app.activePreviewRefreshPath = ""
        fileModel.clear()
        dirListProcess.running = false
        searchProcess.command = [
            app.backendPath,
            "search",
            searchRootPath,
            searchQuery,
            app.showHidden ? "1" : "0",
            app.sortField,
            app.sortAsc ? "1" : "0",
            app.foldersFirst ? "1" : "0"
        ]
        searchProcess.running = false
        searchProcess.running = true
    }

    function clearSearch() {
        if (!searchActive && !searchVisible)
            return
        searchActive = false
        searchVisible = false
        searchQuery = ""
        searchRootPath = ""
        loadDirectory()
    }

    function loadDirectory() {
        if (!currentPath)
            return

        updateRemoteStateFromItems([])

        if (searchActive) {
            stopDirectoryWatch()
            submitSearch(searchQuery)
            return
        }

        if (app.isRecentPath(currentPath)) {
            stopDirectoryWatch()
            remoteDirectoryActive = false
            remoteDirectoryReason = ""
            loadingDir = false
            loadError = ""
            app.previewsEnabled = true
            activeRequestMode = "recent"
            activeDirectoryRequestPath = currentPath
            app.activePreviewRefreshPath = ""
            replaceFileModel(app.recentModelItems())
            return
        }

        loadingDir = true
        loadError = ""
        app.previewsEnabled = false
        activeRequestMode = "list"
        activeDirectoryRequestPath = currentPath
        app.activePreviewRefreshPath = ""
        if (remoteDirectoryActive)
            stopDirectoryWatch()
        else
            startDirectoryWatch(currentPath)
        fileModel.clear()
        searchProcess.running = false
        dirListProcess.command = [
            app.backendPath,
            "list",
            activeDirectoryRequestPath,
            app.showHidden ? "1" : "0",
            app.sortField,
            app.sortAsc ? "1" : "0",
            app.foldersFirst ? "1" : "0"
        ]
        dirListProcess.running = false
        dirListProcess.running = true
    }

    property var _allItems: []
    property int _fillOffset: 0

    function replaceFileModel(items) {
        var filtered = []
        for (var i = 0; i < items.length; i++) {
            if (fileMatchesDialogFilter(items[i].fileName, items[i].fileIsDir))
                filtered.push(items[i])
        }
        fileModel.clear()
        _allItems = filtered
        _fillOffset = 0
        fileModelFilling = filtered.length > 0
        fileModelRevision++
        fillTimer.restart()
    }

    function _fillChunk() {
        var chunkSize = fileModel.count === 0 ? 160 : 240
        var chunk = _allItems.slice(_fillOffset, _fillOffset + chunkSize)
        if (chunk.length === 0) {
            _allItems = []
            fileModelFilling = false
            fileModelRevision++
            return
        }
        fileModel.append(chunk)
        _fillOffset += chunkSize
        if (_fillOffset < _allItems.length)
            fillTimer.restart()
        else {
            _allItems = []
            fileModelFilling = false
            fileModelRevision++
            if (loadError === "" && app.previewsEnabled && !remoteDirectoryActive && !app.isPortalDialog && !searchActive)
                app.warmCurrentDirectoryThumbnails()
        }
    }
    property Timer fillTimer: Timer {
        interval: 4
        repeat: false
        onTriggered: navigation._fillChunk()
    }

    function updateFileModelMetadata(items) {
        if (remoteDirectoryActive || !items || items.length === 0 || fileModel.count === 0)
            return

        var filtered = []
        for (var i = 0; i < items.length; i++) {
            if (fileMatchesDialogFilter(items[i].fileName, items[i].fileIsDir))
                filtered.push(items[i])
        }

        if (filtered.length !== fileModel.count) {
            replaceFileModel(items)
            return
        }

        var indexByPath = {}
        for (var j = 0; j < fileModel.count; j++)
            indexByPath[fileModel.get(j).filePath] = j

        for (var k = 0; k < filtered.length; k++) {
            var updated = filtered[k]
            var modelIndex = indexByPath[updated.filePath]
            if (modelIndex === undefined) {
                replaceFileModel(items)
                return
            }

            fileModel.setProperty(modelIndex, "filePreviewUrl", updated.filePreviewUrl)
            fileModel.setProperty(modelIndex, "fileKind", updated.fileKind)
            fileModel.setProperty(modelIndex, "fileSize", updated.fileSize)
            fileModel.setProperty(modelIndex, "fileModified", updated.fileModified)
        }
        fileModelRevision++
    }

    function removePathsFromFileModel(paths) {
        if (!paths || paths.length === 0)
            return

        var removeSet = {}
        for (var i = 0; i < paths.length; i++) {
            if (paths[i])
                removeSet[paths[i]] = true
        }

        var changed = false
        for (var j = fileModel.count - 1; j >= 0; j--) {
            var item = fileModel.get(j)
            if (removeSet[item.filePath]) {
                fileModel.remove(j, 1)
                changed = true
            }
        }

        if (_allItems && _allItems.length > 0) {
            var kept = []
            for (var k = 0; k < _allItems.length; k++) {
                var pendingItem = _allItems[k]
                if (!removeSet[pendingItem.filePath])
                    kept.push(pendingItem)
            }
            _allItems = kept
        }

        if (changed)
            fileModelRevision++
    }

    function selectedItem() {
        if (!app.selectedFile)
            return null

        for (var i = 0; i < fileModel.count; i++) {
            var item = fileModel.get(i)
            if (item.fileName === app.selectedFile)
                return item
        }

        return null
    }

    function fileMatchesDialogFilter(fileName, isDir) {
        if (!dialogActive)
            return true
        if (dialogMode === "select_folder")
            return isDir
        if (isDir)
            return true
        if (!dialogFilePatterns || dialogFilePatterns.length === 0)
            return true

        var lowerName = (fileName || "").toLowerCase()
        for (var i = 0; i < dialogFilePatterns.length; i++) {
            var pattern = (dialogFilePatterns[i] || "").toLowerCase()
            pattern = pattern.replace(/\[([a-z0-9])\1\]/g, "$1")
            if (!pattern || pattern === "*")
                return true
            if (pattern.indexOf("*.") === 0 && lowerName.lastIndexOf(pattern.slice(1)) === lowerName.length - (pattern.length - 1))
                return true
            if (pattern === lowerName)
                return true
        }

        return false
    }

    function normalizedPath(path) {
        var text = String(path || "")
        if (text.length > 1)
            text = text.replace(/\/+$/, "")
        return text
    }

    function pathHasPrefix(path, prefix) {
        var cleanPath = normalizedPath(path)
        var cleanPrefix = normalizedPath(prefix)
        return cleanPath === cleanPrefix || cleanPath.indexOf(cleanPrefix + "/") === 0
    }

    function remotePathReason(path) {
        var cleanPath = normalizedPath(path)
        if (!cleanPath || app.isRecentPath(cleanPath))
            return ""

        var networkRoot = normalizedPath(app.networkRootPath || "")
        if (networkRoot && pathHasPrefix(cleanPath, networkRoot))
            return "gvfs"

        var prefixes = String(Quickshell.env("ASTREA_EXPLORER_REMOTE_PREFIXES") || "").split(":")
        for (var i = 0; i < prefixes.length; i++) {
            var prefix = normalizedPath(prefixes[i])
            if (prefix && pathHasPrefix(cleanPath, prefix))
                return "remote-prefix"
        }

        var parts = cleanPath.toLowerCase().split("/")
        for (var j = 0; j < parts.length; j++) {
            if (parts[j] === "rclone" || parts[j].indexOf("rclone-") === 0 || parts[j].indexOf("rclone_") === 0)
                return "rclone"
        }

        return ""
    }

    function updateRemoteStateFromItems(items) {
        var reason = remotePathReason(currentPath)
        var active = reason !== ""

        for (var i = 0; items && i < items.length; i++) {
            var item = items[i]
            if (item && item.fileRemote) {
                active = true
                reason = item.fileFilesystem || reason || "remote"
                break
            }
        }

        remoteDirectoryActive = active
        remoteDirectoryReason = active ? reason : ""
        if (remoteDirectoryActive) {
            app.previewsEnabled = false
            stopDirectoryWatch()
        }
    }

    property Process dirListProcess: Process {
        id: dirListProcess
        command: []
        running: false
        stdout: StdioCollector {
            id: dirListStdout
            onStreamFinished: {
                if (navigation.activeRequestMode !== "list" || navigation.activeDirectoryRequestPath !== navigation.currentPath)
                    return

                try {
                    var items = JSON.parse(this.text)
                    navigation.updateRemoteStateFromItems(items)
                    navigation.replaceFileModel(items)
                    navigation.loadError = ""
                } catch (error) {
                    navigation.fileModel.clear()
                    navigation.loadError = "Erro ao carregar diretório"
                }
                navigation.loadingDir = false
                if (navigation.loadError === "" && !navigation.remoteDirectoryActive)
                    app.previewsEnabled = true
                // if (navigation.loadError === "" && app.previewsEnabled && !app.isPortalDialog && !navigation.searchActive)
                    // app.warmCurrentDirectoryThumbnails()
            }
        }
        onExited: function(exitCode) {
            if (navigation.activeRequestMode !== "list")
                return
            if (exitCode !== 0 && dirListStdout.text.trim() === "") {
                navigation.fileModel.clear()
                navigation.loadError = "Erro ao carregar diretório"
                navigation.loadingDir = false
                app.previewsEnabled = false
            }
        }
    }

    property Process searchProcess: Process {
        id: searchProcess
        command: []
        running: false
        stdout: StdioCollector {
            id: searchStdout
            onStreamFinished: {
                if (navigation.activeRequestMode !== "search" || !navigation.searchActive || navigation.searchRootPath !== navigation.currentPath)
                    return

                try {
                    var items = JSON.parse(this.text)
                    navigation.updateRemoteStateFromItems(items)
                    navigation.replaceFileModel(items)
                    navigation.loadError = ""
                } catch (error) {
                    navigation.fileModel.clear()
                    navigation.loadError = "Erro ao pesquisar"
                }
                navigation.loadingDir = false
                if (navigation.loadError === "" && !navigation.remoteDirectoryActive)
                    app.previewsEnabled = true
                // if (navigation.loadError === "" && app.previewsEnabled && !app.isPortalDialog && !navigation.searchActive)
                    // app.warmCurrentDirectoryThumbnails()
            }
        }
        onExited: function(exitCode) {
            if (navigation.activeRequestMode !== "search")
                return
            if (exitCode !== 0 && searchStdout.text.trim() === "") {
                navigation.fileModel.clear()
                navigation.loadError = "Erro ao pesquisar"
                navigation.loadingDir = false
                app.previewsEnabled = false
            }
        }
    }

    property Timer directoryRefreshDebounce: Timer {
        interval: 260
        repeat: false
        onTriggered: {
            if (!navigation.currentPath
                    || navigation.currentPath !== navigation.watchedDirectoryPath
                    || navigation.searchActive
                    || navigation.remoteDirectoryActive
                    || app.isRecentPath(navigation.currentPath))
                return
            if (navigation.loadingDir) {
                restart()
                return
            }
            navigation.loadDirectory()
        }
    }

    property Process directoryWatchProcess: Process {
        command: []
        running: false
        stdout: SplitParser {
            onRead: line => {
                if (line.trim() === "changed")
                    navigation.directoryRefreshDebounce.restart()
            }
        }
        onExited: function() {
            if (navigation.watchedDirectoryPath === navigation.currentPath
                    && !navigation.searchActive
                    && !navigation.remoteDirectoryActive
                    && !app.isRecentPath(navigation.currentPath))
                directoryWatchRestartTimer.restart()
        }
    }

    property Timer directoryWatchRestartTimer: Timer {
        interval: 1000
        repeat: false
        onTriggered: {
            if (navigation.currentPath
                    && navigation.watchedDirectoryPath === navigation.currentPath
                    && !navigation.directoryWatchProcess.running
                    && !navigation.searchActive
                    && !navigation.remoteDirectoryActive
                    && !app.isRecentPath(navigation.currentPath))
                navigation.startDirectoryWatch(navigation.currentPath)
        }
    }
}
