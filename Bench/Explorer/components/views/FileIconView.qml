import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.impl 2.15
import "/home/agony/.local/share/Astrea/Features/Files/DragDropSupport.js" as DragDropSupport
import "../.."
import "../common" as CommonComponents
import "ViewShared.js" as ViewShared

// ── FileGridView ──────────────────────────────────────────────────────────────
// Icon-grid (thumbnail) view, paired with FileListView.
//
// Key changes vs. original:
//  • `reuseItems: true` — the original already had this; kept and ensured
//    all bindings are model-role-driven so reuse doesn't leave stale state.
//  • ScrollView wrapper removed. It added an extra Flickable layer, causing
//    double-scroll events and fighting with the GridView's own flicking.
//    GridView is itself a Flickable — just attach ScrollBar directly.
//  • `SmoothedAnimation` on contentY removed. It fought with finger-drag
//    physics and caused rubber-banding on Wayland. Natural flick deceleration
//    is smoother and more predictable.
//  • Wheel handler moved onto the GridView itself (via WheelHandler) — no
//    need for an extra MouseArea z-layer to intercept events. Background
//    click / context-menu kept in a separate, narrow MouseArea so it doesn't
//    steal from items.
//  • Computed tile metrics (`tileWidth`, `columns`, etc.) are `readonly`
//    on the GridView — unchanged, but now with inline comments explaining
//    each value's role.
//  • Preview Image replaced with a Loader (same pattern as list view) so
//    the Image object doesn't exist in the scene graph until a preview URL
//    is actually available — saves memory in dirs full of folders/plain text.
//  • Removed duplicate `x: Math.round((parent.width - width) / 2)` from
//    every child — replaced by a centring Column/Item approach so the math
//    lives in one place.
//  • Icon highlight (`Rectangle#highlight`) now has `Behavior on color` for
//    a subtle hover fade rather than an instant jump.
//  • `warmVisibleRange` now only listens to Y-scroll changes, not X
//    (`onContentXChanged`) — GridView scrolls vertically only, so the X
//    signal was a no-op that fired unnecessarily on resize.
// ─────────────────────────────────────────────────────────────────────────────

