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

    // ── Cabeçalho ─────────────────────────────────────────────
    Rectangle {
        id: header
        width: parent.width; height: 26
        color: Theme.toolbar; z: 2
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }

        Row {
            anchors.fill: parent
            Repeater {
                model: [
                    { label: "Nome",                field: "name", flex: 2   },
                    { label: "Data de modificação", field: "date", flex: 1.5 },
                    { label: "Tamanho",             field: "size", flex: 0.8 },
                    { label: "Tipo",                field: "kind", flex: 1   },
                ]
                Item {
                    width: parent.width * (modelData.flex / 5.3); height: parent.height
                    Row {
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 3
                        Text {
                            text: modelData.label
                            color: AppState.sortField === modelData.field ? Theme.accent : Theme.textSec
                            font { pixelSize: 11; weight: Font.Medium }
                        }
                        Text {
                            text: AppState.sortField === modelData.field ? (AppState.sortAsc ? "↑" : "↓") : ""
                            color: Theme.accent; font.pixelSize: 10
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (AppState.sortField === modelData.field) AppState.sortAsc = !AppState.sortAsc
                            else { AppState.sortField = modelData.field; AppState.sortAsc = true }
                        }
                    }
                }
            }
        }
    }

    // ── Lista ─────────────────────────────────────────────────
    ListView {
        readonly property int previewRequestSize: AppState.isPortalDialog ? 96 : 72
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        model: AppState.fileModel
        clip: true
        reuseItems: true
        cacheBuffer: 240
        ScrollBar.vertical: ScrollBar {}

        function scheduleVisibleWarm() {
            visibleWarmTimer.restart()
        }

        function warmVisibleRange() {
            if (count <= 0 || contentItem.childrenRect.height <= 0)
                return

            var first = indexAt(8, contentY + 1)
            var last = indexAt(8, contentY + height - 2)
            if (first < 0)
                first = 0
            if (last < 0)
                last = Math.min(count - 1, first + 18)
            AppState.scheduleVisibleThumbnailWarm(first, last)
        }

        onContentYChanged: scheduleVisibleWarm()
        onHeightChanged: scheduleVisibleWarm()
        Component.onCompleted: scheduleVisibleWarm()

        Timer {
            id: visibleWarmTimer
            interval: 120
            repeat: false
            onTriggered: ListView.view.warmVisibleRange()
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            propagateComposedEvents: true
            z: 2
            onPressed: function(mouse) {
                if (parent.indexAt(mouse.x, mouse.y) !== -1)
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

        delegate: Rectangle {
            id: delegateRoot
            readonly property string itemPath: filePath
            readonly property string itemUrl: fileUrl
            readonly property string itemPreviewUrl: filePreviewUrl
            readonly property bool isPreviewable: AppState.previewsEnabled && !fileIsDir && itemPreviewUrl !== ""
            readonly property string dragPreviewSource: hasPreview ? itemPreviewUrl : ""
            readonly property bool hasPreview: isPreviewable && itemPreviewUrl !== ""
            readonly property real rowScale: Math.max(0.95, AppState.zoomLevel)
            readonly property int iconFrameSize: Math.round((AppState.isPortalDialog ? 76 : 60) * Math.min(AppState.zoomLevel, 1.15))
            readonly property int iconSize: Math.round(iconFrameSize)
            readonly property int primaryFont: Math.round(13 * Math.min(AppState.zoomLevel, 1.25))
            readonly property int secondaryFont: Math.round(12 * Math.min(AppState.zoomLevel, 1.2))
            width: ListView.view.width
            height: Math.max(Math.round(30 * rowScale), iconFrameSize + (AppState.isPortalDialog ? 14 : 8))
            opacity: AppState.isCutPending(fileName) ? 0.4 : 1.0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            color: AppState.itemColor(fileName, hoverArea.containsMouse)
            radius: 5
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

            Row {
                anchors.fill: parent

                // Nome
                Item {
                    width: parent.width * (2 / 5.3); height: parent.height
                    Row {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Item {
                            width: iconFrameSize
                            height: iconFrameSize
                            anchors.verticalCenter: parent.verticalCenter

                            IconImage {
                                id: fallbackIcon
                                anchors.centerIn: parent
                                visible: !isPreviewable && !AppState.isPortalDialog
                                name: AppState.fileIconName(fileName, fileIsDir)
                                width: iconSize
                                height: iconSize
                                sourceSize: Qt.size(iconSize, iconSize)
                            }

                            Image {
                                anchors.centerIn: parent
                                visible: !isPreviewable && AppState.isPortalDialog
                                source: AppState.portalIconSource(AppState.fileIconName(fileName, fileIsDir), iconSize)
                                width: iconSize
                                height: iconSize
                                asynchronous: true
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                sourceSize.width: iconSize
                                sourceSize.height: iconSize
                            }

                            Image {
                                id: previewImage
                                anchors.centerIn: parent
                                visible: hasPreview && status === Image.Ready
                                source: hasPreview
                                        ? itemPreviewUrl
                                        : ""
                                width: iconSize
                                height: iconSize
                                asynchronous: true
                                cache: true
                                sourceSize.width: ListView.view.previewRequestSize
                                sourceSize.height: ListView.view.previewRequestSize
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                            }
                        }
                        Text {
                            text: fileName; color: Theme.text; font.pixelSize: primaryFont
                            elide: Text.ElideMiddle; width: parent.parent.width - 62
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Data
                Item {
                    width: parent.width * (1.5 / 5.3); height: parent.height
                    Text {
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        text: AppState.formatDate(fileModified); color: Theme.textSec
                        font.pixelSize: secondaryFont; elide: Text.ElideRight; width: parent.width - 8
                    }
                }

                // Tamanho
                Item {
                    width: parent.width * (0.8 / 5.3); height: parent.height
                    Text {
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: fileIsDir ? "—" : AppState.formatSize(fileSize)
                        color: Theme.textSec; font.pixelSize: secondaryFont
                    }
                }

                // Tipo
                Item {
                    width: parent.width * (1 / 5.3); height: parent.height
                    Text {
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        text: fileKind
                        color: Theme.textSec; font.pixelSize: secondaryFont; elide: Text.ElideRight; width: parent.width - 8
                    }
                }
            }

            MouseArea {
                id: hoverArea
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
                    AppState.selectedFile = fileName
                    if (mouse.button === Qt.RightButton) {
                        var point = parent.mapToItem(contextMenu, mouse.x, mouse.y)
                        contextMenu.openAt(point.x + 6, point.y + 6, itemPath, fileIsDir, itemUrl)
                    }
                }

                onReleased: delegateRoot.dragging = false
                onCanceled: delegateRoot.dragging = false
                onDoubleClicked: AppState.openItem(itemPath, fileIsDir, itemUrl)
            }

            // Borda selecionado
            Rectangle {
                anchors { left: parent.left; leftMargin: 2; right: parent.right; rightMargin: 2 }
                height: parent.height; radius: 5; color: "transparent"
                border.color: AppState.isSelected(fileName) ? Theme.selectedBdr : "transparent"
                border.width: 1
            }
        }
    }
}
