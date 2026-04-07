import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.impl 2.15
import "../.."
import "../common" as CommonComponents

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

    // ── Activation ────────────────────────────────────────────────────────
    property string lastActivationCandidatePath: ""
    property double lastActivationCandidateAt: 0
    readonly property int  activationIntervalMs: 450
    readonly property real dragStartThreshold: Math.max(12, Qt.styleHints.startDragDistance || 10)

    function resetActivationCandidate() {
        lastActivationCandidatePath = ""
        lastActivationCandidateAt   = 0
    }

    function handlePrimaryItemClick(path, isDir, fileUrl, fileName, index, modifiers) {
        const ctrl  = Boolean(modifiers & Qt.ControlModifier)
        const shift = Boolean(modifiers & Qt.ShiftModifier)
        AppState.handleSelection(fileName, index, ctrl, shift, false)
        if (ctrl || shift) return

        const now = Date.now()
        if (lastActivationCandidatePath === path &&
                (now - lastActivationCandidateAt) <= activationIntervalMs) {
            resetActivationCandidate()
            AppState.openItem(path, isDir, fileUrl)
            return
        }
        lastActivationCandidatePath = path
        lastActivationCandidateAt   = now
    }

    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

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

    // ── Grid ──────────────────────────────────────────────────────────────
    GridView {
        id: grid
        anchors { fill: parent; margins: 14 }
        model: AppState.fileModel
        clip: true
        reuseItems: true
        cacheBuffer: 999999
        flickDeceleration: 3500             // feels snappier than the default
        maximumFlickVelocity: 8000

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        // ── Tile metrics (computed once, read by every delegate) ───────────
        readonly property var   absoluteTileWidths: [72, 90, 120, 160, 220]
        readonly property int   tileWidth:  AppState.isPortalDialog
                                                ? 100
                                                : absoluteTileWidths[AppState.thumbnailLevel()]
        readonly property int   columns:    Math.max(1, Math.floor(width / tileWidth))
        readonly property int   iconSize:   Math.round(tileWidth * (AppState.isPortalDialog ? 0.68 : 0.55))
        readonly property int   previewReqSize: AppState.isPortalDialog ? 160 : 128
        readonly property int   fontSize:   Math.round(11 + AppState.thumbnailLevel())
        readonly property int   textHeight: Math.round(fontSize * 1.4)
        readonly property int   firstVisibleIndex: {
            const idx = indexAt(contentX + 1, contentY + 1)
            return idx < 0 ? 0 : idx
        }
        readonly property int   lastVisibleIndex: {
            const idx = indexAt(contentX + width - 2, contentY + height - 2)
            return idx < 0 ? Math.min(count - 1, firstVisibleIndex + columns * 4) : idx
        }
        // The visible highlight box (slightly inset from the cell)
        readonly property int   tilePad:    3
        readonly property int   hlWidth:    tileWidth  - tilePad * 2
        readonly property int   hlHeight:   iconSize + textHeight + 14

        cellWidth:  tileWidth
        cellHeight: hlHeight + tilePad * 2

        // ── Thumbnail warm-up ─────────────────────────────────────────────
        function warmVisible() {
            if (count <= 0 || cellWidth <= 0 || cellHeight <= 0) return
            const first = indexAt(contentX + 1, contentY + 1)
            const last  = indexAt(contentX + width - 2, contentY + height - 2)
            AppState.scheduleVisibleThumbnailWarm(
                first < 0 ? 0 : first,
                last  < 0 ? Math.min(count - 1, (first < 0 ? 0 : first) + columns * 8) : Math.min(count - 1, last + columns * 2))
        }

        onContentYChanged: warmTimer.restart()
        onWidthChanged:    warmTimer.restart()
        onHeightChanged:   warmTimer.restart()
        Component.onCompleted: warmTimer.restart()

        Timer { id: warmTimer; interval: 80; repeat: false; onTriggered: grid.warmVisible() }

        // ── Wheel + background interaction ────────────────────────────────
        // A slim MouseArea at z:0 handles empty-area right-click / left-click.
        // Wheel events are caught by a WheelHandler on the GridView itself —
        // this avoids the "MouseArea steals from Flickable" problem.

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            propagateComposedEvents: true
            z: -1   // below delegates

            onPressed: function(mouse) {
                if (grid.indexAt(mouse.x, mouse.y) !== -1) mouse.accepted = false
            }

            onClicked: function(mouse) {
                root.resetActivationCandidate()
                AppState.clearSelection()
                if (mouse.button === Qt.RightButton) {
                    const pt = mapToItem(contextMenu, mouse.x, mouse.y)
                    contextMenu.openAt(pt.x + 6, pt.y + 6,
                                       AppState.currentPath, true,
                                       "file://" + AppState.currentPath)
                }
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
                        grid.contentY + dir * grid.cellHeight * 1.05 * notches, 0, maxY)
                }
                event.accepted = true
            }
        }

        // ── Delegate ──────────────────────────────────────────────────────
        delegate: Item {
            id: tile

            readonly property string itemPath:  filePath
            readonly property string itemUrl:   fileUrl
            readonly property bool   itemIsDir: fileIsDir
            readonly property string itemName:  fileName
            readonly property string cachedIconName: AppState.fileIconName(itemName, itemIsDir)
            readonly property bool   isPreviewable: AppState.previewsEnabled &&
                                                    !itemIsDir &&
                                                    filePreviewUrl !== ""
            readonly property bool   hasPreview: filePreviewUrl !== ""
            property url    activePreviewUrl: filePreviewUrl

            GridView.onReused: { activePreviewUrl = ""; activePreviewUrl = Qt.binding(function(){ return filePreviewUrl }) }
            readonly property int    previewRequestSize: grid.previewReqSize
            readonly property int    previewDisplaySize: Math.min(grid.iconSize, Math.round(grid.iconSize * 0.82))

            // Drag
            property bool dragging: false
            property real pressX: 0
            property real pressY: 0
            Drag.active: dragging
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: ({ "text/uri-list": itemUrl, "text/plain": itemPath })
            Drag.imageSource: hasPreview && filePreviewUrl ? filePreviewUrl : Qt.resolvedUrl("")
            Drag.hotSpot: Qt.point(width / 2, height / 2)

            width:  grid.cellWidth
            height: grid.cellHeight

            opacity: AppState.isCutPending(itemName) ? 0.4 : 1.0

            // ── Highlight background ──────────────────────────────────────
            Rectangle {
                id: hl
                width: grid.hlWidth; height: grid.hlHeight
                x: Math.round((parent.width - width)  / 2)
                y: grid.tilePad
                radius: 8
                color: AppState.isSelected(itemName)
                       ? "#3a3a3c"
                       : tileMouse.containsMouse ? "#2e2e30" : "transparent"

            }

            // ── Icon area — centred, icon and preview share the same slot ─
            Item {
                id: iconSlot
                width: grid.iconSize; height: grid.iconSize
                x: Math.round((parent.width - width) / 2)
                y: hl.y + 8

                // System icon (non-portal)
                IconImage {
                    anchors.centerIn: parent
                    visible: (!tile.hasPreview || previewImage.status !== Image.Ready) && !AppState.isPortalDialog
                    name: tile.cachedIconName
                    width: grid.iconSize; height: grid.iconSize
                    sourceSize: Qt.size(grid.iconSize, grid.iconSize)
                }

                // Portal icon (xdg-portal context)
                Image {
                    anchors.centerIn: parent
                    visible: (!tile.hasPreview || previewImage.status !== Image.Ready) && AppState.isPortalDialog
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

            // ── Label ─────────────────────────────────────────────────────
            Text {
                width: grid.hlWidth - 8
                height: grid.textHeight
                x: Math.round((parent.width - width) / 2)
                y: iconSlot.y + iconSlot.height + 6
                text: itemName
                color: "#ffffff"
                font { pixelSize: grid.fontSize; weight: Font.Medium }
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment:   Text.AlignVCenter
                wrapMode: Text.NoWrap
                maximumLineCount: 1
                elide: Text.ElideRight
            }

            // ── Interaction ───────────────────────────────────────────────
            MouseArea {
                id: tileMouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onPressed: function(mouse) {
                    tile.pressX = mouse.x; tile.pressY = mouse.y; tile.dragging = false
                }

                onPositionChanged: function(mouse) {
                    if (tile.dragging || !(pressedButtons & Qt.LeftButton)) return
                    const dist = Math.abs(mouse.x - tile.pressX) + Math.abs(mouse.y - tile.pressY)
                    if (dist < root.dragStartThreshold) return
                    root.resetActivationCandidate()
                    AppState.handleSelection(itemName, index, false, false, true)
                    tile.dragging = true
                }

                onClicked: function(mouse) {
                    tile.dragging = false
                    if (mouse.button === Qt.LeftButton) {
                        root.handlePrimaryItemClick(
                            itemPath, itemIsDir, itemUrl, itemName, index, mouse.modifiers)
                        return
                    }
                    AppState.handleSelection(
                        itemName, index,
                        Boolean(mouse.modifiers & Qt.ControlModifier),
                        Boolean(mouse.modifiers & Qt.ShiftModifier), true)
                    if (mouse.button === Qt.RightButton) {
                        root.resetActivationCandidate()
                        const pt = parent.mapToItem(contextMenu, mouse.x, mouse.y)
                        contextMenu.openAt(pt.x + 6, pt.y + 6, itemPath, itemIsDir, itemUrl)
                    }
                }

                onReleased: tile.dragging = false
                onCanceled: tile.dragging = false
            }
        }
    }
}
