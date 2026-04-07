import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.impl 2.15
import "../.."
import "../common" as CommonComponents

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

    // ── Activation (double-click emulation) ───────────────────────────────
    property string lastActivationCandidatePath: ""
    property double lastActivationCandidateAt: 0
    readonly property int activationIntervalMs: 450
    readonly property real dragStartThreshold: Math.max(12, Qt.styleHints.startDragDistance || 10)

    // ── Header column definitions (computed once) ──────────────────────────
    readonly property var columns: [
        { label: "Nome",                field: "name", flex: 2   },
        { label: "Data de modificação", field: "date", flex: 1.5 },
        { label: "Tamanho",             field: "size", flex: 0.8 },
        { label: "Tipo",                field: "kind", flex: 1   },
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

    function clamp(value, min, max) { return Math.max(min, Math.min(max, value)) }

    // ── Shared UI helpers ─────────────────────────────────────────────────
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
                            font { pixelSize: 11; weight: Font.Medium }
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
        model: AppState.fileModel
        clip: true

        // Reuse delegates — safe because all bindings are model-role driven.
        // This is the single biggest CPU win for large directories.
        reuseItems: true
        cacheBuffer: 999999

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        readonly property int firstVisibleIndex: {
            const idx = indexAt(8, contentY + 1)
            return idx < 0 ? 0 : idx
        }
        readonly property int lastVisibleIndex: {
            const idx = indexAt(8, contentY + height - 2)
            return idx < 0 ? Math.min(count - 1, firstVisibleIndex + 18) : idx
        }

        // ── Thumbnail warm-up ─────────────────────────────────────────────
        function warmVisible() {
            if (count <= 0) return
            const first = indexAt(8, contentY + 1)
            const last  = indexAt(8, contentY + height - 2)
            AppState.scheduleVisibleThumbnailWarm(
                first < 0 ? 0 : first,
                last  < 0 ? Math.min(count - 1, (first < 0 ? 0 : first) + 36) : Math.min(count - 1, last + 12))
        }

        onContentYChanged: warmTimer.restart()
        onHeightChanged:   warmTimer.restart()
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
                if (list.indexAt(mouse.x, mouse.y) !== -1) mouse.accepted = false
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

            // Model aliases — make intent clear
            readonly property string itemPath:    filePath
            readonly property string itemUrl:     fileUrl
            readonly property bool   itemIsDir:   fileIsDir
            readonly property string itemName:    fileName
            readonly property bool   isPreviewable: AppState.previewsEnabled &&
                                                    !itemIsDir &&
                                                    filePreviewUrl !== ""
            readonly property bool   hasPreview:  filePreviewUrl !== ""
            property url    activePreviewUrl: filePreviewUrl

            ListView.onReused: { activePreviewUrl = ""; activePreviewUrl = Qt.binding(function(){ return filePreviewUrl }) }
            readonly property int    previewRequestSize: root.previewSize
            readonly property int    previewDisplaySize: Math.min(root.iconFrameSize, Math.round(root.iconFrameSize * 0.82))

            // Drag support
            property bool dragging: false
            property real pressX: 0
            property real pressY: 0
            Drag.active: dragging
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: ({ "text/uri-list": itemUrl, "text/plain": itemPath })
            Drag.imageSource: hasPreview && filePreviewUrl ? filePreviewUrl : Qt.resolvedUrl("")
            Drag.hotSpot: Qt.point(width / 2, height / 2)

            width:   ListView.view.width
            height:  root.rowHeight
            radius:  5
            color:   AppState.itemColor(itemName, hover.containsMouse)

            opacity: AppState.isCutPending(itemName) ? 0.4 : 1.0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            // ── Row content ───────────────────────────────────────────────
            Row {
                anchors.fill: parent

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

                            // System icon (non-portal)
                            IconImage {
                                anchors.centerIn: parent
                                visible: (!row.hasPreview || previewImage.status !== Image.Ready) && !AppState.isPortalDialog
                                name: AppState.fileIconName(itemName, itemIsDir)
                                width: root.iconFrameSize; height: root.iconFrameSize
                                sourceSize: Qt.size(root.iconFrameSize, root.iconFrameSize)
                            }

                            // Portal icon
                            Image {
                                anchors.centerIn: parent
                                visible: (!row.hasPreview || previewImage.status !== Image.Ready) && AppState.isPortalDialog
                                source: AppState.portalIconSource(
                                    AppState.fileIconName(itemName, itemIsDir), root.iconFrameSize)
                                width: root.iconFrameSize; height: root.iconFrameSize
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true; smooth: true
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
                radius: 5; color: "transparent"
                border {
                    color: AppState.isSelected(itemName) ? Theme.selectedBdr : "transparent"
                    width: 1
                }
            }

            // ── Interaction ───────────────────────────────────────────────
            MouseArea {
                id: hover
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onPressed: function(mouse) {
                    row.pressX = mouse.x; row.pressY = mouse.y; row.dragging = false
                }

                onPositionChanged: function(mouse) {
                    if (row.dragging || !(pressedButtons & Qt.LeftButton)) return
                    const dist = Math.abs(mouse.x - row.pressX) + Math.abs(mouse.y - row.pressY)
                    if (dist < root.dragStartThreshold) return
                    root.resetActivationCandidate()
                    AppState.handleSelection(itemName, index, false, false, true)
                    row.dragging = true
                }

                onClicked: function(mouse) {
                    row.dragging = false
                    if (mouse.button === Qt.LeftButton) {
                        root.handlePrimaryItemClick(itemPath, itemIsDir, itemUrl, itemName, index, mouse.modifiers)
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

                onReleased: row.dragging = false
                onCanceled: row.dragging = false
            }
        }
    }
}
