pragma Singleton
import Quickshell
import QtQuick 2.15
import QtQml 2.15
import QtCore
import "state" as StateModules

QtObject {
    id: state

    readonly property bool isPortalDialog: (Quickshell.env("BENCH_FILE_DIALOG_OPTIONS") || "") !== ""
    readonly property string quickLookPathFile: "/tmp/explorer-quicklook-path"
    readonly property string quickLookPidFile: "/tmp/explorer-quicklook.pid"
    readonly property string backendPath: "/home/agony/GitHub/Bench/Explorer/backend/target/release/explorer_backend"
    readonly property string networkRootPath: (Quickshell.env("XDG_RUNTIME_DIR") || ("/run/user/" + Quickshell.env("UID"))) + "/gvfs"
    readonly property string trashFilesPath: "/home/agony/.local/share/Trash/files"
    readonly property string trashInfoPath: "/home/agony/.local/share/Trash/info"
    readonly property string recentVirtualPath: "recent://"
    readonly property real minZoom: 0.75
    readonly property real maxZoom: 1.7
    readonly property real thumbnailZoomThreshold: 1.15
    readonly property var thumbnailColumnStops: [18, 14, 10, 7, 5]
    readonly property var thumbnailScaleStops: [1.0, 1.08, 1.16, 1.26, 1.38]
    readonly property color themeSelected: Theme.selected
    readonly property color themeHover: Theme.hover
    property var scrollPositions: ({})

    property string sortField: "name"
    property bool sortAsc: true
    property bool showHidden: false
    property bool foldersFirst: true
    property bool groupingEnabled: true
    readonly property bool inTrashView: isTrashPath(currentPath)

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
    property alias searchActive: navigationObj.searchActive
    property alias searchVisible: navigationObj.searchVisible
    property alias searchQuery: navigationObj.searchQuery
    property alias searchRootPath: navigationObj.searchRootPath
    property alias fileModel: navigationObj.fileModel
    property alias fileModelRevision: navigationObj.fileModelRevision

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

    property alias showPreview: previewObj.showPreview
    property alias viewMode: previewObj.viewMode
    property alias previewsEnabled: previewObj.previewsEnabled
    property alias pendingThumbnailWarmRequest: previewObj.pendingThumbnailWarmRequest
    property alias activeThumbnailWarmRequest: previewObj.activeThumbnailWarmRequest
    property alias activePreviewRefreshPath: previewObj.activePreviewRefreshPath
    property alias startupWarmQueue: previewObj.startupWarmQueue
    property alias quickLookCooldown: previewObj.quickLookCooldown
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
        location: "file:///home/agony/.config/explorer.conf"
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
        navigation.initialize()
        deviceNet.loadSavedAutoMounts()
        deviceNet.refreshDevices()
    }

    function isSelected(name) { return selection.isSelected(name) }
    function clearSelection() { selection.clearSelection() }
    function handleSelection(name, index, ctrlMode, shiftMode, preserveCurrentSelection) { selection.handleSelection(name, index, ctrlMode, shiftMode, preserveCurrentSelection) }
    function selectAll() { selection.selectAll() }

    function createTab(initialPath) { navigation.createTab(initialPath) }
    function closeTab(index) { navigation.closeTab(index) }
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
    function copySelected() { fileOps.copySelected() }
    function cutSelected() { fileOps.cutSelected() }
    function pasteFiles() { fileOps.pasteFiles() }
    function dropFiles(urls, destinationPath, mode) { fileOps.dropFiles(urls, destinationPath, mode) }
    function resolvePasteConflict(policy) { fileOps.resolvePasteConflict(policy) }
    function renamePasteConflict(newName) { fileOps.renamePasteConflict(newName) }
    function cancelPasteConflict() { fileOps.cancelPasteConflict() }
    function deleteSelected() { fileOps.deleteSelected() }
    function emptyTrash() { fileOps.emptyTrash() }

    function refreshPreviewMetadata() { preview.refreshPreviewMetadata() }
    function openQuickLook() { preview.openQuickLook() }
    function syncQuickLookSelection() { preview.syncQuickLookSelection() }
    function fileIconName(fileName, isFolder) { return preview.fileIconName(fileName, isFolder) }
    function portalIconSource(iconName, size) { return preview.portalIconSource(iconName, size) }
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
    onSelectedFileChanged: syncQuickLookSelection()
    onAutoMountDeviceIdsJsonChanged: loadSavedAutoMounts()
}
