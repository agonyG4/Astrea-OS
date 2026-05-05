import QtQuick

Item {
    id: root

    property var model: null
    property bool editMode: false
    property real itemSpacing: 14
    property var itemHeightProvider: function(key) { return 0 }
    property var itemLabelProvider: function(key) { return "" }
    property Component itemDelegate: null

    property bool draggingItem: false
    property string draggedKey: ""
    property int dragPreviewIndex: -1
    property real dragTop: 0

    property real editOverlayRadius: 14
    property color editOverlayColor: Qt.rgba(0.10, 0.55, 1.0, 0.06)
    property color editOverlayBorderColor: Qt.rgba(0.35, 0.75, 1.0, 0.24)
    property color labelColor: Qt.rgba(1, 1, 1, 0.62)
    property string labelFontFamily: "Inter"
    property int labelPixelSize: 9

    signal itemDropped()

    height: layoutHeight()

    function itemHeight(key) {
        return itemHeightProvider ? itemHeightProvider(key) : 0
    }

    function itemLabel(key) {
        return itemLabelProvider ? itemLabelProvider(key) : ""
    }

    function currentOrder() {
        const order = []
        if (!model)
            return order

        for (let i = 0; i < model.count; i++)
            order.push(model.get(i).kind)

        return order
    }

    function modelIndex(key) {
        if (!model)
            return -1

        for (let i = 0; i < model.count; i++) {
            if (model.get(i).kind === key)
                return i
        }

        return -1
    }

    function topForOrderIndex(order, index) {
        let y = 0
        for (let i = 0; i < index; i++)
            y += itemHeight(order[i]) + itemSpacing
        return y
    }

    function layoutHeight() {
        if (!model)
            return 0

        let h = 0
        for (let i = 0; i < model.count; i++)
            h += itemHeight(model.get(i).kind)

        return h + Math.max(0, model.count - 1) * itemSpacing
    }

    function visualOrder() {
        const order = currentOrder()
        if (!draggingItem || draggedKey === "" || dragPreviewIndex < 0)
            return order

        const without = []
        for (let i = 0; i < order.length; i++) {
            if (order[i] !== draggedKey)
                without.push(order[i])
        }

        const insertAt = Math.max(0, Math.min(without.length, dragPreviewIndex))
        without.splice(insertAt, 0, draggedKey)
        return without
    }

    function visualTop(key) {
        const order = visualOrder()
        for (let i = 0; i < order.length; i++) {
            if (order[i] === key)
                return topForOrderIndex(order, i)
        }
        return 0
    }

    function clampDragTop(key, top) {
        const maxTop = layoutHeight() - itemHeight(key)
        return Math.max(0, Math.min(maxTop, top))
    }

    function previewIndexForTop(key, top) {
        const order = currentOrder()
        const without = []
        for (let i = 0; i < order.length; i++) {
            if (order[i] !== key)
                without.push(order[i])
        }

        const draggedCenter = top + itemHeight(key) / 2
        let preview = 0
        for (let j = 0; j < without.length; j++) {
            const center = topForOrderIndex(without, j) + itemHeight(without[j]) / 2
            if (draggedCenter > center)
                preview = j + 1
        }

        return Math.max(0, Math.min(model ? model.count - 1 : 0, preview))
    }

    function finishDrag() {
        const key = draggedKey
        const to = dragPreviewIndex
        const from = modelIndex(key)

        draggingItem = false
        draggedKey = ""
        dragPreviewIndex = -1
        dragTop = 0

        if (model && from !== -1 && to !== -1 && from !== to)
            model.move(from, to, 1)

        itemDropped()
    }

    Repeater {
        model: root.model

        delegate: Item {
            id: stackDelegate

            required property int index
            required property string kind
            readonly property bool isDragged: root.draggingItem && root.draggedKey === kind
            readonly property real restingY: root.visualTop(kind)

            x: 0
            y: isDragged ? root.dragTop : restingY
            width: root.width
            height: root.itemHeight(kind)
            z: isDragged ? 20 : (root.editMode ? 5 : 0)
            scale: isDragged ? 1.025 : 1
            opacity: isDragged ? 0.94 : 1

            Behavior on y {
                enabled: !stackDelegate.isDragged
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 120 } }

            Loader {
                anchors.fill: parent
                sourceComponent: root.itemDelegate

                onLoaded: {
                    if (item && item.itemKey !== undefined)
                        item.itemKey = stackDelegate.kind
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: root.editOverlayRadius
                color: root.editOverlayColor
                border.width: 1
                border.color: root.editOverlayBorderColor
                visible: root.editMode
            }

            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 10
                anchors.bottomMargin: 8
                visible: root.editMode
                text: root.itemLabel(kind)
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

                anchors.fill: parent
                enabled: root.editMode && (!root.draggingItem || stackDelegate.isDragged)
                hoverEnabled: true
                cursorShape: stackDelegate.isDragged ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                onPressed: mouse => {
                    grabY = mouse.y
                    root.draggedKey = stackDelegate.kind
                    root.dragPreviewIndex = stackDelegate.index
                    root.dragTop = stackDelegate.y
                    root.draggingItem = true
                }

                onPositionChanged: mouse => {
                    if (!stackDelegate.isDragged)
                        return

                    const pointerY = stackDelegate.y + mouse.y
                    root.dragTop = root.clampDragTop(stackDelegate.kind, pointerY - grabY)
                    root.dragPreviewIndex = root.previewIndexForTop(stackDelegate.kind, root.dragTop)
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
                        root.dragTop = 0
                    }
                }
            }
        }
    }
}