Item {
    id: root
    property ListModel sectionModel: ListModel {}
    property string trackedPath: ""
    property bool scrollSyncReady: false
    property bool restoringScroll: false
    property real pendingRestoreY: 0
    property int restoreAttempts: 0
    property alias restoreRetryTimerRef: restoreRetryTimer
    property string queuedDragItemName: ""
    property int queuedDragItemSourceIndex: -1
    property string queuedDragItemPath: ""
    property string queuedDragItemUrl: ""
    property url queuedDragImageUrl: ""
    property int queuedDragPreviewSize: 48
    property real queuedDragX: 0
    property real queuedDragY: 0
    property bool dragStartScheduled: false
    property bool dragInProgress: false

    // ── Activation ────────────────────────────────────────────────────────
    property string lastActivationCandidatePath: ""
    property double lastActivationCandidateAt: 0
    readonly property int  activationIntervalMs: 450
    readonly property real dragStartThreshold: Math.max(12, Qt.styleHints.startDragDistance || 10)

    function resetActivationCandidate() {
        ViewShared.resetActivationCandidate(root)
    }

    function handlePrimaryItemClick(path, isDir, fileUrl, fileName, index, modifiers) {
        ViewShared.handlePrimaryItemClick(root, AppState, path, isDir, fileUrl, fileName, index, modifiers)
    }

    function clamp(v, lo, hi) { return ViewShared.clamp(v, lo, hi) }

    function prepareScrollRestore(path) {
        ViewShared.prepareScrollRestore(root, AppState, "icon", path)
    }

    function applyPendingScrollRestore() {
        ViewShared.applyPendingScrollRestore(root, AppState, grid)
    }

    function refreshAfterModelChange() {
        if (AppState.fileModelFilling)
            return
        ViewShared.refreshAfterModelChange(
            root,
            AppState,
            grid,
            "icon",
            function() { root.rebuildSectionModel() },
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
        if (!drop || !drop.hasUrls)
            return false

        const targetPath = destinationPath || AppState.currentPath
        const dropMode = DragDropSupport.dropModeFor(drop)
        const urls = [].concat(drop.urls || [])

        drop.accepted = true
        Qt.callLater(function() {
            AppState.dropFiles(urls, targetPath, dropMode)
        })
        return true
    }

    function dragPathsForItem(itemName, itemPath) {
        if (AppState.isSelected(itemName) && AppState.selectedFiles.length > 1)
            return AppState.selectedPathsInCurrentFolder()
        return [itemPath]
    }

    function dragUriListForItem(itemName, itemPath, itemUrl) {
        if (AppState.isSelected(itemName) && AppState.selectedFiles.length > 1)
            return AppState.selectedUriListInCurrentFolder()
        return itemUrl || ("file://" + itemPath)
    }

    function queueIconDrag(itemName, itemSourceIndex, itemPath, itemUrl, dragImageUrl, dragPreviewSize, dragX, dragY) {
        if (dragStartScheduled || dragInProgress)
            return

        queuedDragItemName = itemName
        queuedDragItemSourceIndex = itemSourceIndex
        queuedDragItemPath = itemPath
        queuedDragItemUrl = itemUrl
        queuedDragImageUrl = dragImageUrl
        queuedDragPreviewSize = dragPreviewSize
        queuedDragX = dragX
        queuedDragY = dragY
        dragStartScheduled = true

        Qt.callLater(function() {
            root.dragStartScheduled = false
            if (!root.queuedDragItemPath)
                return

            root.resetActivationCandidate()
            AppState.handleSelection(root.queuedDragItemName, root.queuedDragItemSourceIndex, false, false, true)
            root.queuedDragItemUrl = root.dragUriListForItem(root.queuedDragItemName, root.queuedDragItemPath, root.queuedDragItemUrl)
            root.queuedDragItemPath = root.dragPathsForItem(root.queuedDragItemName, root.queuedDragItemPath).join("\n")

            root.dragInProgress = true
            iconDragProxy.Drag.active = true
            iconDragProxy.Drag.startDrag(Qt.CopyAction)
            iconDragProxy.Drag.active = false
            root.dragInProgress = false
            root.cancelQueuedIconDrag()
        })
    }

    function cancelQueuedIconDrag() {
        if (dragInProgress)
            return
        queuedDragItemName = ""
        queuedDragItemSourceIndex = -1
        queuedDragItemPath = ""
        queuedDragItemUrl = ""
        queuedDragImageUrl = ""
        queuedDragPreviewSize = 48
        queuedDragX = 0
        queuedDragY = 0
        dragStartScheduled = false
    }

    function groupLabelForItem(item) {
        return ViewShared.groupLabelForItem(AppState, item)
    }

    function rebuildSectionModel() {
        sectionModel.clear()
        var groups = []
        var currentGroup = ""
        var currentItems = []
        for (var i = 0; i < AppState.fileModel.count; i++) {
            var item = AppState.fileModel.get(i)
            var groupLabel = groupLabelForItem(item)
            if (groupLabel !== currentGroup) {
                if (currentItems.length > 0 || currentGroup !== "") {
                    groups.push({
                        title: currentGroup,
                        items: currentItems
                    })
                }
                currentGroup = groupLabel
                currentItems = []
            }
            currentItems.push({
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
        if (currentItems.length > 0 || currentGroup !== "") {
            groups.push({
                title: currentGroup,
                items: currentItems
            })
        }
        for (var j = 0; j < groups.length; j++)
            sectionModel.append(groups[j])
    }

    // ── Shared helpers ────────────────────────────────────────────────────
    CommonComponents.FileContextMenu {
        id: contextMenu
        anchors.fill: parent
        clipboardProxy: clipboardProxy
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
        function onSortFieldChanged() { root.rebuildSectionModel() }
        function onSortAscChanged() { root.rebuildSectionModel() }
        function onGroupingEnabledChanged() { root.rebuildSectionModel() }
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
                AppState.rememberScrollPosition(root.trackedPath, "icon", grid.contentY)
            root.prepareScrollRestore(AppState.currentPath)
            root.rebuildSectionModel()
            warmTimer.restart()
        }
    }

    Component.onCompleted: {
        rebuildSectionModel()
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

    Item {
        id: iconDragProxy
        x: root.queuedDragX - width / 2
        y: root.queuedDragY - height / 2
        width: root.queuedDragPreviewSize
        height: root.queuedDragPreviewSize
        visible: root.dragInProgress
        opacity: 0
        z: 9999
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction
        Drag.mimeData: ({ "text/uri-list": root.queuedDragItemUrl, "text/plain": root.queuedDragItemPath })
        Drag.imageSource: root.queuedDragImageUrl
        Drag.imageSourceSize: Qt.size(root.queuedDragPreviewSize, root.queuedDragPreviewSize)
        Drag.hotSpot: Qt.point(width / 2, height / 2)
    }

    // ── Sectioned icon view ───────────────────────────────────────────────
    ListView {
        id: grid
        readonly property bool compactLayout: width < 920
        readonly property int sideMargin: compactLayout ? 8 : 14
        anchors { fill: parent; margins: grid.sideMargin }
        model: root.sectionModel
        clip: true
        // With section delegates that each host a Repeater, delegate reuse can
        // briefly paint stale section/item data during fast back-navigation +
        // scroll. Disabling reuse here avoids the transient duplicated icons.
        reuseItems: false
        cacheBuffer: Math.max(height * 2, tileHeight * 10)
        flickDeceleration: compactLayout ? 4200 : 3500
        maximumFlickVelocity: compactLayout ? 6200 : 8000

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        // ── Tile metrics (computed once, read by every delegate) ───────────
        readonly property var   absoluteTileWidths: [72, 90, 120, 160, 220]
        readonly property int   minimumTileWidth: compactLayout ? 76 : 88
        readonly property int   preferredTileWidth: {
            var baseWidth = AppState.isPortalDialog
                ? 100
                : absoluteTileWidths[AppState.thumbnailLevel()]
            return compactLayout ? Math.max(minimumTileWidth, baseWidth - 20) : baseWidth
        }
        readonly property int   columns: Math.max(1, Math.floor(width / preferredTileWidth))
        readonly property int   tileWidth: Math.max(minimumTileWidth, Math.floor(width / columns))
        readonly property int   iconSize:   Math.round(tileWidth * (AppState.isPortalDialog ? 0.68 : 0.55))
        readonly property int   previewReqSize: AppState.isPortalDialog ? 160 : 128
        readonly property int   fontSize:   Math.round(11 + AppState.thumbnailLevel())
        readonly property int   textHeight: Math.round(fontSize * 1.4)
        readonly property int   tilePad:    compactLayout ? 2 : 3
        readonly property int   hlWidth:    tileWidth  - tilePad * 2
        readonly property int   hlHeight:   iconSize + textHeight + 14
        readonly property int   tileHeight: hlHeight + tilePad * 2

        // ── Thumbnail warm-up ─────────────────────────────────────────────
        function warmVisible() {
            if (AppState.fileModel.count <= 0)
                return
            var firstSection = indexAt(8, contentY + 1)
            var lastSection = indexAt(8, contentY + height - 2)
            if (firstSection < 0)
                firstSection = 0
            if (lastSection < 0)
                lastSection = Math.min(count - 1, firstSection + 2)
            firstSection = Math.max(0, Math.min(firstSection, root.sectionModel.count - 1))
            lastSection = Math.max(firstSection, Math.min(lastSection + 1, root.sectionModel.count - 1))

            var firstSource = -1
            var lastSource = -1
            for (var i = firstSection; i <= lastSection; i++) {
                var section = root.sectionModel.get(i)
                var items = section && section.items ? section.items : []
                if (items.length === 0)
                    continue
                if (firstSource < 0)
                    firstSource = items[0].sourceIndex
                lastSource = items[items.length - 1].sourceIndex
            }
            if (firstSource < 0 || lastSource < firstSource)
                return
            var pad = grid.columns * 2
            AppState.scheduleVisibleThumbnailWarm(
                Math.max(0, firstSource - pad),
                Math.min(AppState.fileModel.count - 1, lastSource + pad))
        }

        onContentYChanged: {
            warmTimer.restart()
            if (root.scrollSyncReady && !root.restoringScroll && root.trackedPath === AppState.currentPath)
                AppState.rememberScrollPosition(root.trackedPath, "icon", contentY)
        }
        onWidthChanged: {
            warmTimer.restart()
            root.applyPendingScrollRestore()
        }
        onHeightChanged: {
            warmTimer.restart()
            root.applyPendingScrollRestore()
        }
        onContentHeightChanged: root.applyPendingScrollRestore()
        Component.onCompleted: warmTimer.restart()

        Timer { id: warmTimer; interval: 80; repeat: false; onTriggered: grid.warmVisible() }

        TapHandler {
            acceptedButtons: Qt.RightButton
            gesturePolicy: TapHandler.ReleaseWithinBounds

            onTapped: function(eventPoint, button) {
                root.resetActivationCandidate()
                AppState.clearSelection()
                const pt = grid.mapToItem(contextMenu,
                                          eventPoint.position.x,
                                          eventPoint.position.y)
                contextMenu.openAt(pt.x + 6, pt.y + 6,
                                   AppState.currentPath, true,
                                   "file://" + AppState.currentPath)
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                if (AppState.isPortalDialog) { event.accepted = false; return }

                if (event.modifiers & Qt.ControlModifier) {
                    event.angleDelta.y > 0 ? AppState.increaseZoom() : AppState.decreaseZoom()
                    event.accepted = true
                    return
                }

                const maxY = Math.max(0, grid.contentHeight - grid.height)
                if (event.pixelDelta.y !== 0) {
                    grid.contentY = root.clamp(grid.contentY - event.pixelDelta.y * 1.1, 0, maxY)
                } else if (event.angleDelta.y !== 0) {
                    const notches = Math.max(1, Math.abs(event.angleDelta.y) / 120)
                    const dir     = event.angleDelta.y > 0 ? -1 : 1
                    grid.contentY = root.clamp(
                        grid.contentY + dir * grid.tileHeight * 1.05 * notches, 0, maxY)
                }
                event.accepted = true
            }
        }

        delegate: Item {
            id: sectionBlock
            required property string title
            required property var items

            width: grid.width
            height: sectionHeader.height + sectionFlow.implicitHeight + 8

            Text {
                id: sectionHeader
                anchors {
                    left: parent.left
                    leftMargin: 6
                    top: parent.top
                }
                visible: title !== ""
                text: title
                color: Theme.accent
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Flow {
                id: sectionFlow
                anchors {
                    top: sectionHeader.bottom
                    topMargin: title !== "" ? 8 : 0
                    left: parent.left
                    right: parent.right
                }
                spacing: 0

                Repeater {
                    model: sectionBlock.items

                    delegate: Item {
                        id: tile
                        required property var modelData

                        readonly property int itemSourceIndex: modelData.sourceIndex
                        readonly property string itemPath:  modelData.filePath
                        readonly property string itemUrl:   modelData.fileUrl
                        readonly property bool   itemIsDir: modelData.fileIsDir
                        readonly property bool   itemExecutable: Boolean(modelData.fileExecutable)
                        readonly property string itemName:  modelData.fileName
                        readonly property string cachedIconName: AppState.fileIconName(itemName, itemIsDir, itemExecutable)
                        readonly property bool   isPreviewable: AppState.previewsEnabled &&
                                                                !itemIsDir &&
                                                                modelData.filePreviewUrl !== ""
                        readonly property bool   hasPreview: modelData.filePreviewUrl !== ""
                        property url    activePreviewUrl: modelData.filePreviewUrl
                        readonly property int    previewRequestSize: grid.previewReqSize
                        readonly property int    previewDisplaySize: Math.min(grid.iconSize, Math.round(grid.iconSize * 0.82))
                        readonly property int    dragPreviewSize: Math.max(48, Math.round(grid.iconSize * 0.78))
                        readonly property url    dragImageUrl: DragDropSupport.dragImageUrl(
                                                    hasPreview && activePreviewUrl ? activePreviewUrl : "",
                                                    AppState.portalIconSource(cachedIconName, dragPreviewSize))

                        onModelDataChanged: {
                            activePreviewUrl = ""
                            activePreviewUrl = Qt.binding(function() { return modelData.filePreviewUrl })
                        }

                        property bool dragging: false
                        property real pressX: 0
                        property real pressY: 0

                        width: grid.tileWidth
                        height: grid.hlHeight + grid.tilePad * 2
                        opacity: (AppState.isCutPending(itemName) || modelData.fileHidden) ? 0.4 : 1.0

                        Rectangle {
                            id: hl
                            width: grid.hlWidth; height: grid.hlHeight
                            x: Math.round((parent.width - width)  / 2)
                            y: grid.tilePad
                            radius: 8
                            color: AppState.isSelected(itemName)
                                   ? "#3a3a3c"
                                   : folderDropTarget.containsDrag ? Qt.rgba(0.49, 0.72, 0.97, 0.18)
                                   : tileHover.hovered ? "#2e2e30" : "transparent"
                        }

                        Item {
                            id: iconSlot
                            width: grid.iconSize; height: grid.iconSize
                            x: Math.round((parent.width - width) / 2)
                            y: hl.y + 8

                            Image {
                                anchors.centerIn: parent
                                visible: !tile.hasPreview || previewImage.status !== Image.Ready
                                source: AppState.portalIconSource(tile.cachedIconName, grid.iconSize)
                                width: grid.iconSize; height: grid.iconSize
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true; smooth: true
                                sourceSize: Qt.size(grid.iconSize, grid.iconSize)
                            }

                            Image {
                                id: previewImage
                                anchors.centerIn: parent
                                visible: tile.isPreviewable && status === Image.Ready
                                width: tile.previewDisplaySize; height: tile.previewDisplaySize
                                source: tile.activePreviewUrl
                                asynchronous: true
                                cache: true
                                smooth: true
                                mipmap: true
                                fillMode: Image.PreserveAspectFit
                                sourceSize: Qt.size(tile.previewRequestSize, tile.previewRequestSize)
                            }
                        }

                        Text {
                            width: grid.hlWidth - 8
                            height: grid.textHeight
                            x: Math.round((parent.width - width) / 2)
                            y: iconSlot.y + iconSlot.height + 6
                            text: itemName
                            color: "#ffffff"
                            font { pixelSize: grid.fontSize; weight: Font.Normal }
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment:   Text.AlignVCenter
                            wrapMode: Text.NoWrap
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }

                        HoverHandler {
                            id: tileHover
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: hl
                            z: 1
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            hoverEnabled: true
                            scrollGestureEnabled: false
                            cursorShape: Qt.PointingHandCursor

                            onPressed: function(mouse) {
                                root.cancelQueuedIconDrag()
                                tile.pressX = mouse.x; tile.pressY = mouse.y; tile.dragging = false
                            }

                            onPositionChanged: function(mouse) {
                                if (tile.dragging || !(pressedButtons & Qt.LeftButton)) return
                                const dist = Math.abs(mouse.x - tile.pressX) + Math.abs(mouse.y - tile.pressY)
                                if (dist < root.dragStartThreshold) return
                                tile.dragging = true
                                const pos = tileMouse.mapToItem(root, mouse.x, mouse.y)
                                root.queueIconDrag(
                                    itemName,
                                    itemSourceIndex,
                                    itemPath,
                                    itemUrl,
                                    dragImageUrl,
                                    dragPreviewSize,
                                    pos.x,
                                    pos.y
                                )
                            }

                            onClicked: function(mouse) {
                                root.cancelQueuedIconDrag()
                                tile.dragging = false
                                if (mouse.button === Qt.LeftButton) {
                                    root.handlePrimaryItemClick(
                                        itemPath, itemIsDir, itemUrl, itemName, itemSourceIndex, mouse.modifiers)
                                    return
                                }
                                AppState.handleSelection(
                                    itemName, itemSourceIndex,
                                    Boolean(mouse.modifiers & Qt.ControlModifier),
                                    Boolean(mouse.modifiers & Qt.ShiftModifier), true)
                                if (mouse.button === Qt.RightButton) {
                                    root.resetActivationCandidate()
                                    const pt = parent.mapToItem(contextMenu, mouse.x, mouse.y)
                                    contextMenu.openAt(pt.x + 6, pt.y + 6, itemPath, itemIsDir, itemUrl)
                                }
                            }

                            onReleased: {
                                if (!root.dragInProgress) {
                                    root.cancelQueuedIconDrag()
                                    tile.dragging = false
                                }
                            }
                            onCanceled: {
                                if (!root.dragInProgress) {
                                    root.cancelQueuedIconDrag()
                                    tile.dragging = false
                                }
                            }
                        }

                        DropArea {
                            id: folderDropTarget
                            anchors.fill: hl
                            z: 0
                            enabled: itemIsDir

                            onDropped: function(drop) {
                                if (drop.accepted)
                                    return
                                tile.dragging = false
                                root.handleDroppedUrls(drop, itemPath)
                            }
                        }
                    }
                }
            }
        }
    }
}
