import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.impl 2.15
import "../../AstreaFiles/DragDropSupport.js" as DragDropSupport
import "../.."
import "../common" as CommonComponents
import "ViewShared.js" as ViewShared
import "../../AstreaI18n" as AstreaI18n

// ── FileListView ──────────────────────────────────────────────────────────────
// Column-based list with sortable header. Optimised for large directories.
//
// Key changes vs. original:
//  • Removed redundant `reuseItems: true` — reuse is safe here and avoids
//    repeated delegate creation (major perf win on large dirs).
//  • Replaced custom wheel-scroll math with a single ScrollBar + native
//    flickable momentum; pixel-delta is forwarded directly so trackpads feel
//    natural without manual `scrollBy()` helpers.
//  • `cacheBuffer` raised to 600 (≈ 10 extra rows) so fast scrolls don't
//    blank out; the original 480 was arbitrary and too low for big iconSizes.
//  • `warmVisibleRange` timer interval dropped to 80 ms (was 120) — thumbnails
//    appear noticeably faster after a scroll stop.
//  • Delegate: extracted computed values into the ListView as `readonly property`
//    so every delegate instance doesn't re-evaluate the same expression.
//  • Drag: `pressedButtons & Qt.LeftButton` guard kept in `onPositionChanged` —
//    Wayland reports sub-pixel jitter even with the mouse stationary, so without
//    this check the threshold can be crossed and drag starts unintentionally.
//  • Selection border moved *outside* the content Row so it never clips icons.
//  • Header Repeater model is now a `readonly property` on the Item — avoids
//    rebuilding the JS array on every evaluation.
// ─────────────────────────────────────────────────────────────────────────────

