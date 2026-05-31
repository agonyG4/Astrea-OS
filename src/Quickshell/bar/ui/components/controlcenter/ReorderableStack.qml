import QtQuick
import "../../.."

Item {
    id: root

    property var model: null
    property bool editMode: false
    property real itemSpacing: Theme.spacingXLarge
    property int columnCount: 4
    property var itemHeightProvider: function(kind, size, group) { return 0 }
    property var itemSpanProvider: function(kind, size, group) { return columnCount }
    property var itemLabelProvider: function(kind, size, group) { return "" }
    property Component itemDelegate: null

    property bool draggingItem: false
    property string draggedKey: ""
    property int dragPreviewIndex: -1
    property real dragLeft: 0
    property real dragTop: 0

    property real editOverlayRadius: Theme.cornerRadiusLarge
    property color editOverlayColor: Qt.rgba(0.10, 0.55, 1.0, 0.06)
    property color editOverlayBorderColor: Qt.rgba(0.35, 0.75, 1.0, 0.24)
    property color labelColor: Qt.rgba(1, 1, 1, 0.62)
    property string labelFontFamily: Theme.fontFamily
    property int labelPixelSize: Theme.fontSizeMicro
    property int hitboxRowsPadding: 2
    property int hitboxMinimumRows: 6
    property int hitboxSize: 54

    signal itemDropped()
    signal itemMovedToSlot(string key, int slot)
    signal itemRemoveRequested(string key)

    height: editMode ? Math.max(layoutHeight(), hitboxLayoutHeight()) : layoutHeight()

    function rowForKey(key) {
        if (!model)
            return null

        for (let i = 0; i < model.count; i++) {
            const row = model.get(i)
            const rowKey = row.moduleId !== undefined && row.moduleId !== "" ? row.moduleId : row.kind
            if (rowKey === key)
                return row
        }

        return null
    }

    function rowKey(row) {
        return row && row.moduleId !== undefined && row.moduleId !== "" ? row.moduleId : (row ? row.kind : "")
    }

    function itemHeight(key) {
        const row = rowForKey(key)
        return itemHeightProvider && row ? itemHeightProvider(row.kind, row.size, row.group) : 0
    }

    function itemSpan(key) {
        const row = rowForKey(key)
        const requested = itemSpanProvider && row ? itemSpanProvider(row.kind, row.size, row.group) : columnCount
        return Math.max(1, Math.min(columnCount, requested))
    }

    function itemSlot(key) {
        const row = rowForKey(key)
        return row && row.slot !== undefined && row.slot >= 0 ? row.slot : -1
    }

    function cellHeight() {
        return 74
    }

    function hitboxRows() {
        const layout = layoutMap(currentOrder())
        return Math.max(hitboxMinimumRows, layout.__maxRow + 1 + hitboxRowsPadding)
    }

    function hitboxCount() {
        return hitboxRows() * columnCount
    }

    function hitboxLayoutHeight() {
        const rows = hitboxRows()
        return rows > 0 ? rows * cellHeight() + Math.max(0, rows - 1) * itemSpacing : 0
    }

    function hitboxGeometry(slot) {
        const layout = layoutMap(currentOrder())
        const row = Math.floor(slot / columnCount)
        const col = slot % columnCount
        const colWidth = columnWidth()
        const top = layout.__rowTops[row] !== undefined ? layout.__rowTops[row] : row * (cellHeight() + itemSpacing)
        const rowHeight = layout.__rowHeights[row] !== undefined ? layout.__rowHeights[row] : cellHeight()
        const size = Math.min(hitboxSize, Math.max(36, colWidth * 0.86))

        return {
            "x": col * (colWidth + itemSpacing) + (colWidth - size) / 2,
            "y": top + (rowHeight - size) / 2,
            "size": size
        }
    }

    function slotOccupied(slot) {
        const used = occupiedCells(draggingItem ? draggedKey : "")
        return used[slot] !== undefined
    }

    function slotCoveredByDrag(slot) {
        if (!draggingItem || dragPreviewIndex < 0)
            return false

        const span = itemSpan(draggedKey)
        const start = normalizeSlotForSpan(dragPreviewIndex, span)
        return slot >= start && slot < start + span
    }

    function columnWidth() {
        return columnCount > 0 ? Math.max(1, (width - itemSpacing * (columnCount - 1)) / columnCount) : width
    }

    function widthForSpan(span) {
        return columnWidth() * span + itemSpacing * Math.max(0, span - 1)
    }

    function itemLabel(key) {
        const row = rowForKey(key)
        return itemLabelProvider && row ? itemLabelProvider(row.kind, row.size, row.group) : ""
    }

    function currentOrder() {
        const order = []
        if (!model)
            return order

        for (let i = 0; i < model.count; i++)
            order.push(rowKey(model.get(i)))

        return order
    }

    function modelIndex(key) {
        if (!model)
            return -1

        for (let i = 0; i < model.count; i++) {
            if (rowKey(model.get(i)) === key)
                return i
        }

        return -1
    }

    function layoutMap(order) {
        const map = {}
        const cells = []
        const rowHeights = {}
        let maxRow = 0
        const colWidth = columnWidth()

        for (let i = 0; i < order.length; i++) {
            const key = order[i]
            const span = itemSpan(key)
            const h = itemHeight(key)
            let slot = root.draggingItem && key === root.draggedKey && root.dragPreviewIndex >= 0 ? root.dragPreviewIndex : itemSlot(key)
            if (slot < 0)
                slot = i

            let row = Math.floor(slot / columnCount)
            let col = slot % columnCount
            if (span >= columnCount)
                col = 0
            else if (col + span > columnCount)
                col = columnCount - span

            slot = row * columnCount + col
            cells.push({ "key": key, "slot": slot, "row": row, "col": col, "span": span, "height": h })
            rowHeights[row] = Math.max(rowHeights[row] || cellHeight(), h)
            maxRow = Math.max(maxRow, row)
        }

        const rowTops = {}
        let y = 0
        for (let rowIndex = 0; rowIndex <= maxRow; rowIndex++) {
            rowTops[rowIndex] = y
            y += (rowHeights[rowIndex] || cellHeight()) + itemSpacing
        }

        let maxBottom = 0
        for (let c = 0; c < cells.length; c++) {
            const cell = cells[c]
            const top = rowTops[cell.row] || 0
            map[cell.key] = {
                "x": cell.col * (colWidth + itemSpacing),
                "y": top,
                "width": widthForSpan(cell.span),
                "height": cell.height,
                "span": cell.span,
                "slot": cell.slot
            }
            maxBottom = Math.max(maxBottom, top + cell.height)
        }

        map.__height = maxBottom
        map.__rowTops = rowTops
        map.__rowHeights = rowHeights
        map.__maxRow = maxRow
        return map
    }

    function layoutHeight() {
        if (!model)
            return 0

        return layoutMap(currentOrder()).__height
    }

    function visualOrder() {
        return currentOrder()
    }

    function visualGeometry(key) {
        const geometry = layoutMap(visualOrder())[key]
        return geometry ? geometry : { "x": 0, "y": 0, "width": width, "height": itemHeight(key), "span": columnCount }
    }

    function clampDragLeft(key, left) {
        const maxLeft = width - widthForSpan(itemSpan(key))
        return Math.max(0, Math.min(maxLeft, left))
    }

    function clampDragTop(key, top) {
        const maxTop = Math.max(0, layoutHeight() + (cellHeight() + itemSpacing) * 4 - itemHeight(key))
        return Math.max(0, Math.min(maxTop, top))
    }

    function normalizeSlotForSpan(slot, span) {
        const rowStart = Math.floor(Math.max(0, slot) / columnCount) * columnCount
        const col = Math.max(0, slot) % columnCount

        if (span >= columnCount)
            return rowStart
        if (col + span > columnCount)
            return rowStart + columnCount - span
        return rowStart + col
    }

    function slotForPosition(key, left, top) {
        const span = itemSpan(key)
        const draggedCenterX = left + widthForSpan(itemSpan(key)) / 2
        const draggedCenterY = top + itemHeight(key) / 2
        const colWidth = columnWidth()
        const col = span >= columnCount ? 0 : Math.max(0, Math.min(columnCount - span, Math.floor(draggedCenterX / (colWidth + itemSpacing))))
        const layout = layoutMap(currentOrder())
        let row = 0

        for (let r = 0; r <= layout.__maxRow + 8; r++) {
            const rowTop = layout.__rowTops[r] !== undefined ? layout.__rowTops[r] : r * (cellHeight() + itemSpacing)
            const rowHeight = layout.__rowHeights[r] !== undefined ? layout.__rowHeights[r] : cellHeight()
            if (draggedCenterY < rowTop + rowHeight + itemSpacing / 2) {
                row = r
                break
            }
        }

        return normalizeSlotForSpan(row * columnCount + col, span)
    }

    function occupiedCells(ignoreKey) {
        const used = {}
        const order = currentOrder()
        for (let i = 0; i < order.length; i++) {
            const key = order[i]
            if (key === ignoreKey)
                continue
            const slot = itemSlot(key)
            if (slot < 0)
                continue
            const span = itemSpan(key)
            const rowStart = Math.floor(slot / columnCount) * columnCount
            const start = span >= columnCount ? rowStart : slot
            for (let j = 0; j < span; j++)
                used[start + j] = key
        }
        return used
    }

    function canPlaceSlot(slot, span, used) {
        const start = normalizeSlotForSpan(slot, span)
        for (let i = 0; i < span; i++) {
            if (used[start + i])
                return false
        }
        return true
    }

    function conflictingKeys(slot, span, ignoreKey) {
        const conflicts = []
        const seen = {}
        const used = occupiedCells(ignoreKey)
        const start = normalizeSlotForSpan(slot, span)

        for (let i = 0; i < span; i++) {
            const key = used[start + i]
            if (key && !seen[key]) {
                conflicts.push(key)
                seen[key] = true
            }
        }

        return conflicts
    }

    function nextFreeSlotForSpan(span, ignoreKey) {
        const used = occupiedCells(ignoreKey)
        for (let slot = 0; slot < 128; slot++) {
            const start = normalizeSlotForSpan(slot, span)
            if (canPlaceSlot(start, span, used))
                return start
        }
        return 0
    }

    function nextAvailableSlotForKind(kind) {
        const span = itemSpanProvider ? Math.max(1, Math.min(columnCount, itemSpanProvider(kind, "small", ""))) : 1
        return nextFreeSlotForSpan(span, "")
    }

    function finishDrag() {
        const key = draggedKey
        const from = modelIndex(key)
        const toSlot = dragPreviewIndex

        if (model && from !== -1 && toSlot !== -1) {
            const span = itemSpan(key)
            const oldSlot = normalizeSlotForSpan(itemSlot(key), span)
            const targetSlot = normalizeSlotForSpan(toSlot, span)
            const conflicts = conflictingKeys(targetSlot, span, key)

            itemMovedToSlot(key, targetSlot)

            for (let i = 0; i < conflicts.length; i++) {
                const conflictKey = conflicts[i]
                const conflictSpan = itemSpan(conflictKey)
                let replacementSlot = i === 0 && oldSlot >= 0 ? normalizeSlotForSpan(oldSlot, conflictSpan) : -1

                if (replacementSlot < 0 || !canPlaceSlot(replacementSlot, conflictSpan, occupiedCells(conflictKey)))
                    replacementSlot = nextFreeSlotForSpan(conflictSpan, conflictKey)

                itemMovedToSlot(conflictKey, replacementSlot)
            }
        }

        draggingItem = false
        draggedKey = ""
        dragPreviewIndex = -1
        dragLeft = 0
        dragTop = 0

        itemDropped()
    }

    Repeater {
        model: root.editMode ? root.hitboxCount() : 0

        delegate: Rectangle {
            readonly property var hitbox: root.hitboxGeometry(index)

            x: hitbox.x
            y: hitbox.y
            width: hitbox.size
            height: hitbox.size
            radius: height / 2
            z: 1
            visible: !root.slotOccupied(index) && !root.slotCoveredByDrag(index)
            opacity: root.dragPreviewIndex === index ? 0.98 : 0.68
            color: root.dragPreviewIndex === index
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                : Theme.surface
            border.width: 1
            border.color: root.dragPreviewIndex === index
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.42)
                : Theme.border

            Behavior on opacity { NumberAnimation { duration: Theme.animationQuick } }
            Behavior on color { ColorAnimation { duration: Theme.animationHover } }
            Behavior on border.color { ColorAnimation { duration: Theme.animationHover } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: height / 2
                color: "transparent"
                border.width: 1
                border.color: root.dragPreviewIndex === index ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20) : Theme.separator
            }
        }
    }

    Repeater {
        model: root.model

        delegate: Item {
            id: stackDelegate

            required property int index
            required property string kind
            required property string moduleId
            required property string size
            required property string group
            required property int slot
            readonly property string itemKey: moduleId !== "" ? moduleId : kind
            readonly property bool isDragged: root.draggingItem && root.draggedKey === itemKey
            readonly property var restingGeometry: root.visualGeometry(itemKey)

            x: isDragged ? root.dragLeft : restingGeometry.x
            y: isDragged ? root.dragTop : restingGeometry.y
            width: isDragged ? root.widthForSpan(root.itemSpan(itemKey)) : restingGeometry.width
            height: restingGeometry.height
            z: isDragged ? 20 : (root.editMode ? 5 : 0)
            scale: isDragged ? 1.025 : 1
            opacity: isDragged ? Theme.opacityDragging : 1

            Behavior on y {
                enabled: !stackDelegate.isDragged
                NumberAnimation { duration: Theme.animationFast; easing.type: Easing.OutCubic }
            }
            Behavior on x {
                enabled: !stackDelegate.isDragged
                NumberAnimation { duration: Theme.animationFast; easing.type: Easing.OutCubic }
            }
            Behavior on scale { NumberAnimation { duration: Theme.animationQuick; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.animationQuick } }

            Loader {
                anchors.fill: parent
                sourceComponent: root.itemDelegate

                onLoaded: {
                    if (item && item.itemKey !== undefined)
                        item.itemKey = stackDelegate.itemKey
                    if (item && item.itemKind !== undefined)
                        item.itemKind = stackDelegate.kind
                    if (item && item.itemSize !== undefined)
                        item.itemSize = stackDelegate.size
                    if (item && item.itemGroup !== undefined)
                        item.itemGroup = stackDelegate.group
                    if (item && item.itemSlot !== undefined)
                        item.itemSlot = stackDelegate.slot
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: root.editOverlayRadius
                color: root.editOverlayColor
                border.width: 1
                border.color: root.editOverlayBorderColor
                visible: root.editMode && stackDelegate.width >= 96
            }

            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: Theme.spacingMedium
                anchors.bottomMargin: Theme.spacing
                visible: false
                text: root.itemLabel(stackDelegate.itemKey)
                color: root.labelColor
                font {
                    family: root.labelFontFamily
                    pixelSize: root.labelPixelSize
                    weight: Font.DemiBold
                }
            }

	        MouseArea {
	            id: dragArea

	            property real grabY: 0
	            property real grabX: 0

	            anchors.fill: parent
	            enabled: root.editMode && (!root.draggingItem || stackDelegate.isDragged)
	            hoverEnabled: true
	            preventStealing: true
	            cursorShape: stackDelegate.isDragged ? Qt.ClosedHandCursor : Qt.OpenHandCursor

	    onPressed: mouse => {
		        const pointer = mapToItem(root, mouse.x, mouse.y)
		        grabX = pointer.x - stackDelegate.x
		        grabY = pointer.y - stackDelegate.y
		        root.draggedKey = stackDelegate.itemKey
		        root.dragPreviewIndex = stackDelegate.slot
		        root.dragLeft = stackDelegate.x
		        root.dragTop = stackDelegate.y
		        root.draggingItem = true
	                }

	            onPositionChanged: mouse => {
	                if (!stackDelegate.isDragged)
	                    return

		        const pointer = mapToItem(root, mouse.x, mouse.y)
		        root.dragLeft = root.clampDragLeft(stackDelegate.itemKey, pointer.x - grabX)
		        root.dragTop = root.clampDragTop(stackDelegate.itemKey, pointer.y - grabY)
		        root.dragPreviewIndex = root.slotForPosition(stackDelegate.itemKey, root.dragLeft, root.dragTop)
	            }

                onReleased: {
                    if (stackDelegate.isDragged)
                        root.finishDrag()
                }

                onCanceled: {
                    if (stackDelegate.isDragged) {
                        root.draggingItem = false
	                        root.draggedKey = ""
	                        root.dragPreviewIndex = -1
	                        root.dragLeft = 0
	                        root.dragTop = 0
                    }
                }
            }

            Rectangle {
                id: removeButton
                x: stackDelegate.width < 96 ? (stackDelegate.width - Math.max(44, Math.min(stackDelegate.width, stackDelegate.height) * 0.72)) / 2 - 7 : -9
                y: stackDelegate.width < 96 ? (stackDelegate.height - Math.max(44, Math.min(stackDelegate.width, stackDelegate.height) * 0.72)) / 2 - 7 : -9
                width: 22
                height: 22
                radius: height / 2
                z: 40
                visible: root.editMode
                color: removeArea.containsMouse ? Theme.errorColor : Theme.surface
                border.width: 1
                border.color: removeArea.containsMouse ? Qt.rgba(Theme.errorColor.r, Theme.errorColor.g, Theme.errorColor.b, 0.44) : Theme.border

                Behavior on color { ColorAnimation { duration: Theme.animationHover } }
                Behavior on border.color { ColorAnimation { duration: Theme.animationHover } }

                Text {
                    anchors.centerIn: parent
                    text: "−"
                    color: removeArea.containsMouse ? "#ffffff" : Theme.shellTextActive
                    font { family: Theme.fontFamily; pixelSize: 17; weight: Font.DemiBold }
                }

                MouseArea {
                    id: removeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.itemRemoveRequested(stackDelegate.itemKey)
                }
            }
        }
    }
}
