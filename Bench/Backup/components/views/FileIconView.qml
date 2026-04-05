import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.impl 2.15
import "../.."
import "../common" as CommonComponents

Item {
    CommonComponents.FileContextMenu {
        id: contextMenu
        anchors.fill: parent
        clipboardProxy: clipboardProxy
    }

    TextEdit {
        id: clipboardProxy
        visible: false

        function copyPath(path) {
            text = path
            forceActiveFocus()
            select(0, path.length)
            copy()
            text = ""
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            propagateComposedEvents: true
            z: 2

            onPressed: function(mouse) {
                if (grid.indexAt(mouse.x - grid.x, mouse.y - grid.y) !== -1)
                    mouse.accepted = false
            }

            onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton) {
                    AppState.clearSelection()
                    return
                }

                if (mouse.button !== Qt.RightButton)
                    return

                AppState.clearSelection()
                var point = mapToItem(contextMenu, mouse.x, mouse.y)
                contextMenu.openAt(point.x + 6, point.y + 6, AppState.currentPath, true, "file://" + AppState.currentPath)
            }

            onWheel: function(wheel) {
                if (AppState.isPortalDialog) {
                    wheel.accepted = false
                    return
                }

                if (!(wheel.modifiers & Qt.ControlModifier)) {
                    wheel.accepted = false
                    return
                }
                if (wheel.angleDelta.y > 0)
                    AppState.increaseZoom()
                else if (wheel.angleDelta.y < 0)
                    AppState.decreaseZoom()
                wheel.accepted = true
            }
        }

        GridView {
            id: grid
            anchors.fill: parent
            anchors.margins: 14
            model: AppState.fileModel
            clip: true
            reuseItems: true
            cacheBuffer: 180

            readonly property var absoluteTileWidths: [72, 90, 120, 160, 220]
            readonly property int tileWidth: AppState.isPortalDialog ? 100 : absoluteTileWidths[AppState.thumbnailLevel()]
            readonly property int columns: Math.max(1, Math.floor(width / tileWidth))
            readonly property real scale: AppState.thumbnailScale()
            readonly property int iconSize: Math.round(tileWidth * (AppState.isPortalDialog ? 0.68 : 0.55))
            readonly property int previewRequestSize: AppState.isPortalDialog ? 160 : 128
            readonly property int fontSize: Math.round(11 + AppState.thumbnailLevel())
            readonly property int textHeight: Math.round(fontSize * 1.4)
            readonly property int highlightWidth: tileWidth - 6
            readonly property int highlightHeight: iconSize + textHeight + 14

            cellWidth: tileWidth
            cellHeight: highlightHeight + 6

            function scheduleVisibleWarm() {
                visibleWarmTimer.restart()
            }

            function warmVisibleRange() {
                if (count <= 0 || cellWidth <= 0 || cellHeight <= 0)
                    return

                var first = indexAt(contentX + 1, contentY + 1)
                var last = indexAt(contentX + width - 2, contentY + height - 2)
                if (first < 0)
                    first = 0
                if (last < 0)
                    last = Math.min(count - 1, first + columns * 4)
                AppState.scheduleVisibleThumbnailWarm(first, last)
            }

            onContentXChanged: scheduleVisibleWarm()
            onContentYChanged: scheduleVisibleWarm()
            onWidthChanged: scheduleVisibleWarm()
            onHeightChanged: scheduleVisibleWarm()
            Component.onCompleted: scheduleVisibleWarm()

            Timer {
                id: visibleWarmTimer
                interval: 120
                repeat: false
                onTriggered: grid.warmVisibleRange()
            }

            delegate: Item {
                id: delegateRoot
                readonly property string itemPath: filePath
                readonly property string itemUrl: fileUrl
                readonly property bool isPreviewable: AppState.previewsEnabled && !fileIsDir && itemPreviewUrl !== ""
                readonly property string itemIconName: AppState.fileIconName(fileName, fileIsDir)
                readonly property string itemPreviewUrl: filePreviewUrl
                readonly property string dragPreviewSource: hasPreview ? itemPreviewUrl : ""
                readonly property bool hasPreview: isPreviewable && itemPreviewUrl !== ""

                width: grid.cellWidth
                height: grid.cellHeight
                opacity: AppState.isCutPending(fileName) ? 0.4 : 1.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                
                property bool dragging: false
                property real pressX: 0
                property real pressY: 0
                Drag.active: dragging
                Drag.dragType: Drag.Automatic
                Drag.supportedActions: Qt.CopyAction
                Drag.mimeData: {
                    "text/uri-list": itemUrl,
                    "text/plain": itemPath
                }
                Drag.imageSource: dragPreviewSource
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                Rectangle {
                    id: highlight
                    width: grid.highlightWidth
                    height: grid.highlightHeight
                    x: Math.round((parent.width - width) / 2)
                    y: 2
                    radius: 8
                    color: AppState.isSelected(fileName)
                           ? "#3a3a3c"
                           : tileMouse.containsMouse ? "#2e2e30" : "transparent"
                }

                IconImage {
                    id: fallbackIcon
                    width: grid.iconSize
                    height: grid.iconSize
                    x: Math.round((parent.width - width) / 2)
                    y: 8
                    visible: !isPreviewable && !AppState.isPortalDialog
                    name: itemIconName
                    sourceSize: Qt.size(grid.iconSize, grid.iconSize)
                }

                Image {
                    width: grid.iconSize
                    height: grid.iconSize
                    x: Math.round((parent.width - width) / 2)
                    y: 8
                    visible: !isPreviewable && AppState.isPortalDialog
                    source: AppState.portalIconSource(itemIconName, grid.iconSize)
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    sourceSize.width: grid.iconSize
                    sourceSize.height: grid.iconSize
                }

                Image {
                    id: previewImage
                    width: grid.iconSize
                    height: grid.iconSize
                    x: Math.round((parent.width - width) / 2)
                    y: 8
                    visible: hasPreview && status === Image.Ready
                    source: hasPreview
                            ? itemPreviewUrl
                            : ""
                    asynchronous: true
                    cache: true
                    sourceSize.width: grid.previewRequestSize
                    sourceSize.height: grid.previewRequestSize
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }

                Text {
                    width: grid.highlightWidth - 8
                    height: grid.textHeight
                    x: Math.round((parent.width - width) / 2)
                    y: grid.iconSize + 12
                    text: fileName
                    color: "#ffffff"
                    font.pixelSize: grid.fontSize
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: tileMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onPressed: function(mouse) {
                        delegateRoot.pressX = mouse.x
                        delegateRoot.pressY = mouse.y
                        delegateRoot.dragging = false
                    }

                    onPositionChanged: function(mouse) {
                        if (!(pressedButtons & Qt.LeftButton) || delegateRoot.dragging)
                            return

                        if (Math.abs(mouse.x - delegateRoot.pressX) < 8 && Math.abs(mouse.y - delegateRoot.pressY) < 8)
                            return

                        AppState.handleSelection(fileName, index, false, false)
                        delegateRoot.dragging = true
                    }

                    onClicked: function(mouse) {
                        delegateRoot.dragging = false
                        AppState.handleSelection(fileName, index, mouse.modifiers & Qt.ControlModifier, mouse.modifiers & Qt.ShiftModifier)
                        if (mouse.button === Qt.RightButton) {
                            var point = parent.mapToItem(contextMenu, mouse.x, mouse.y)
                            contextMenu.openAt(point.x + 6, point.y + 6, itemPath, fileIsDir, itemUrl)
                        }
                    }

                    onReleased: delegateRoot.dragging = false
                    onCanceled: delegateRoot.dragging = false
                    onDoubleClicked: {
                        AppState.openItem(itemPath, fileIsDir, itemUrl)
                    }
                }
            }
        }
    }
}
