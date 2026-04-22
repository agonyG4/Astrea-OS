import QtQuick 2.15
import Quickshell.Io

QtObject {
    id: navigation

    property QtObject app
    property string currentPath: ""
    property var history: []
    property int historyIdx: -1
    property var tabs: [{ id: 0, path: "/home/agony", history: ["/home/agony"], historyIdx: 0 }]
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
    property ListModel fileModel: ListModel {}
    property int fileModelRevision: 0
    property string _pendingParseMode: ""
    property WorkerScript jsonWorker: WorkerScript {
        id: jsonWorker
        source: "JsonWorker.js"
        onMessage: function(msg) {
            if (!msg.ok) {
                navigation.fileModel.clear()
                navigation.loadError = navigation._pendingParseMode === "search"
                    ? "Erro ao pesquisar" : "Erro ao carregar diretório"
                navigation.loadingDir = false
                app.previewsEnabled = false
                return
            }
            navigation.replaceFileModel(msg.items)
            navigation.loadError = ""
            navigation.loadingDir = false
            if (navigation.loadError === "")
                app.previewsEnabled = true
        }
    }

    function initialize() {
        var homePath = "/home/agony"
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
        var path = initialPath || currentPath || "/home/agony"
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
            breadcrumbParts = [{ label: "Recentes", path: app.recentVirtualPath }]
            return
        }

        var parts = currentPath.split("/").filter(Boolean)
        var result = []
        var acc = ""
        var startIndex = 0

        if (parts.length >= 2 && parts[0] === "home" && parts[1] === "agony") {
            result.push({ label: "Pasta pessoal", path: "/home/agony" })
            acc = "/home/agony"
            startIndex = 2
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

        if (searchActive) {
            submitSearch(searchQuery)
            return
        }

        if (app.isRecentPath(currentPath)) {
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
        fileModelRevision++
        fillTimer.restart()
    }

            function _fillChunk() {
        var chunk = _allItems.slice(_fillOffset, _fillOffset + 50)
        if (chunk.length === 0) { _allItems = []; return }
        fileModel.append(chunk)
        _fillOffset += 50
        if (_fillOffset < _allItems.length)
            fillTimer.restart()
        else
            _allItems = []
    }
    property Timer fillTimer: Timer {
        interval: 8
        repeat: false
        onTriggered: navigation._fillChunk()
    }

    function updateFileModelMetadata(items) {
        if (!items || items.length === 0 || fileModel.count === 0)
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
            if (!pattern || pattern === "*")
                return true
            if (pattern.indexOf("*.") === 0 && lowerName.lastIndexOf(pattern.slice(1)) === lowerName.length - (pattern.length - 1))
                return true
            if (pattern === lowerName)
                return true
        }

        return false
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
                    navigation.replaceFileModel(JSON.parse(this.text))
                    navigation.loadError = ""
                } catch (error) {
                    navigation.fileModel.clear()
                    navigation.loadError = "Erro ao carregar diretório"
                }
                navigation.loadingDir = false
                if (navigation.loadError === "")
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
                    navigation.replaceFileModel(JSON.parse(this.text))
                    navigation.loadError = ""
                } catch (error) {
                    navigation.fileModel.clear()
                    navigation.loadError = "Erro ao pesquisar"
                }
                navigation.loadingDir = false
                if (navigation.loadError === "")
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
}
