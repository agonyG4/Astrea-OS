import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "AstreaComponents" as UI
import "AstreaI18n" as AstreaI18n

FloatingWindow {
    id: window
    visible: true
    implicitWidth: 980
    implicitHeight: 680
    title: t("apps.media_viewer.title", "Astrea Image Viewer")
    color: "transparent"
    onVisibleChanged: if (!visible) Qt.quit()

    readonly property string homePath: Quickshell.env("HOME") || ""
    readonly property string astreaRoot: Quickshell.env("ASTREA_ROOT") || (homePath + "/.local/share/Astrea")
    readonly property string helperPath: astreaRoot + "/Apps/MediaViewer/media_viewer_helper.py"
    readonly property string startupTarget: Quickshell.env("ASTREA_MEDIA_TARGET") || ""
    property int selectedIndex: -1
    property string errorMessage: ""
    property string currentPreviewUri: ""
    property string previewTargetPath: ""
    property string previewError: ""
    property bool loading: false
    property bool fitToWindow: true
    property real zoom: 1.0
    readonly property color bgColor: UI.Theme.windowBackground
    readonly property color chromeColor: UI.Theme.popupBg
    readonly property color panelColor: UI.Theme.windowWash
    readonly property color cardColor: UI.Theme.cardBg
    readonly property color borderColor: UI.Theme.windowBorder
    readonly property color hoverColor: UI.Theme.cardBorder
    readonly property color selectedColor: Qt.rgba(UI.Theme.accent.r, UI.Theme.accent.g, UI.Theme.accent.b, 0.20)

    ListModel { id: mediaModel }

    readonly property var currentItem: selectedIndex >= 0 && selectedIndex < mediaModel.count
        ? mediaModel.get(selectedIndex)
        : null
    readonly property bool hasMedia: currentItem !== null
    readonly property bool currentIsImage: hasMedia && currentItem.kind === "image"

    function t(key, fallback, params) {
        return AstreaI18n.I18n.tr(key, fallback, params)
    }

    function openTarget(target) {
        if (!target || openProc.running)
            return
        loading = true
        errorMessage = ""
        openProc.command = ["python3", helperPath, "open", target]
        openProc.running = false
        openProc.running = true
    }

    function loadContext(payload) {
        mediaModel.clear()
        var items = payload.items || []
        for (var i = 0; i < items.length; ++i)
            mediaModel.append(items[i])
        selectedIndex = Math.max(-1, Math.min(payload.selected_index || 0, mediaModel.count - 1))
        resetView()
        requestCurrentPreview()
        if (strip.count > 0)
            strip.positionViewAtIndex(selectedIndex, ListView.Center)
    }

    function resetView() {
        fitToWindow = true
        zoom = bestFitZoom()
        syncContentToZoom()
        Qt.callLater(centerImage)
    }

    function clamp(value, low, high) {
        return Math.max(low, Math.min(high, value))
    }

    function imageBaseWidth() {
        return Math.max(1, previewImage.sourceSize.width)
    }

    function imageBaseHeight() {
        return Math.max(1, previewImage.sourceSize.height)
    }

    function shouldUseSmoothScale() {
        if (!currentIsImage || previewImage.status !== Image.Ready)
            return true
        var smallImage = imageBaseWidth() < 512 || imageBaseHeight() < 512
        var highZoom = zoom >= 1.75
        return !(smallImage && highZoom)
    }

    function bestFitZoom() {
        if (!currentIsImage || imageBaseWidth() <= 1 || imageBaseHeight() <= 1)
            return 1.0
        return Math.min(mediaFlick.width / imageBaseWidth(), mediaFlick.height / imageBaseHeight(), 1.0)
    }

    function centerImage() {
        if (!currentIsImage)
            return
        mediaFlick.contentX = Math.max(0, (mediaFlick.contentWidth - mediaFlick.width) / 2)
        mediaFlick.contentY = Math.max(0, (mediaFlick.contentHeight - mediaFlick.height) / 2)
    }

    function fitImageToWindow() {
        if (!currentIsImage)
            return
        fitToWindow = true
        zoom = bestFitZoom()
        syncContentToZoom()
        Qt.callLater(centerImage)
    }

    function actualSize() {
        if (!currentIsImage)
            return
        fitToWindow = false
        zoom = 1.0
        syncContentToZoom()
        Qt.callLater(centerImage)
    }

    function toggleFitActual() {
        if (!currentIsImage)
            return
        if (fitToWindow)
            actualSize()
        else
            fitImageToWindow()
    }

    function selectItem(index) {
        if (index < 0 || index >= mediaModel.count)
            return
        selectedIndex = index
        resetView()
        requestCurrentPreview()
        strip.positionViewAtIndex(index, ListView.Center)
    }

    function selectRelative(delta) {
        if (mediaModel.count === 0)
            return
        var next = selectedIndex + delta
        if (next < 0)
            next = mediaModel.count - 1
        if (next >= mediaModel.count)
            next = 0
        selectItem(next)
    }

    function imageDisplayWidthFor(nextZoom) {
        return Math.max(1, imageBaseWidth() * nextZoom)
    }

    function imageDisplayHeightFor(nextZoom) {
        return Math.max(1, imageBaseHeight() * nextZoom)
    }

    function contentWidthForZoom(nextZoom) {
        return Math.max(mediaFlick.width, imageDisplayWidthFor(nextZoom))
    }

    function contentHeightForZoom(nextZoom) {
        return Math.max(mediaFlick.height, imageDisplayHeightFor(nextZoom))
    }

    function imageXForWidth(widthValue, contentWidthValue) {
        return Math.max(0, (contentWidthValue - widthValue) / 2)
    }

    function imageYForHeight(heightValue, contentHeightValue) {
        return Math.max(0, (contentHeightValue - heightValue) / 2)
    }

    function viewportCenterPoint() {
        return Qt.point(mediaFlick.width / 2, mediaFlick.height / 2)
    }

    function setFlickContentSizeForZoom(nextZoom) {
        mediaFlick.contentWidth = contentWidthForZoom(nextZoom)
        mediaFlick.contentHeight = contentHeightForZoom(nextZoom)
    }

    function imageRatioAtView(zoomValue, viewX, viewY) {
        var widthValue = imageDisplayWidthFor(zoomValue)
        var heightValue = imageDisplayHeightFor(zoomValue)
        var contentWidthValue = contentWidthForZoom(zoomValue)
        var contentHeightValue = contentHeightForZoom(zoomValue)
        return Qt.point(
            clamp((mediaFlick.contentX + viewX - imageXForWidth(widthValue, contentWidthValue)) / widthValue, 0, 1),
            clamp((mediaFlick.contentY + viewY - imageYForHeight(heightValue, contentHeightValue)) / heightValue, 0, 1)
        )
    }

    function positionImageRatioAtView(ratioX, ratioY, viewX, viewY) {
        var widthValue = imageDisplayWidthFor(zoom)
        var heightValue = imageDisplayHeightFor(zoom)
        var contentWidthValue = contentWidthForZoom(zoom)
        var contentHeightValue = contentHeightForZoom(zoom)
        mediaFlick.contentX = clamp(
            imageXForWidth(widthValue, contentWidthValue) + ratioX * widthValue - viewX,
            0,
            Math.max(0, contentWidthValue - mediaFlick.width)
        )
        mediaFlick.contentY = clamp(
            imageYForHeight(heightValue, contentHeightValue) + ratioY * heightValue - viewY,
            0,
            Math.max(0, contentHeightValue - mediaFlick.height)
        )
    }

    function syncContentToZoom(centerPoint) {
        if (mediaFlick.width <= 0 || mediaFlick.height <= 0)
            return
        if (!currentIsImage) {
            mediaFlick.contentWidth = Math.max(1, mediaFlick.width)
            mediaFlick.contentHeight = Math.max(1, mediaFlick.height)
            return
        }
        var viewPoint = centerPoint || viewportCenterPoint()
        var anchorRatio = imageRatioAtView(zoom, viewPoint.x, viewPoint.y)
        setFlickContentSizeForZoom(zoom)
        positionImageRatioAtView(anchorRatio.x, anchorRatio.y, viewPoint.x, viewPoint.y)
    }

    function setZoomAnchored(nextZoom, viewX, viewY) {
        if (!currentIsImage || previewImage.status !== Image.Ready)
            return
        var oldZoom = zoom
        var clampedZoom = clamp(nextZoom, 0.2, 6.0)
        if (Math.abs(clampedZoom - oldZoom) < 0.0001)
            return
        var liveViewPoint = Qt.point(clamp(viewX, 0, mediaFlick.width), clamp(viewY, 0, mediaFlick.height))
        var anchorRatio = imageRatioAtView(oldZoom, liveViewPoint.x, liveViewPoint.y)

        fitToWindow = false
        zoom = clampedZoom
        setFlickContentSizeForZoom(zoom)
        positionImageRatioAtView(anchorRatio.x, anchorRatio.y, liveViewPoint.x, liveViewPoint.y)
    }

    function applyZoom(nextZoom) {
        setZoomAnchored(nextZoom, mediaFlick.width / 2, mediaFlick.height / 2)
    }

    function zoomAt(viewX, viewY, deltaSteps) {
        if (!currentIsImage || previewImage.status !== Image.Ready)
            return
        var factor = Math.pow(1.045, deltaSteps)
        setZoomAnchored(zoom * factor, viewX, viewY)
    }

    function panBy(deltaX, deltaY) {
        mediaFlick.contentX = clamp(
            mediaFlick.contentX - deltaX,
            0,
            Math.max(0, mediaFlick.contentWidth - mediaFlick.width)
        )
        mediaFlick.contentY = clamp(
            mediaFlick.contentY - deltaY,
            0,
            Math.max(0, mediaFlick.contentHeight - mediaFlick.height)
        )
    }

    function requestCurrentPreview() {
        previewError = ""
        if (!currentIsImage || !currentItem) {
            currentPreviewUri = ""
            previewTargetPath = ""
            return
        }
        previewTargetPath = currentItem.path
        currentPreviewUri = ""
        previewProc.command = ["python3", helperPath, "preview", currentItem.path]
        previewProc.running = false
        previewProc.running = true
    }

    Component.onCompleted: {
        Qt.application.name = t("apps.media_viewer.title", "Astrea Image Viewer")
        Qt.application.organization = "agony"
        Qt.application.domain = "local"
        if (startupTarget !== "")
            openTarget(startupTarget)
    }

    Shortcut { sequence: "Left"; onActivated: window.selectRelative(-1) }
    Shortcut { sequence: "Right"; onActivated: window.selectRelative(1) }
    Shortcut { sequence: "Space"; onActivated: window.toggleFitActual() }
    Shortcut { sequence: "Ctrl++"; onActivated: window.applyZoom(window.zoom + 0.10) }
    Shortcut { sequence: "Ctrl+="; onActivated: window.applyZoom(window.zoom + 0.10) }
    Shortcut { sequence: "Ctrl+-"; onActivated: window.applyZoom(window.zoom - 0.10) }
    Shortcut { sequence: "Ctrl+0"; onActivated: window.resetView() }
    Shortcut { sequence: "1"; onActivated: window.resetView() }
    Shortcut { sequence: "Ctrl+9"; onActivated: window.fitImageToWindow() }

    Process {
        id: openProc
        command: []
        running: false
        stdout: StdioCollector {
            id: openStdout
            onStreamFinished: {
                if (text.trim().length === 0)
                    return
                try {
                    var payload = JSON.parse(text)
                    if (payload.ok === false) {
                        mediaModel.clear()
                        selectedIndex = -1
                        errorMessage = payload.error || t("apps.media_viewer.error.open_image", "Could not open the image")
                    } else {
                        loadContext(payload)
                    }
                } catch (error) {
                    mediaModel.clear()
                    selectedIndex = -1
                    errorMessage = t("apps.media_viewer.error.invalid_viewer_response", "Invalid viewer response")
                }
            }
        }
        stderr: StdioCollector { id: openStderr }
        onExited: function(exitCode) {
            loading = false
            if (exitCode !== 0 && errorMessage === "") {
                var text = openStderr.text.trim()
                errorMessage = text || t("apps.media_viewer.error.open_image", "Could not open the image")
            }
        }
    }

    Process {
        id: previewProc
        command: []
        running: false
        stdout: StdioCollector {
            id: previewStdout
            onStreamFinished: {
                if (text.trim().length === 0)
                    return
                try {
                    var payload = JSON.parse(text)
                    if (payload.path !== window.previewTargetPath)
                        return
                    if (payload.ok === true) {
                        window.currentPreviewUri = payload.uri || ""
                        window.previewError = ""
                    } else {
                        window.currentPreviewUri = ""
                        window.previewError = payload.error || t("apps.media_viewer.error.unsupported_format", "Unsupported format")
                    }
                } catch (error) {
                    window.currentPreviewUri = ""
                    window.previewError = t("apps.media_viewer.error.invalid_preview", "Invalid preview")
                }
            }
        }
        stderr: StdioCollector { id: previewStderr }
        onExited: function(exitCode) {
            if (exitCode !== 0 && window.currentPreviewUri === "" && window.previewError === "") {
                var text = previewStderr.text.trim()
                window.previewError = text || t("apps.media_viewer.error.preview_failed", "Could not generate preview")
            }
        }
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        color: window.bgColor
        border.width: 1
        border.color: window.borderColor
        clip: true

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.035)
            z: 1
        }

        DropArea {
            id: dropArea
            anchors.fill: parent
            onDropped: function(drop) {
                if (!drop.hasUrls || drop.urls.length === 0)
                    return
                window.openTarget(String(drop.urls[0]))
                drop.acceptProposedAction()
            }
        }

        MouseArea {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 16
            cursorShape: Qt.SizeAllCursor
            property point pressOffset
            onPressed: mouse => pressOffset = Qt.point(mouse.globalX - window.x, mouse.globalY - window.y)
            onPositionChanged: mouse => {
                if (!pressed)
                    return
                window.x = mouse.globalX - pressOffset.x
                window.y = mouse.globalY - pressOffset.y
            }
        }

        Item {
            id: mediaStage
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: stripFrame.top
            clip: true

            Rectangle {
                anchors.fill: parent
                color: window.panelColor
            }

            Flickable {
                id: mediaFlick
                anchors.fill: parent
                clip: true
                visible: window.currentIsImage
                contentWidth: 1
                contentHeight: 1
                boundsBehavior: Flickable.StopAtBounds
                interactive: false
                onWidthChanged: Qt.callLater(window.syncContentToZoom)
                onHeightChanged: Qt.callLater(window.syncContentToZoom)

                Image {
                    id: previewImage
                    source: window.currentIsImage ? window.currentPreviewUri : ""
                    asynchronous: true
                    cache: false
                    smooth: window.shouldUseSmoothScale()
                    mipmap: true
                    fillMode: Image.PreserveAspectFit
                    width: window.imageDisplayWidthFor(window.zoom)
                    height: window.imageDisplayHeightFor(window.zoom)
                    x: Math.max(0, (mediaFlick.contentWidth - width) / 2)
                    y: Math.max(0, (mediaFlick.contentHeight - height) / 2)
                    onStatusChanged: {
                        if (status !== Image.Ready)
                            return
                        if (window.fitToWindow)
                            window.zoom = window.bestFitZoom()
                        window.syncContentToZoom()
                        Qt.callLater(window.centerImage)
                    }
                }

                UI.TextLabel {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 48, 360)
                    text: window.previewError !== "" ? window.previewError : window.t("apps.media_viewer.error.unsupported_qt_format", "Format not supported by Qt")
                    textColor: UI.Theme.textSecondary
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: window.currentIsImage && (window.previewError !== "" || previewImage.status === Image.Error)
                }

            }

            MouseArea {
                id: imagePointerArea
                anchors.fill: mediaFlick
                visible: window.currentIsImage
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                cursorShape: pressed ? Qt.ClosedHandCursor : (mediaFlick.contentWidth > mediaFlick.width || mediaFlick.contentHeight > mediaFlick.height ? Qt.OpenHandCursor : Qt.ArrowCursor)
                property real lastX: 0
                property real lastY: 0

                onPressed: mouse => {
                    lastX = mouse.x
                    lastY = mouse.y
                }

                onPositionChanged: mouse => {
                    if (!pressed)
                        return
                    window.panBy(mouse.x - lastX, mouse.y - lastY)
                    lastX = mouse.x
                    lastY = mouse.y
                }

                onWheel: wheel => {
                    wheel.accepted = true
                    var steps = wheel.angleDelta.y / 120
                    if (steps === 0)
                        steps = wheel.angleDelta.y > 0 ? 1 : -1
                    window.zoomAt(imagePointerArea.mouseX, imagePointerArea.mouseY, steps)
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 360)
                height: 148
                radius: 8
                color: window.cardColor
                border.width: 1
                border.color: window.errorMessage !== "" ? Qt.rgba(UI.Theme.errorColor.r, UI.Theme.errorColor.g, UI.Theme.errorColor.b, 0.42) : window.borderColor
                visible: !window.hasMedia || window.loading || window.errorMessage !== ""

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 9

                    UI.TextLabel {
                        Layout.fillWidth: true
                        text: window.errorMessage !== "" ? window.t("apps.media_viewer.text.open_failed", "Could not open") : (window.loading ? window.t("apps.media_viewer.text.loading", "Loading") : window.t("apps.media_viewer.text.drop_image_here", "Drop an image here"))
                        textColor: window.errorMessage !== "" ? UI.Theme.errorColor : UI.Theme.textPrimary
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                    }

                    UI.TextLabel {
                        Layout.fillWidth: true
                        text: window.errorMessage !== "" ? window.errorMessage : window.t("apps.media_viewer.text.image_only_help", "Image Viewer only shows image files.")
                        textColor: UI.Theme.textSecondary
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Rectangle {
            id: stripFrame
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: mediaModel.count > 1 ? 92 : 0
            color: window.chromeColor
            border.color: window.borderColor
            border.width: mediaModel.count > 1 ? 1 : 0
            clip: true

            ListView {
                id: strip
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                orientation: ListView.Horizontal
                spacing: 8
                clip: true
                model: mediaModel
                delegate: Rectangle {
                    width: 124
                    height: strip.height - 20
                    radius: 8
                    color: index === window.selectedIndex ? window.selectedColor : UI.Theme.cardBg
                    border.width: 1
                    border.color: index === window.selectedIndex ? UI.Theme.accent : (thumbHover.hovered ? window.hoverColor : window.borderColor)
                    clip: true

                    Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    HoverHandler { id: thumbHover }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.selectItem(index)
                        onDoubleClicked: window.toggleFitActual()
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 3
                        source: model.qt_native ? model.uri : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        smooth: true
                        visible: model.qt_native
                    }

                    UI.TextLabel {
                        anchors.centerIn: parent
                        text: "IMG"
                        textColor: UI.Theme.accent
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        visible: !model.qt_native
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 24
                        color: Qt.rgba(0, 0, 0, 0.62)

                        UI.TextLabel {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            verticalAlignment: Text.AlignVCenter
                            text: model.name
                            textColor: UI.Theme.textPrimary
                            font.pixelSize: 10
                            elide: Text.ElideMiddle
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(10 / 255, 132 / 255, 255 / 255, 0.10)
            border.width: 2
            border.color: UI.Theme.accent
            visible: dropArea.containsDrag
            z: 80

            Rectangle {
                anchors.centerIn: parent
                width: 280
                height: 88
                radius: 8
                color: window.cardColor
                border.width: 1
                border.color: Qt.rgba(UI.Theme.accent.r, UI.Theme.accent.g, UI.Theme.accent.b, 0.45)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 6

                    UI.TextLabel {
                        Layout.fillWidth: true
                        text: window.t("apps.media_viewer.text.open_in_image_viewer", "Open in Image Viewer")
                        textColor: UI.Theme.textPrimary
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                    }

                    UI.TextLabel {
                        Layout.fillWidth: true
                        text: window.t("apps.media_viewer.text.drop_image_here", "Drop an image here")
                        textColor: UI.Theme.textSecondary
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
