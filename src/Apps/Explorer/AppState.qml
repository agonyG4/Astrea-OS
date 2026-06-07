pragma Singleton
import Quickshell
import QtQuick 2.15
import QtQml 2.15
import QtCore
import "state" as StateModules

QtObject {
    id: state

    readonly property bool isPortalDialog: (Quickshell.env("ASTREA_FILE_DIALOG_OPTIONS") || Quickshell.env("BENCH_FILE_DIALOG_OPTIONS") || "") !== ""
    readonly property string homePath: Quickshell.env("HOME") || ""
    readonly property string backendPath: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Core/bridge/apps/explorer_backend"
    readonly property string helperPath: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Apps/Explorer/explorer_helper.py"
    readonly property string wallpaperManagerPath: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Core/bridge/wallpaper/wallpaper_manager.py"
    readonly property string astreaLaunch: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/bin/astrea-launch"
    readonly property string windowsRun: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/System/scripts/astrea-windows-run"
    readonly property string networkRootPath: (Quickshell.env("XDG_RUNTIME_DIR") || ("/run/user/" + Quickshell.env("UID"))) + "/gvfs"
    readonly property string trashFilesPath: homePath + "/.local/share/Trash/files"
    readonly property string trashInfoPath: homePath + "/.local/share/Trash/info"
    readonly property string recentVirtualPath: "recent://"
    readonly property real minZoom: 0.75
    readonly property real maxZoom: 2.0
    readonly property real thumbnailZoomThreshold: 1.15
    readonly property var thumbnailColumnStops: [18, 14, 10, 7, 5, 4, 3]
    readonly property var thumbnailScaleStops: [1.0, 1.08, 1.16, 1.26, 1.38, 1.65, 2.0]
    readonly property color themeSelected: Theme.selected
    readonly property color themeHover: Theme.hover
    property var scrollPositions: ({})

    property string sortField: "name"
    property bool sortAsc: true
    property bool showHidden: false
    property bool foldersFirst: true
    property bool groupingEnabled: true
    property string sidebarFavoritesJson: "[]"
    property string sidebarHiddenDefaultFavoritesJson: "[]"
    property var sidebarFavorites: []
    property var sidebarHiddenDefaultFavorites: []
    property int sidebarFavoritesRevision: 0
    readonly property bool inTrashView: isTrashPath(currentPath)
    readonly property var defaultSidebarFavoritePaths: [
        homePath + "/Área de trabalho",
        homePath + "/Documentos",
        homePath + "/Downloads",
        homePath + "/Imagens",
        homePath + "/Músicas",
        homePath + "/Vídeos",
        homePath + "/Público",
        homePath + "/Modelos"
    ]

    property alias currentPath: navigationObj.currentPath
    property alias history: navigationObj.history
    property alias historyIdx: navigationObj.historyIdx
    property alias tabs: navigationObj.tabs
    property alias activeTabIndex: navigationObj.activeTabIndex
    property alias nextTabId: navigationObj.nextTabId
    property alias breadcrumbParts: navigationObj.breadcrumbParts
    property alias loadingDir: navigationObj.loadingDir
    property alias loadError: navigationObj.loadError
    property alias dialogActive: navigationObj.dialogActive
    property alias dialogMode: navigationObj.dialogMode
    property alias dialogFilePatterns: navigationObj.dialogFilePatterns
    property alias activeDirectoryRequestPath: navigationObj.activeDirectoryRequestPath
    property alias remoteDirectoryActive: navigationObj.remoteDirectoryActive
    property alias remoteDirectoryReason: navigationObj.remoteDirectoryReason
    property alias searchActive: navigationObj.searchActive
    property alias searchVisible: navigationObj.searchVisible
    property alias searchQuery: navigationObj.searchQuery
    property alias searchRootPath: navigationObj.searchRootPath
    property alias fileModel: navigationObj.fileModel
    property alias fileModelRevision: navigationObj.fileModelRevision
    property alias fileModelFilling: navigationObj.fileModelFilling

    property alias selectedFile: selectionObj.selectedFile
    property alias selectedFiles: selectionObj.selectedFiles
    property alias lastSelectedIndex: selectionObj.lastSelectedIndex

    property alias clipboardFiles: fileOpsObj.clipboardFiles
    property alias clipboardMode: fileOpsObj.clipboardMode
    property alias pasteConflictVisible: fileOpsObj.pasteConflictVisible
    property alias pasteConflictItems: fileOpsObj.pasteConflictItems
    property alias pendingPasteFiles: fileOpsObj.pendingPasteFiles
    property alias pendingPasteMode: fileOpsObj.pendingPasteMode
    property alias pendingPasteDestination: fileOpsObj.pendingPasteDestination
    property alias pendingPasteRename: fileOpsObj.pendingPasteRename
    property alias archiveExtractionRunning: fileOpsObj.archiveExtractionRunning
    property alias archiveExtractionProgress: fileOpsObj.archiveExtractionProgress
    property alias archiveExtractionPercent: fileOpsObj.archiveExtractionPercent
    property alias archiveExtractionFileName: fileOpsObj.archiveExtractionFileName
    property alias archiveExtractionStatus: fileOpsObj.archiveExtractionStatus
    property alias archiveExtractionError: fileOpsObj.archiveExtractionError
    property alias archiveExtractionDestination: fileOpsObj.archiveExtractionDestination
    property alias archiveExtractionDoneCount: fileOpsObj.archiveExtractionDoneCount
    property alias archiveExtractionTotalCount: fileOpsObj.archiveExtractionTotalCount
    property alias archiveExtractionRemainingText: fileOpsObj.archiveExtractionRemainingText
    property alias archivePasswordPromptVisible: fileOpsObj.archivePasswordPromptVisible
    property alias archivePassword: fileOpsObj.archivePassword
    property alias archivePasswordError: fileOpsObj.archivePasswordError
    property alias archiveConflictVisible: fileOpsObj.archiveConflictVisible
    property alias archiveConflictDestination: fileOpsObj.archiveConflictDestination
    property alias archiveConflictName: fileOpsObj.archiveConflictName
    property alias fileOperationRunning: fileOpsObj.fileOperationRunning
    property alias fileOperationProgress: fileOpsObj.fileOperationProgress
    property alias fileOperationPercent: fileOpsObj.fileOperationPercent
    property alias fileOperationFileName: fileOpsObj.fileOperationFileName
    property alias fileOperationStatus: fileOpsObj.fileOperationStatus
    property alias fileOperationError: fileOpsObj.fileOperationError
    property alias fileOperationDestination: fileOpsObj.fileOperationDestination
    property alias fileOperationDoneCount: fileOpsObj.fileOperationDoneCount
    property alias fileOperationTotalCount: fileOpsObj.fileOperationTotalCount
    property alias fileOperationMode: fileOpsObj.fileOperationMode
    property alias appImageInstallRunning: fileOpsObj.appImageInstallRunning
    property alias wallpaperApplyRunning: fileOpsObj.wallpaperApplyRunning

    property alias showPreview: previewObj.showPreview
    property alias viewMode: previewObj.viewMode
    property alias previewsEnabled: previewObj.previewsEnabled
    property alias pendingThumbnailWarmRequest: previewObj.pendingThumbnailWarmRequest
    property alias activeThumbnailWarmRequest: previewObj.activeThumbnailWarmRequest
    property alias activePreviewRefreshPath: previewObj.activePreviewRefreshPath
    property alias startupWarmQueue: previewObj.startupWarmQueue
    property alias zoomLevel: previewObj.zoomLevel

    property alias deviceModel: deviceNetObj.deviceModel
    property alias autoMountDeviceIds: deviceNetObj.autoMountDeviceIds
    property alias autoMountDeviceIdsJson: deviceNetObj.autoMountDeviceIdsJson
    property alias deviceOperationPath: deviceNetObj.deviceOperationPath
    property alias deviceOperationType: deviceNetObj.deviceOperationType
    property alias deviceOperationTargetMountPath: deviceNetObj.deviceOperationTargetMountPath
    property alias deviceOperationOpenAfterMount: deviceNetObj.deviceOperationOpenAfterMount
    property alias lastUnmountedMountPath: deviceNetObj.lastUnmountedMountPath
    property alias deviceError: deviceNetObj.deviceError
    property alias networkConnectVisible: deviceNetObj.networkConnectVisible
    property alias networkAddress: deviceNetObj.networkAddress
    property alias networkError: deviceNetObj.networkError
    property alias networkConnecting: deviceNetObj.networkConnecting

    property Settings persistedState: Settings {
        location: "file://" + state.homePath + "/.config/explorer.conf"
        category: "Explorer"
        property alias currentPath: state.currentPath
        property alias showPreview: state.showPreview
        property alias viewMode: state.viewMode
        property alias sortField: state.sortField
        property alias sortAsc: state.sortAsc
        property alias showHidden: state.showHidden
        property alias foldersFirst: state.foldersFirst
        property alias groupingEnabled: state.groupingEnabled
        property alias zoomLevel: state.zoomLevel
        property alias autoMountDeviceIdsJson: state.autoMountDeviceIdsJson
        property alias sidebarFavoritesJson: state.sidebarFavoritesJson
        property alias sidebarHiddenDefaultFavoritesJson: state.sidebarHiddenDefaultFavoritesJson
    }

    property QtObject selection: StateModules.SelectionState {
        id: selectionObj
        app: state
    }

    property QtObject navigation: StateModules.NavigationState {
        id: navigationObj
        app: state
    }

    property QtObject fileOps: StateModules.FileOperationsState {
        id: fileOpsObj
        app: state
    }

    property QtObject preview: StateModules.PreviewState {
        id: previewObj
        app: state
    }

    property QtObject deviceNet: StateModules.DeviceNetworkState {
        id: deviceNetObj
        app: state
    }

    property QtObject recent: StateModules.RecentState {
        id: recentObj
        app: state
    }

    Component.onCompleted: {
        loadSidebarFavorites()
        navigation.initialize()
        deferredStartupTimer.restart()
    }

    property Timer deferredStartupTimer: Timer {
        interval: 650
        repeat: false
        onTriggered: {
            recent.load()
            deviceNet.loadSavedAutoMounts()
            deviceNet.scheduleStartupDeviceRefresh()
            preview.enableStartupWork()
        }
    }

    function isSelected(name) { return selection.isSelected(name) }
    function clearSelection() { selection.clearSelection() }
    function handleSelection(name, index, ctrlMode, shiftMode, preserveCurrentSelection) { selection.handleSelection(name, index, ctrlMode, shiftMode, preserveCurrentSelection) }
    function selectAll() { selection.selectAll() }
    function selectByName(name) { selection.selectByName(name) }

    function createTab(initialPath) { navigation.createTab(initialPath) }
    function closeTab(index) { navigation.closeTab(index) }
    function closeTabById(tabId) { navigation.closeTabById(tabId) }
    function switchTabById(tabId) { navigation.switchTabById(tabId) }
    function tabIndexById(tabId) { return navigation.tabIndexById(tabId) }
    function activeTabId() { return navigation.activeTabId() }
    function moveTab(fromIndex, toIndex) { navigation.moveTab(fromIndex, toIndex) }
    function switchTab(index) { navigation.switchTab(index) }
    function navigateTo(path) { navigation.navigateTo(path) }
    function goBack() { navigation.goBack() }
    function goForward() { navigation.goForward() }
    function pathComponents() { return navigation.pathComponents() }
    function rebuildBreadcrumbs() { navigation.rebuildBreadcrumbs() }
    function refreshCurrentFolder() { navigation.refreshCurrentFolder() }
    function loadDirectory() { navigation.loadDirectory() }
    function replaceFileModel(items) { navigation.replaceFileModel(items) }
    function updateFileModelMetadata(items) { navigation.updateFileModelMetadata(items) }
    function removePathsFromFileModel(paths) { navigation.removePathsFromFileModel(paths) }
    function selectedItem() { return navigation.selectedItem() }
    function fileMatchesDialogFilter(fileName, isDir) { return navigation.fileMatchesDialogFilter(fileName, isDir) }
    function hideSearch() { navigation.hideSearch() }
    function submitSearch(query) { navigation.submitSearch(query) }
    function clearSearch() { navigation.clearSearch() }

    function isCutPending(name) { return fileOps.isCutPending(name) }
    function joinPath(dirPath, fileName) { return fileOps.joinPath(dirPath, fileName) }
    function fileUrlForPath(path) { return fileOps.fileUrlForPath(path) }
    function selectedPathsInCurrentFolder() { return fileOps.selectedPathsInCurrentFolder() }
    function selectedUriListInCurrentFolder() { return fileOps.selectedUriListInCurrentFolder() }
    function copySelected() { fileOps.copySelected() }
    function cutSelected() { fileOps.cutSelected() }
    function pasteFiles() { fileOps.pasteFiles() }
    function dropFiles(urls, destinationPath, mode) { fileOps.dropFiles(urls, destinationPath, mode) }
    function dropFilePaths(paths, destinationPath, mode) { fileOps.dropFilePaths(paths, destinationPath, mode) }
    function resolvePasteConflict(policy) { fileOps.resolvePasteConflict(policy) }
    function renamePasteConflict(newName) { fileOps.renamePasteConflict(newName) }
    function cancelPasteConflict() { fileOps.cancelPasteConflict() }
    function deleteSelected() { fileOps.deleteSelected() }
    function restoreSelected() { fileOps.restoreSelected() }
    function emptyTrash() { fileOps.emptyTrash() }
    function startArchiveExtraction(archivePath, folderName) { fileOps.startArchiveExtraction(archivePath, folderName) }
    function submitArchivePassword(password) { fileOps.submitArchivePassword(password) }
    function cancelArchivePassword() { fileOps.cancelArchivePassword() }
    function submitArchiveConflict(policy) { fileOps.submitArchiveConflict(policy) }
    function cancelArchiveConflict() { fileOps.cancelArchiveConflict() }
    function startFolderCompression(folderPath, format) { fileOps.startFolderCompression(folderPath, format) }
    function isAppImageFileName(fileName) { return String(fileName || "").toLowerCase().endsWith(".appimage") }
    function isWallpaperImageFileName(fileName) { return /\.(avif|bmp|gif|heic|heif|jpe?g|png|tif|tiff|webp)$/i.test(String(fileName || "")) }
    function installAppImage(path) { fileOps.installAppImage(path) }
    function setAsWallpaper(path) { fileOps.setAsWallpaper(path) }

    function refreshPreviewMetadata() { preview.refreshPreviewMetadata() }
    function fileIconName(fileName, isFolder, isExecutable) { return preview.fileIconName(fileName, isFolder, isExecutable) }
    function portalIconSource(iconName, size) { return preview.portalIconSource(iconName, size) }
    function sidebarIconSource(iconName, size) { return preview.sidebarIconSource(iconName, size) }
    function isPreviewableFile(fileName, isDir) { return preview.isPreviewableFile(fileName, isDir) }
    function requestThumbnailWarm(path, offset, limit) { preview.requestThumbnailWarm(path, offset, limit) }
    function startThumbnailWarm(request) { preview.startThumbnailWarm(request) }
    function warmCurrentDirectoryThumbnails() { preview.warmCurrentDirectoryThumbnails() }
    function scheduleVisibleThumbnailWarm(firstIndex, lastIndex) { preview.scheduleVisibleThumbnailWarm(firstIndex, lastIndex) }
    function enqueueStartupWarm(path, limit) { preview.enqueueStartupWarm(path, limit) }
    function scheduleHomeThumbnailWarmup() { preview.scheduleHomeThumbnailWarmup() }
    function formatSize(bytes) { return preview.formatSize(bytes) }
    function formatDate(date) { return preview.formatDate(date) }
    function itemColor(name, hovered) { return preview.itemColor(name, hovered) }
    function setZoom(level) { preview.setZoom(level) }
    function increaseZoom() { preview.increaseZoom() }
    function decreaseZoom() { preview.decreaseZoom() }
    function resetZoom() { preview.resetZoom() }
    function syncViewModeWithZoom() { preview.syncViewModeWithZoom() }
    function thumbnailLevel() { return preview.thumbnailLevel() }
    function thumbnailColumnCount() { return preview.thumbnailColumnCount() }
    function thumbnailScale() { return preview.thumbnailScale() }
    function openShellScript(path) { preview.openShellScript(path) }
    function openItem(path, isDir, fileUrl) { preview.openItem(path, isDir, fileUrl) }
    function recordRecentItem(path, isDir, fileUrl) { recent.recordAccess(path, isDir, fileUrl) }
    function recentModelItems() { return recent.recentModelItems() }

    signal contextMenuOpening(string owner)

    function announceContextMenuOpening(owner) {
        contextMenuOpening(owner || "")
    }

    function normalizeSidebarPath(path) {
        var text = String(path || "")
        if (text.length > 1)
            text = text.replace(/\/+$/, "")
        return text
    }

    function sidebarLabelForPath(path) {
        var cleanPath = normalizeSidebarPath(path)
        if (cleanPath === homePath)
            return "Home Folder"
        if (cleanPath === "/")
            return "System"
        var parts = cleanPath.split("/").filter(Boolean)
        return parts.length > 0 ? parts[parts.length - 1] : cleanPath
    }

    function parseSidebarArray(text) {
        try {
            var parsed = JSON.parse(text || "[]")
            return Array.isArray(parsed) ? parsed : []
        } catch (error) {
            return []
        }
    }

    function loadSidebarFavorites() {
        var parsedFavorites = parseSidebarArray(sidebarFavoritesJson)
        var nextFavorites = []
        var seen = {}

        for (var i = 0; i < parsedFavorites.length; i++) {
            var entry = parsedFavorites[i] || {}
            var path = normalizeSidebarPath(entry.path)
            if (!path || seen[path] || isDefaultSidebarFavoritePath(path))
                continue
            seen[path] = true
            nextFavorites.push({
                label: entry.label || sidebarLabelForPath(path),
                icon: entry.icon || "inode-directory",
                path: path
            })
        }

        var parsedHidden = parseSidebarArray(sidebarHiddenDefaultFavoritesJson)
        var nextHidden = []
        seen = {}
        for (var h = 0; h < parsedHidden.length; h++) {
            var hiddenPath = normalizeSidebarPath(parsedHidden[h])
            if (!hiddenPath || seen[hiddenPath] || !isDefaultSidebarFavoritePath(hiddenPath))
                continue
            seen[hiddenPath] = true
            nextHidden.push(hiddenPath)
        }

        sidebarFavorites = nextFavorites
        sidebarHiddenDefaultFavorites = nextHidden
        sidebarFavoritesRevision++
    }

    function saveSidebarFavorites() {
        sidebarFavoritesJson = JSON.stringify(sidebarFavorites)
        sidebarHiddenDefaultFavoritesJson = JSON.stringify(sidebarHiddenDefaultFavorites)
        sidebarFavoritesRevision++
    }

    function isDefaultSidebarFavoritePath(path) {
        var cleanPath = normalizeSidebarPath(path)
        for (var i = 0; i < defaultSidebarFavoritePaths.length; i++) {
            if (normalizeSidebarPath(defaultSidebarFavoritePaths[i]) === cleanPath)
                return true
        }
        return false
    }

    function isDefaultSidebarFavoriteHidden(path) {
        var cleanPath = normalizeSidebarPath(path)
        for (var i = 0; i < sidebarHiddenDefaultFavorites.length; i++) {
            if (normalizeSidebarPath(sidebarHiddenDefaultFavorites[i]) === cleanPath)
                return true
        }
        return false
    }

    function isCustomSidebarFavorite(path) {
        var cleanPath = normalizeSidebarPath(path)
        for (var i = 0; i < sidebarFavorites.length; i++) {
            if (normalizeSidebarPath(sidebarFavorites[i].path) === cleanPath)
                return true
        }
        return false
    }

    function isSidebarFavorite(path) {
        var cleanPath = normalizeSidebarPath(path)
        if (isCustomSidebarFavorite(cleanPath))
            return true
        return isDefaultSidebarFavoritePath(cleanPath) && !isDefaultSidebarFavoriteHidden(cleanPath)
    }

    function canPinSidebarFavorite(path) {
        var cleanPath = normalizeSidebarPath(path)
        return cleanPath !== "" && cleanPath.indexOf("/") === 0 && !isTrashPath(cleanPath)
    }

    function visibleDefaultSidebarFavorites(items) {
        var visibleItems = []
        for (var i = 0; i < items.length; i++) {
            if (!isDefaultSidebarFavoriteHidden(items[i].path))
                visibleItems.push(items[i])
        }
        return visibleItems
    }

    function pinSidebarFavorite(path, label, icon) {
        var cleanPath = normalizeSidebarPath(path)
        if (!canPinSidebarFavorite(cleanPath))
            return

        if (isDefaultSidebarFavoritePath(cleanPath)) {
            var hidden = []
            for (var h = 0; h < sidebarHiddenDefaultFavorites.length; h++) {
                var hiddenPath = normalizeSidebarPath(sidebarHiddenDefaultFavorites[h])
                if (hiddenPath !== cleanPath)
                    hidden.push(hiddenPath)
            }
            sidebarHiddenDefaultFavorites = hidden
            saveSidebarFavorites()
            return
        }

        if (isCustomSidebarFavorite(cleanPath))
            return

        var next = sidebarFavorites.slice()
        next.push({
            label: label || sidebarLabelForPath(cleanPath),
            icon: icon || "inode-directory",
            path: cleanPath
        })
        sidebarFavorites = next
        saveSidebarFavorites()
    }

    function removeSidebarFavorite(path) {
        var cleanPath = normalizeSidebarPath(path)
        if (!cleanPath)
            return

        if (isDefaultSidebarFavoritePath(cleanPath)) {
            if (!isDefaultSidebarFavoriteHidden(cleanPath)) {
                var hidden = sidebarHiddenDefaultFavorites.slice()
                hidden.push(cleanPath)
                sidebarHiddenDefaultFavorites = hidden
                saveSidebarFavorites()
            }
            return
        }

        var next = []
        for (var i = 0; i < sidebarFavorites.length; i++) {
            if (normalizeSidebarPath(sidebarFavorites[i].path) !== cleanPath)
                next.push(sidebarFavorites[i])
        }
        if (next.length !== sidebarFavorites.length) {
            sidebarFavorites = next
            saveSidebarFavorites()
        }
    }

    function isTrashPath(path) {
        return (path || "").replace(/\/+$/, "") === trashFilesPath
    }

    function isRecentPath(path) {
        return (path || "") === recentVirtualPath
    }

    function showNetworkConnectDialog() { deviceNet.showNetworkConnectDialog() }
    function hideNetworkConnectDialog() { deviceNet.hideNetworkConnectDialog() }
    function normalizedNetworkAddress() { return deviceNet.normalizedNetworkAddress() }
    function openNetworkBrowser() { deviceNet.openNetworkBrowser() }
    function connectToNetwork() { deviceNet.connectToNetwork() }
    function loadSavedAutoMounts() { deviceNet.loadSavedAutoMounts() }
    function saveAutoMounts() { deviceNet.saveAutoMounts() }
    function isDeviceAutoMount(deviceId) { return deviceNet.isDeviceAutoMount(deviceId) }
    function setDeviceAutoMount(deviceId, enabled) { deviceNet.setDeviceAutoMount(deviceId, enabled) }
    function toggleDeviceAutoMount(deviceId) { deviceNet.toggleDeviceAutoMount(deviceId) }
    function syncDeviceAutoMountFlags() { deviceNet.syncDeviceAutoMountFlags() }
    function replaceDeviceModel(items) { deviceNet.replaceDeviceModel(items) }
    function refreshDevices() { deviceNet.refreshDevices() }
    function ensureAutoMountDevices() { deviceNet.ensureAutoMountDevices() }
    function requestMountDevice(devicePath, fromAutoMount, openAfterMount) { deviceNet.requestMountDevice(devicePath, fromAutoMount, openAfterMount) }
    function requestUnmountDevice(devicePath, mountPath) { deviceNet.requestUnmountDevice(devicePath, mountPath) }
    function requestRemountDevice(devicePath, mountPath, openAfterMount) { deviceNet.requestRemountDevice(devicePath, mountPath, openAfterMount) }
    function syncDeviceBusyFlags() { deviceNet.syncDeviceBusyFlags() }
    function startSearch() { navigation.startSearch() }

    function scrollPositionKey(path, viewMode) {
        return (viewMode || "list") + "::" + (path || "")
    }

    function rememberScrollPosition(path, viewMode, position) {
        if (!path || searchActive)
            return
        if (typeof position !== "number" || isNaN(position))
            return

        var key = scrollPositionKey(path, viewMode)
        var next = {}
        for (var existingKey in scrollPositions)
            next[existingKey] = scrollPositions[existingKey]
        next[key] = Math.max(0, position)
        scrollPositions = next
    }

    function savedScrollPosition(path, viewMode) {
        if (!path || searchActive)
            return 0

        var key = scrollPositionKey(path, viewMode)
        return scrollPositions[key] || 0
    }

    signal dialogFileActivated(string path, string fileUrl)

    onCurrentPathChanged: rebuildBreadcrumbs()
    onSortFieldChanged: if (currentPath !== "") loadDirectory()
    onSortAscChanged: if (currentPath !== "") loadDirectory()
    onShowHiddenChanged: if (currentPath !== "") loadDirectory()
    onFoldersFirstChanged: if (currentPath !== "") loadDirectory()
    onAutoMountDeviceIdsJsonChanged: loadSavedAutoMounts()
}