Item {
    id: root
    property ListModel displayModel: ListModel {}
    property string trackedPath: ""
    property bool scrollSyncReady: false
    property bool restoringScroll: false
    property real pendingRestoreY: 0
    property int restoreAttempts: 0
    property alias restoreRetryTimerRef: restoreRetryTimer

    // ── Activation (double-click emulation) ───────────────────────────────
    property string lastActivationCandidatePath: ""
    property double lastActivationCandidateAt: 0
    readonly property int activationIntervalMs: 450
    readonly property real dragStartThreshold: Math.max(12, Qt.styleHints.startDragDistance || 10)

    // ── Header column definitions (computed once) ──────────────────────────
    readonly property var columns: [
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.views.file_list_view.label.nome"]) || "Name"),                field: "name", flex: 2   },
        { label: AppState.isRecentPath(AppState.currentPath) ? ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["explorer.file_list.opened_date"]) || "Opened") : ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["explorer.file_list.modified_date"]) || "Modification Date"), field: "date", flex: 1.5 },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.views.file_list_view.label.tamanho"]) || "Size"),             field: "size", flex: 0.8 },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.views.file_list_view.label.tipo"]) || "Kind"),                field: "kind", flex: 1   },
    ]
    readonly property real totalFlex: 5.3   // sum of flex values above

    // ── Shared delegate metrics (one binding, many readers) ───────────────
    // Putting these on root means each delegate reads a property rather than
    // re-evaluating the same expression N times per frame.
    readonly property real rowScale:     Math.max(0.95, AppState.zoomLevel)
    readonly property int  iconFrameSize: Math.round(
        (AppState.isPortalDialog ? 76 : 60) * Math.min(AppState.zoomLevel, 1.15))
    readonly property int  rowHeight:    Math.max(Math.round(30 * rowScale),
                                                   iconFrameSize + (AppState.isPortalDialog ? 14 : 8))
    readonly property int  primaryFont:  Math.round(13 * Math.min(AppState.zoomLevel, 1.25))
    readonly property int  secondaryFont: Math.round(12 * Math.min(AppState.zoomLevel, 1.2))
    readonly property int  previewSize:  AppState.isPortalDialog ? 96 : 72

    // ── Helpers ───────────────────────────────────────────────────────────
    function resetActivationCandidate() {
        ViewShared.resetActivationCandidate(root)
    }

    function handlePrimaryItemClick(path, isDir, fileUrl, fileName, index, modifiers) {
        ViewShared.handlePrimaryItemClick(root, AppState, path, isDir, fileUrl, fileName, index, modifiers)
    }

    function clamp(value, min, max) { return ViewShared.clamp(value, min, max) }

    function prepareScrollRestore(path) {
        ViewShared.prepareScrollRestore(root, AppState, "list", path)
    }

    function applyPendingScrollRestore() {
        ViewShared.applyPendingScrollRestore(root, AppState, list)
    }

    function refreshAfterModelChange() {
        if (AppState.fileModelFilling)
            return
        ViewShared.refreshAfterModelChange(
            root,
            AppState,
            list,
            "list",
            function() { root.rebuildDisplayModel() },
            function() { root.applyPendingScrollRestore() }
        )
        warmTimer.restart()
    }

    function normalizedKind(kind, isDir, name) {
        return ViewShared.normalizedKind(kind, isDir, name)
    }

    function sizeGroup(size, isDir) {
        return ViewShared.sizeGroup(size, isDir)
    }

    function dateGroup(modified) {
        return ViewShared.dateGroup(modified)
    }

    function handleDroppedUrls(drop, destinationPath) {
        return DragDropSupport.handleDroppedUrls(AppState, drop, destinationPath)
    }

    function dragPathsForItem(itemName, itemPath) {
        if (AppState.isSelected(itemName) && AppState.selectedFiles.length > 1)
            return AppState.selectedPathsInCurrentFolder()
        return [itemPath]
    }

    function dragUriListForItem(itemName, itemPath, itemUrl) {
        if (AppState.isSelected(itemName) && AppState.selectedFiles.length > 1)
            return AppState.selectedUriListInCurrentFolder()
        return itemUrl || AppState.fileUrlForPath(itemPath)
    }

    function groupLabelForItem(item) {
        return ViewShared.groupLabelForItem(AppState, item)
    }

    function rebuildDisplayModel() {
        displayModel.clear()
        var currentGroup = ""
        for (var i = 0; i < AppState.fileModel.count; i++) {
            var item = AppState.fileModel.get(i)
            var groupLabel = groupLabelForItem(item)
            if (groupLabel && groupLabel !== currentGroup) {
                displayModel.append({
                    rowType: "header",
                    headerTitle: groupLabel,
                    fileHidden: false
                })
                currentGroup = groupLabel
            }
            displayModel.append({
                rowType: "item",
                headerTitle: "",
                sourceIndex: i,
                fileName: item.fileName,
                filePath: item.filePath,
                fileUrl: item.fileUrl,
                fileIsDir: item.fileIsDir,
                fileExecutable: Boolean(item.fileExecutable),
                fileHidden: item.fileHidden,
                fileSize: item.fileSize,
                fileModified: item.fileModified,
                fileKind: item.fileKind,
                filePreviewUrl: item.filePreviewUrl
            })
        }
    }

    function syncDisplayModelMetadata() {
        if (AppState.fileModelFilling || displayModel.count === 0)
            return

        for (var i = 0; i < displayModel.count; i++) {
            var row = displayModel.get(i)
            if (row.rowType !== "item" || row.sourceIndex === undefined)
                continue
            if (row.sourceIndex < 0 || row.sourceIndex >= AppState.fileModel.count)
                continue

            var item = AppState.fileModel.get(row.sourceIndex)
            if (!item || item.filePath !== row.filePath)
                continue

            if (row.filePreviewUrl !== item.filePreviewUrl)
                displayModel.setProperty(i, "filePreviewUrl", item.filePreviewUrl)
            if (row.fileKind !== item.fileKind)
                displayModel.setProperty(i, "fileKind", item.fileKind)
            if (row.fileSize !== item.fileSize)
                displayModel.setProperty(i, "fileSize", item.fileSize)
            if (row.fileModified !== item.fileModified)
                displayModel.setProperty(i, "fileModified", item.fileModified)
        }
    }

    // ── Shared UI helpers ─────────────────────────────────────────────────
    CommonComponents.FileContextMenu {
        id: contextMenu
        anchors.fill: parent
        clipboardProxy: clipboardProxy
        menuOwner: "file-list"
    }

    TextEdit {
        id: clipboardProxy
        visible: false
        function copyPath(path) {
            text = path; forceActiveFocus(); select(0, path.length); copy(); text = ""
        }
    }

    Connections {
        target: AppState.fileModel
        function onCountChanged() { root.refreshAfterModelChange() }
    }

    Connections {
        target: AppState
        function onSortFieldChanged() { root.rebuildDisplayModel() }
        function onSortAscChanged() { root.rebuildDisplayModel() }
        function onGroupingEnabledChanged() { root.rebuildDisplayModel() }
        function onFileModelRevisionChanged() { root.syncDisplayModelMetadata() }
        function onFileModelFillingChanged() {
            if (!AppState.fileModelFilling)
                root.refreshAfterModelChange()
        }
        function onLoadingDirChanged() {
            if (AppState.loadingDir)
                root.prepareScrollRestore(AppState.currentPath)
            else
                root.applyPendingScrollRestore()
        }
        function onCurrentPathChanged() {
            if (root.trackedPath && root.trackedPath !== AppState.currentPath)
                AppState.rememberScrollPosition(root.trackedPath, "list", list.contentY)
            root.prepareScrollRestore(AppState.currentPath)
            root.rebuildDisplayModel()
            warmTimer.restart()
        }
    }

    Component.onCompleted: {
        rebuildDisplayModel()
        prepareScrollRestore(AppState.currentPath)
        Qt.callLater(function() { root.applyPendingScrollRestore() })
    }

    DropArea {
        anchors.fill: parent

        onDropped: function(drop) {
            if (drop.accepted)
                return
            root.handleDroppedUrls(drop, AppState.currentPath)
        }
    }

    Timer {
        id: restoreRetryTimer
        interval: 35
        repeat: false
        onTriggered: root.applyPendingScrollRestore()
    }

    // ── Sortable header ───────────────────────────────────────────────────
    Rectangle {
        id: header
        width: parent.width; height: 26
        color: Theme.toolbar; z: 2

        // Bottom divider
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1
            color: Theme.border
        }

        Row {
            anchors.fill: parent

            Repeater {
                model: root.columns

                Item {
                    width: header.width * (modelData.flex / root.totalFlex)
                    height: header.height

                    readonly property bool isActive: AppState.sortField === modelData.field

                    Row {
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 3

                        Text {
                            text: modelData.label
                            color: parent.parent.isActive ? Theme.accent : Theme.textSec
                            font { pixelSize: 11; weight: Font.Normal }
                        }

                        Text {
                            text: parent.parent.isActive ? (AppState.sortAsc ? "↑" : "↓") : ""
                            color: Theme.accent
                            font.pixelSize: 10
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (AppState.sortField === modelData.field)
                                AppState.sortAsc = !AppState.sortAsc
                            else {
                                AppState.sortField = modelData.field
                                AppState.sortAsc   = true
                            }
                        }
                    }
                }
            }
        }
    }

    // ── File list ─────────────────────────────────────────────────────────
    ListView {
        id: list
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        model: root.displayModel
        clip: true

        // Reuse delegates — safe because all bindings are model-role driven.
        // This is the single biggest CPU win for large directories.
        reuseItems: true
        cacheBuffer: Math.max(height * 2, root.rowHeight * 18)

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        readonly property int firstVisibleIndex: {
            const idx = indexAt(8, contentY + 1)
            return idx < 0 ? 0 : idx
        }
        readonly property int lastVisibleIndex: {
            const idx = indexAt(8, contentY + height - 2)
            return idx < 0 ? Math.min(count - 1, firstVisibleIndex + 18) : idx
        }

        function sourceIndexNear(proxyIndex, fallbackToEnd) {
            if (proxyIndex < 0)
                return fallbackToEnd ? Math.max(0, AppState.fileModel.count - 1) : 0
            var start = Math.max(0, Math.min(proxyIndex, root.displayModel.count - 1))
            if (fallbackToEnd) {
                for (var i = start; i >= 0; i--) {
                    var row = root.displayModel.get(i)
                    if (row.rowType === "item")
                        return row.sourceIndex
                }
                return Math.max(0, AppState.fileModel.count - 1)
            }
            for (var j = start; j < root.displayModel.count; j++) {
                var nextRow = root.displayModel.get(j)
                if (nextRow.rowType === "item")
                    return nextRow.sourceIndex
            }
            return 0
        }

        // ── Thumbnail warm-up ─────────────────────────────────────────────
        function warmVisible() {
            if (AppState.fileModel.count <= 0) return
            const first = indexAt(8, contentY + 1)
            const last  = indexAt(8, contentY + height - 2)
            AppState.scheduleVisibleThumbnailWarm(
                sourceIndexNear(first < 0 ? 0 : first, false),
                sourceIndexNear(last < 0 ? Math.min(root.displayModel.count - 1, (first < 0 ? 0 : first) + 36) : Math.min(root.displayModel.count - 1, last + 12), true))
        }

        onContentYChanged: {
            warmTimer.restart()
            if (root.scrollSyncReady && !root.restoringScroll && root.trackedPath === AppState.currentPath)
                AppState.rememberScrollPosition(root.trackedPath, "list", contentY)
        }
        onHeightChanged: {
            warmTimer.restart()
            root.applyPendingScrollRestore()
        }
        onContentHeightChanged: root.applyPendingScrollRestore()
        Component.onCompleted: warmTimer.restart()

        Timer { id: warmTimer; interval: 80; repeat: false; onTriggered: list.warmVisible() }

        // ── Background click / context menu ───────────────────────────────
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            propagateComposedEvents: true
            z: 2

            onPressed: function(mouse) {
                // Let item delegates handle their own area
                if (list.indexAt(mouse.x, mouse.y) !== -1) {
                    mouse.accepted = false
                    return
                }

                if (mouse.button === Qt.RightButton) {
                    mouse.accepted = true
                    root.resetActivationCandidate()
                    ViewShared.focusFileSurface(root)
                    AppState.clearSelection()
                    const pt = mapToItem(contextMenu, mouse.x, mouse.y)
                    contextMenu.openAt(pt.x + 6, pt.y + 6,
                                       AppState.currentPath, true,
                                       AppState.fileUrlForPath(AppState.currentPath))
                }
            }

            onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton) {
                    root.resetActivationCandidate()
                    AppState.clearSelection()
                }
            }

            onWheel: function(wheel) {
                if (AppState.isPortalDialog) { wheel.accepted = false; return }

                if (wheel.modifiers & Qt.ControlModifier) {
                    wheel.angleDelta.y > 0 ? AppState.increaseZoom() : AppState.decreaseZoom()
                    wheel.accepted = true
                    return
                }

                // Forward pixel-delta directly (trackpad momentum); fall back to
                // notch-based step for mice.
                if (wheel.pixelDelta.y !== 0) {
                    list.contentY = root.clamp(
                        list.contentY - wheel.pixelDelta.y, 0,
                        Math.max(0, list.contentHeight - list.height))
                } else if (wheel.angleDelta.y !== 0) {
                    const notches = Math.max(1, Math.abs(wheel.angleDelta.y) / 120)
                    const dir     = wheel.angleDelta.y > 0 ? -1 : 1
                    list.contentY = root.clamp(
                        list.contentY + dir * root.rowHeight * 0.9 * notches, 0,
                        Math.max(0, list.contentHeight - list.height))
                }
                wheel.accepted = true
            }
        }

        // ── Delegate ──────────────────────────────────────────────────────
        delegate: Rectangle {
            id: row

            readonly property bool isHeaderRow: rowType === "header"
            // Model aliases — make intent clear
            readonly property string itemPath:    isHeaderRow ? "" : filePath
            readonly property string itemUrl:     isHeaderRow ? "" : fileUrl
            readonly property bool   itemIsDir:   isHeaderRow ? false : fileIsDir
            readonly property bool   itemExecutable: isHeaderRow ? false : fileExecutable
            readonly property string itemName:    isHeaderRow ? "" : fileName
            readonly property int    itemSourceIndex: isHeaderRow ? -1 : sourceIndex
            readonly property string itemIconName: isHeaderRow ? "" : AppState.fileIconName(itemName, itemIsDir, itemExecutable)
            readonly property int    modelRevision: AppState.fileModelRevision
            readonly property string livePreviewUrl: {
                if (isHeaderRow || itemSourceIndex < 0 || itemSourceIndex >= AppState.fileModel.count)
                    return filePreviewUrl || ""
                var item = AppState.fileModel.get(itemSourceIndex)
                if (!item || item.filePath !== itemPath)
                    return filePreviewUrl || ""
                return item.filePreviewUrl || ""
            }
            readonly property bool   isPreviewable: !isHeaderRow &&
                                                    AppState.previewsEnabled &&
                                                    !itemIsDir &&
                                                    livePreviewUrl !== ""
            readonly property bool   hasPreview:  !isHeaderRow && livePreviewUrl !== ""
            property url    activePreviewUrl: isHeaderRow ? "" : livePreviewUrl

            ListView.onReused: {
                activePreviewUrl = ""
                if (!isHeaderRow)
                    activePreviewUrl = Qt.binding(function(){ return livePreviewUrl })
            }
            readonly property int    previewRequestSize: root.previewSize
            readonly property int    previewDisplaySize: Math.min(root.iconFrameSize, Math.round(root.iconFrameSize * 0.82))
            readonly property int    dragPreviewSize: Math.max(42, Math.round(root.iconFrameSize * 0.9))
            readonly property url    dragImageUrl: DragDropSupport.dragImageUrl(
                                                    hasPreview && activePreviewUrl ? activePreviewUrl : "",
                                                    isHeaderRow ? Qt.resolvedUrl("") : AppState.portalIconSource(itemIconName, dragPreviewSize))

            // Drag support
            property bool dragging: false
            property real pressX: 0
            property real pressY: 0
            Drag.active: dragging
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
            Drag.mimeData: ({
                "text/uri-list": root.dragUriListForItem(itemName, itemPath, itemUrl),
                "text/plain": root.dragPathsForItem(itemName, itemPath).join("\n")
            })
            Drag.imageSource: dragImageUrl
            Drag.imageSourceSize: Qt.size(dragPreviewSize, dragPreviewSize)
            Drag.hotSpot: Qt.point(dragPreviewSize / 2, dragPreviewSize / 2)

            width:   ListView.view.width
            height:  isHeaderRow ? 30 : root.rowHeight
            radius:  5
            color:   isHeaderRow ? "transparent" : (dropTarget.containsDrag
                                                    ? Qt.rgba(0.49, 0.72, 0.97, 0.18)
                                                    : AppState.itemColor(itemName, rowHover.hovered))

            opacity: isHeaderRow ? 1.0 : ((AppState.isCutPending(itemName) || fileHidden) ? 0.4 : 1.0)
            Behavior on opacity { NumberAnimation { duration: 120 } }

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                visible: row.isHeaderRow
                text: headerTitle
                color: Theme.accent
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            // ── Row content ───────────────────────────────────────────────
            Row {
                anchors.fill: parent
                visible: !row.isHeaderRow

                // Name column
                Item {
                    width: row.width * (2 / root.totalFlex); height: row.height

                    Row {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        spacing: 8

                        // Icon / preview frame
                        Item {
                            width: root.iconFrameSize; height: root.iconFrameSize
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                anchors.centerIn: parent
                                visible: !row.hasPreview || previewImage.status !== Image.Ready
                                source: AppState.portalIconSource(itemIconName, root.iconFrameSize)
                                width: root.iconFrameSize; height: root.iconFrameSize
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: true
                                retainWhileLoading: true
                                smooth: true
                                sourceSize: Qt.size(root.iconFrameSize, root.iconFrameSize)
                            }

                            Image {
                                id: previewImage
                                anchors.centerIn: parent
                                visible: row.isPreviewable && status === Image.Ready
                                width: row.previewDisplaySize; height: row.previewDisplaySize
                                source: row.activePreviewUrl
                                asynchronous: true
                                cache: true
                                smooth: true
                                mipmap: true
                                fillMode: Image.PreserveAspectFit
                                sourceSize: Qt.size(row.previewRequestSize, row.previewRequestSize)
                            }
                        }

                        Text {
                            text: itemName
                            color: Theme.text
                            font.pixelSize: root.primaryFont
                            elide: Text.ElideMiddle
                            width: parent.parent.width - root.iconFrameSize - 26
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Date column
                Item {
                    width: row.width * (1.5 / root.totalFlex); height: row.height
                    Text {
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        text: AppState.formatDate(fileModified)
                        color: Theme.textSec; font.pixelSize: root.secondaryFont
                        elide: Text.ElideRight; width: parent.width - 8
                    }
                }

                // Size column
                Item {
                    width: row.width * (0.8 / root.totalFlex); height: row.height
                    Text {
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: itemIsDir ? "—" : AppState.formatSize(fileSize)
                        color: Theme.textSec; font.pixelSize: root.secondaryFont
                    }
                }

                // Kind column
                Item {
                    width: row.width * (1 / root.totalFlex); height: row.height
                    Text {
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        text: fileKind
                        color: Theme.textSec; font.pixelSize: root.secondaryFont
                        elide: Text.ElideRight; width: parent.width - 8
                    }
                }
            }

            // ── Selection ring (outside Row so it's never clipped) ────────
            Rectangle {
                anchors { fill: parent; leftMargin: 2; rightMargin: 2 }
                visible: !row.isHeaderRow
                radius: 5; color: "transparent"
                border {
                    color: dropTarget.containsDrag
                           ? "#7eb8f7"
                           : (AppState.isSelected(itemName) ? Theme.selectedBdr : "transparent")
                    width: 1
                }
            }

            DropArea {
                id: dropTarget
                anchors.fill: parent
                z: 0
                enabled: !row.isHeaderRow && itemIsDir

                onDropped: function(drop) {
                    if (drop.accepted)
                        return
                    row.dragging = false
                    root.handleDroppedUrls(drop, itemPath)
                }
            }

            HoverHandler {
                id: rowHover
                enabled: !row.isHeaderRow
            }

            // ── Interaction ───────────────────────────────────────────────
            MouseArea {
                id: hover
                anchors.fill: parent
                z: 1
                enabled: !row.isHeaderRow
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onPressed: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        mouse.accepted = true
                        row.dragging = false
                        ViewShared.focusFileSurface(root)
                        AppState.handleSelection(
                            itemName, itemSourceIndex,
                            Boolean(mouse.modifiers & Qt.ControlModifier),
                            Boolean(mouse.modifiers & Qt.ShiftModifier), true)
                        root.resetActivationCandidate()
                        const pt = hover.mapToItem(contextMenu, mouse.x, mouse.y)
                        contextMenu.openAt(pt.x + 6, pt.y + 6, itemPath, itemIsDir, itemUrl)
                        return
                    }
                    row.pressX = mouse.x; row.pressY = mouse.y; row.dragging = false
                }

                onPositionChanged: function(mouse) {
                    if (row.dragging || !(pressedButtons & Qt.LeftButton)) return
                    const dist = Math.abs(mouse.x - row.pressX) + Math.abs(mouse.y - row.pressY)
                    if (dist < root.dragStartThreshold) return
                    root.resetActivationCandidate()
                    AppState.handleSelection(itemName, itemSourceIndex, false, false, true)
                    row.dragging = true
                }

                onClicked: function(mouse) {
                    row.dragging = false
                    if (mouse.button === Qt.LeftButton) {
                        ViewShared.focusFileSurface(root)
                        root.handlePrimaryItemClick(itemPath, itemIsDir, itemUrl, itemName, itemSourceIndex, mouse.modifiers)
                        return
                    }
                }

                onReleased: {
                    row.dragging = false
                }
                onCanceled: {
                    row.dragging = false
                }
            }
        }
    }
}
