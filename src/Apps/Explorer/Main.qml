import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components/layout" as LayoutComponents
import "components/views" as ViewComponents
import "components/common" as CommonComponents
import "AstreaFiles" as AstreaFiles
import "AstreaI18n" as AstreaI18n

ApplicationWindow {
    id: window
    visible: true
    width: 1100; height: 680
    minimumWidth: 700; minimumHeight: 450
    title: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.title.finder"]) || "Finder")
    color: Theme.bg

    Component.onCompleted: {
        Qt.application.name = "Explorer"
        Qt.application.organization = "agony"
        Qt.application.domain = "local"
    }

    onClosing: function(close) {
        Qt.quit()
    }

    readonly property bool editableTextHasFocus: {
        var item = activeFocusItem
        while (item) {
            var className = String(item)
            if (className.indexOf("QQuickTextInput") !== -1 || className.indexOf("QQuickTextEdit") !== -1)
                return true
            item = item.parent
        }
        return false
    }
    readonly property bool modalTextInputActive: pasteConflictPopup.visible || archivePasswordPopup.visible || archiveConflictPopup.visible
    readonly property bool fileClipboardShortcutAllowed: !editableTextHasFocus && !modalTextInputActive

    function focusFileSurface() {
        if (contentItem && contentItem.forceActiveFocus)
            contentItem.forceActiveFocus()
    }

    Action { id: zoomInAction; shortcut: "Ctrl++"; onTriggered: AppState.increaseZoom() }
    Action { shortcut: "Ctrl+="; onTriggered: zoomInAction.trigger() }
    Action { shortcut: "Ctrl+-"; onTriggered: AppState.decreaseZoom() }
    Action { shortcut: "Ctrl+_"; onTriggered: AppState.decreaseZoom() }
    Action { shortcut: "Ctrl+0"; onTriggered: AppState.resetZoom() }

    Action {
        id: explorerCopyAction
        shortcut: StandardKey.Copy
        onTriggered: {
            if (!fileClipboardShortcutAllowed)
                return
            AppState.copySelected()
        }
    }
    Action {
        id: explorerCutAction
        shortcut: StandardKey.Cut
        onTriggered: {
            if (!fileClipboardShortcutAllowed)
                return
            AppState.cutSelected()
        }
    }
    Action {
        id: explorerPasteAction
        shortcut: StandardKey.Paste
        onTriggered: {
            if (!fileClipboardShortcutAllowed)
                return
            AppState.pasteFiles()
        }
    }
    Action {
        id: explorerSelectAllAction
        shortcut: StandardKey.SelectAll
        onTriggered: {
            if (!fileClipboardShortcutAllowed)
                return
            AppState.selectAll()
        }
    }
    Action { shortcut: "Delete"; onTriggered: { if (fileClipboardShortcutAllowed) AppState.deleteSelected() } }

    Shortcut { sequence: "Ctrl+T"; onActivated: AppState.createTab() }
    Shortcut { sequence: "Ctrl+W"; onActivated: AppState.closeTab(AppState.activeTabIndex) }
    Shortcut { sequence: "Ctrl+F"; onActivated: AppState.startSearch() }
    Shortcut { sequence: "Ctrl+H"; onActivated: AppState.showHidden = !AppState.showHidden }
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Sidebar (Full Height) ────────────────────────────
        LayoutComponents.Sidebar { Layout.fillHeight: true; Layout.preferredWidth: 256 }

        // ── Main Content Area ────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ── Tab Bar ──────────────────────────────────────
            Rectangle {
                id: tabBar
                Layout.fillWidth: true
                height: 34
                color: Theme.bg
                visible: AppState.tabs.length > 1

                Item {
                    id: tabTrack
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    clip: true

                    readonly property real spacing: 2
                    readonly property real tabWidth: Math.min(200, Math.max(64, (width - 42) / Math.max(1, AppState.tabs.length)))
                    readonly property real tabStep: tabWidth + spacing
                    property int pressedTabId: -1
                    property int draggedTabId: -1
                    property int dragSourceIndex: -1
                    property int dragTargetIndex: -1
                    property real dragGrabOffset: 0
                    property real dragMouseX: 0
                    property real pressRowX: 0
                    property bool dragActive: false
                    property var visualOrder: []

                    function clampIndex(value) {
                        return Math.max(0, Math.min(AppState.tabs.length - 1, value))
                    }

                    function appTabIds() {
                        var ids = []
                        for (var i = 0; i < AppState.tabs.length; i++)
                            ids.push(AppState.tabs[i].id)
                        return ids
                    }

                    function sameOrder(left, right) {
                        if (left.length !== right.length)
                            return false
                        for (var i = 0; i < left.length; i++) {
                            if (left[i] !== right[i])
                                return false
                        }
                        return true
                    }

                    function syncVisualOrder(force) {
                        if (dragActive && !force)
                            return
                        var ids = appTabIds()
                        if (force || !sameOrder(visualOrder, ids))
                            visualOrder = ids
                    }

                    function visualIndexForId(tabId) {
                        for (var i = 0; i < visualOrder.length; i++) {
                            if (visualOrder[i] === tabId)
                                return i
                        }
                        return AppState.tabIndexById(tabId)
                    }

                    function moveVisualOrder(fromIndex, toIndex) {
                        if (fromIndex < 0 || fromIndex >= visualOrder.length)
                            return
                        toIndex = clampIndex(toIndex)
                        if (fromIndex === toIndex)
                            return
                        var ids = visualOrder.slice()
                        var moved = ids.splice(fromIndex, 1)[0]
                        ids.splice(toIndex, 0, moved)
                        visualOrder = ids
                    }

                    function updateDragTarget() {
                        if (draggedTabId < 0)
                            return
                        var floatingX = dragMouseX - dragGrabOffset
                        dragTargetIndex = clampIndex(Math.round(floatingX / tabStep))
                    }

                    function visualXFor(tabIndex, tabId) {
                        var visualIndex = visualIndexForId(tabId)
                        if (visualIndex < 0)
                            visualIndex = tabIndex

                        if (!dragActive)
                            return visualIndex * tabStep

                        if (tabId === draggedTabId) {
                            var maxX = Math.max(0, (AppState.tabs.length - 1) * tabStep)
                            return Math.max(0, Math.min(maxX, dragMouseX - dragGrabOffset))
                        }

                        if (dragSourceIndex < dragTargetIndex
                                && visualIndex > dragSourceIndex
                                && visualIndex <= dragTargetIndex)
                            return (visualIndex - 1) * tabStep

                        if (dragTargetIndex < dragSourceIndex
                                && visualIndex >= dragTargetIndex
                                && visualIndex < dragSourceIndex)
                            return (visualIndex + 1) * tabStep

                        return visualIndex * tabStep
                    }

                    function resetDragState() {
                        pressedTabId = -1
                        draggedTabId = -1
                        dragSourceIndex = -1
                        dragTargetIndex = -1
                        dragGrabOffset = 0
                        dragMouseX = 0
                        pressRowX = 0
                        dragActive = false
                    }

                    function commitPendingMove() {
                        commitTabMoveTimer.stop()
                        var fromIndex = AppState.tabIndexById(commitTabMoveTimer.movingTabId)
                        if (fromIndex >= 0 && commitTabMoveTimer.targetIndex >= 0)
                            AppState.moveTab(fromIndex, commitTabMoveTimer.targetIndex)
                        commitTabMoveTimer.movingTabId = -1
                        commitTabMoveTimer.targetIndex = -1
                    }

                    Component.onCompleted: syncVisualOrder(true)

                    Connections {
                        target: AppState
                        function onTabsChanged() {
                            tabTrack.syncVisualOrder(false)
                        }
                    }

                    Timer {
                        id: commitTabMoveTimer
                        interval: 170
                        repeat: false
                        property int movingTabId: -1
                        property int targetIndex: -1

                        onTriggered: {
                            tabTrack.commitPendingMove()
                        }
                    }

                    Repeater {
                        model: AppState.tabs
                        
                        Item {
                            id: tabItem
                            readonly property int tabId: modelData.id
                            readonly property int currentActiveTabId: AppState.activeTabIndex >= 0 && AppState.activeTabIndex < AppState.tabs.length ? AppState.tabs[AppState.activeTabIndex].id : -1
                            readonly property bool activeTab: tabId === currentActiveTabId
                            readonly property bool draggedTab: tabTrack.draggedTabId === tabId && tabTrack.dragActive
                            x: tabTrack.visualXFor(index, tabId)
                            width: tabTrack.tabWidth
                            height: 28
                            y: Math.round((tabTrack.height - height) / 2)
                            z: tabTrack.draggedTabId === tabId ? 10 : 0

                            Behavior on x {
                                enabled: !(tabTrack.dragActive && tabTrack.draggedTabId === tabItem.tabId)
                                NumberAnimation { duration: 145; easing.type: Easing.OutCubic }
                            }

                            HoverHandler {
                                id: tabHover
                            }

                            Rectangle {
                                id: tabSurface
                                anchors.fill: parent
                                width: parent.width
                                height: parent.height
                                radius: 6
                                color: tabItem.activeTab ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                opacity: 1
                                scale: tabItem.draggedTab ? 1.015 : 1

                                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: Qt.rgba(1, 1, 1, 0.05)
                                    visible: tabHover.hovered && !tabItem.activeTab
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 6
                                    spacing: 6

                                    Text {
                                        text: {
                                            var p = modelData.path;
                                            if (p === AppState.homePath) return "Pasta pessoal";
                                            return p.split("/").pop() || "Raiz";
                                        }
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        color: tabItem.activeTab ? Theme.text : Theme.textTer
                                        font.pixelSize: 12
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 18
                                        Layout.preferredHeight: 18
                                        radius: 9
                                        visible: AppState.tabs.length > 1
                                        color: closeMouse.containsMouse
                                            ? Qt.rgba(1, 1, 1, 0.10)
                                            : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "×"
                                            color: closeMouse.containsMouse ? Theme.text : Theme.textTer
                                            font.pixelSize: 14
                                        }

                                        MouseArea {
                                            id: closeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: AppState.closeTabById(tabItem.tabId)
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: tabMouse
                                anchors {
                                    left: parent.left
                                    top: parent.top
                                    bottom: parent.bottom
                                    right: parent.right
                                    rightMargin: 26
                                }
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton

                                onPressed: function(mouse) {
                                    if (commitTabMoveTimer.running)
                                        tabTrack.commitPendingMove()
                                    tabTrack.syncVisualOrder(false)
                                    tabTrack.pressedTabId = tabItem.tabId
                                    tabTrack.draggedTabId = tabItem.tabId
                                    tabTrack.dragSourceIndex = tabTrack.visualIndexForId(tabItem.tabId)
                                    tabTrack.dragTargetIndex = tabTrack.dragSourceIndex
                                    tabTrack.dragGrabOffset = mouse.x
                                    tabTrack.pressRowX = tabItem.x + mouse.x
                                    tabTrack.dragMouseX = tabTrack.pressRowX
                                    tabTrack.dragActive = false
                                }

                                onPositionChanged: function(mouse) {
                                    if (!pressed)
                                        return
                                    tabTrack.dragMouseX = tabItem.x + mouse.x
                                    if (!tabTrack.dragActive
                                            && Math.abs(tabTrack.dragMouseX - tabTrack.pressRowX) > 6)
                                        tabTrack.dragActive = true
                                    if (tabTrack.dragActive)
                                        tabTrack.updateDragTarget()
                                }

                                onReleased: function(mouse) {
                                    var releasedTabId = tabItem.tabId
                                    var releasedSourceIndex = tabTrack.dragSourceIndex
                                    var releasedTargetIndex = tabTrack.dragTargetIndex
                                    var shouldMove = tabTrack.dragActive && releasedSourceIndex !== releasedTargetIndex

                                    if (!tabTrack.dragActive) {
                                        AppState.switchTabById(releasedTabId)
                                    } else if (shouldMove) {
                                        tabTrack.moveVisualOrder(releasedSourceIndex, releasedTargetIndex)
                                        commitTabMoveTimer.movingTabId = releasedTabId
                                        commitTabMoveTimer.targetIndex = releasedTargetIndex
                                        commitTabMoveTimer.restart()
                                    }
                                    tabTrack.resetDragState()
                                }

                                onCanceled: {
                                    tabTrack.resetDragState()
                                }
                            }
                        }
                    }
                    
                    CommonComponents.NavButton {
                        text: "+"
                        x: Math.min(parent.width - width, AppState.tabs.length * tabTrack.tabStep + 2)
                        y: Math.round((parent.height - height) / 2)
                        width: 28
                        height: 28
                        onClicked: AppState.createTab()
                    }
                }
                
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
            }

            // ── Toolbar ──────────────────────────────────────
            LayoutComponents.Toolbar { Layout.fillWidth: true }


            // ── View Area (Files) ────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // Área principal
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.bg

                    Loader {
                        anchors.fill: parent
                        sourceComponent: AppState.viewMode === "list" ? listComp : iconComp
                    }

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (AppState.searchActive)
                                return "Nenhum resultado para \"" + AppState.searchQuery + "\""
                            if (AppState.inTrashView)
                                return "Lixeira vazia"
                            if (AppState.isRecentPath(AppState.currentPath))
                                return "Nenhum item recente"
                            return "Pasta vazia"
                        }
                        color: Theme.textTer; font.pixelSize: 15
                        visible: !AppState.loadingDir && AppState.fileModel.count === 0 && AppState.loadError === ""
                    }

                    Text {
                        anchors.centerIn: parent
                        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.text.carregando"]) || "Loading..."); color: Theme.textTer; font.pixelSize: 15
                        visible: AppState.loadingDir
                    }

                    Text {
                        anchors.centerIn: parent
                        text: AppState.loadError; color: "#ff8b8b"; font.pixelSize: 15
                        visible: AppState.loadError !== ""
                    }

                    AstreaFiles.OperationProgressCard {
                        id: extractionProgressCard
                        anchors {
                            left: parent.left; leftMargin: 14
                            bottom: parent.bottom; bottomMargin: 14
                        }
                        width: Math.min(320, parent.width - 28)
                        readonly property bool archiveVisible: AppState.archiveExtractionRunning
                        readonly property bool fileOpVisible: AppState.fileOperationRunning && !archiveVisible
                        visible: fileOpVisible || archiveVisible
                        opacity: visible ? 1 : 0
                        z: 20
                        title: fileOpVisible
                            ? (AppState.fileOperationStatus || "Copiando...")
                            : (AppState.archiveExtractionStatus || "Extraindo...")
                        detail: fileOpVisible
                            ? AppState.fileOperationFileName
                            : AppState.archiveExtractionFileName
                        destination: (fileOpVisible ? AppState.fileOperationDestination : AppState.archiveExtractionDestination) !== ""
                            ? (fileOpVisible ? AppState.fileOperationDestination : AppState.archiveExtractionDestination).split("/").filter(Boolean).pop()
                            : ""
                        progress: fileOpVisible ? AppState.fileOperationProgress : AppState.archiveExtractionProgress
                        percent: fileOpVisible ? AppState.fileOperationPercent : AppState.archiveExtractionPercent
                        completedItems: fileOpVisible ? AppState.fileOperationDoneCount : AppState.archiveExtractionDoneCount
                        totalItems: fileOpVisible ? AppState.fileOperationTotalCount : AppState.archiveExtractionTotalCount
                        remainingText: fileOpVisible ? "" : AppState.archiveExtractionRemainingText
                        failed: fileOpVisible ? AppState.fileOperationError !== "" : AppState.archiveExtractionError !== ""
                        panelColor: Theme.panel
                        borderColor: Theme.border
                        primaryTextColor: Theme.text
                        secondaryTextColor: Theme.textTer
                        trackColor: Theme.hover
                        fillColor: Theme.text
                        errorColor: "#ff8b8b"
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                }

                // Painel de preview
                LayoutComponents.PreviewPanel {
                    width: AppState.showPreview ? 220 : 0
                    Layout.preferredWidth: AppState.showPreview ? 220 : 0
                    Layout.minimumWidth: AppState.showPreview ? 220 : 0
                    Layout.maximumWidth: AppState.showPreview ? 220 : 0
                    Layout.fillHeight: true
                    visible: AppState.showPreview
                }
            }

            // ── Status bar ───────────────────────────────────
            LayoutComponents.StatusBar { Layout.fillWidth: true }
        }
    }

    Component { id: listComp; ViewComponents.FileListView {} }
    Component { id: iconComp; ViewComponents.FileIconView {} }


    Popup {
        id: pasteConflictPopup
        anchors.centerIn: parent
        width: 420
        modal: true
        focus: true
        padding: 0
        closePolicy: Popup.NoAutoClose
        visible: AppState.pasteConflictVisible

        background: Rectangle {
            radius: 14
            color: Theme.panel
            border.color: Theme.border
            border.width: 1
        }

        contentItem: Column {
            spacing: 12
            padding: 16

            Text {
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.text.arquivos_com_o_mesmo_nome"]) || "Files with the same name")
                color: Theme.text
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: Theme.text
                font.pixelSize: 12
                text: AppState.pasteConflictItems.length === 1
                      ? "Ja existe um item com esse nome no destino. O que voce quer fazer?"
                      : "Ja existem " + AppState.pasteConflictItems.length + " itens com o mesmo nome no destino. O que voce quer fazer com todos eles?"
            }

            TextField {
                visible: AppState.pasteConflictItems.length === 1
                width: parent.width
                text: AppState.pendingPasteRename
                color: Theme.text
                placeholderText: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.placeholderText.novo_nome"]) || "New name")
                selectByMouse: true
                background: Rectangle {
                    radius: 8
                    color: Theme.bg
                    border.color: parent.activeFocus ? Theme.accent : Theme.border
                    border.width: 1
                }
                onTextChanged: AppState.pendingPasteRename = text
                onAccepted: AppState.renamePasteConflict(text)
            }

            Rectangle {
                width: parent.width
                height: Math.min(conflictColumn.implicitHeight + 12, 140)
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 6
                    contentWidth: width
                    contentHeight: conflictColumn.implicitHeight
                    clip: true

                    Column {
                        id: conflictColumn
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: AppState.pasteConflictItems

                            Text {
                                width: conflictColumn.width
                                text: modelData
                                color: Theme.textTer
                                font.pixelSize: 12
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                }
            }

            Row {
                spacing: 8

                DialogButton {
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.label.cancelar"]) || "Cancel")
                    onClicked: AppState.cancelPasteConflict()
                }

                DialogButton {
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.label.ignorar"]) || "Skip")
                    onClicked: AppState.resolvePasteConflict("skip")
                }

                DialogButton {
                    visible: AppState.pasteConflictItems.length === 1
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.label.renomear"]) || "Rename")
                    onClicked: AppState.renamePasteConflict(AppState.pendingPasteRename)
                }

                DialogButton {
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.label.manter_ambos"]) || "Keep both")
                    emphasized: true
                    onClicked: AppState.resolvePasteConflict("keep-both")
                }

                DialogButton {
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.label.mesclar"]) || "Merge")
                    emphasized: true
                    onClicked: AppState.resolvePasteConflict("merge")
                }
            }
        }
    }

    Popup {
        id: archivePasswordPopup
        anchors.centerIn: parent
        width: 380
        modal: true
        focus: true
        padding: 0
        closePolicy: Popup.NoAutoClose
        visible: AppState.archivePasswordPromptVisible

        onVisibleChanged: {
            if (visible) {
                archivePasswordField.text = ""
                archivePasswordField.forceActiveFocus()
            }
        }

        background: Rectangle {
            radius: 14
            color: Theme.panel
            border.color: Theme.border
            border.width: 1
        }

        contentItem: Column {
            spacing: 12
            padding: 16

            Text {
                text: "Arquivo protegido por senha"
                color: Theme.text
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: Theme.textSec
                font.pixelSize: 12
                text: "Digite a senha para extrair " + AppState.archiveExtractionFileName + "."
            }

            TextField {
                id: archivePasswordField
                width: parent.width
                text: AppState.archivePassword
                color: Theme.text
                echoMode: TextInput.Password
                placeholderText: "Senha"
                placeholderTextColor: Theme.textTer
                selectByMouse: true
                font.pixelSize: 13
                background: Rectangle {
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.color: archivePasswordField.activeFocus ? Theme.accent : Theme.border
                    border.width: 1
                }
                onTextChanged: AppState.archivePassword = text
                onAccepted: AppState.submitArchivePassword(text)
            }

            Text {
                visible: AppState.archivePasswordError !== ""
                width: parent.width
                wrapMode: Text.WordWrap
                color: "#ff9a9a"
                font.pixelSize: 12
                text: AppState.archivePasswordError
            }

            Row {
                spacing: 8

                DialogButton {
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.label.cancelar"]) || "Cancel")
                    onClicked: AppState.cancelArchivePassword()
                }

                DialogButton {
                    label: "Extrair"
                    emphasized: true
                    onClicked: AppState.submitArchivePassword(archivePasswordField.text)
                }
            }
        }
    }

    Popup {
        id: archiveConflictPopup
        anchors.centerIn: parent
        width: 430
        modal: true
        focus: true
        padding: 0
        closePolicy: Popup.NoAutoClose
        visible: AppState.archiveConflictVisible

        background: Rectangle {
            radius: 14
            color: Theme.panel
            border.color: Theme.border
            border.width: 1
        }

        contentItem: Column {
            spacing: 12
            padding: 16

            Text {
                text: "Destino ja existe"
                color: Theme.text
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: Theme.textSec
                font.pixelSize: 12
                text: "Ja existe uma pasta chamada " + AppState.archiveConflictName + ". Voce pode mesclar o conteudo, substituir a pasta atual ou manter ambos."
            }

            Rectangle {
                width: parent.width
                height: 38
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                Text {
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: 10
                    }
                    text: AppState.archiveConflictDestination
                    color: Theme.textTer
                    font.pixelSize: 12
                    elide: Text.ElideMiddle
                }
            }

            Row {
                spacing: 8

                DialogButton {
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.label.cancelar"]) || "Cancel")
                    onClicked: AppState.cancelArchiveConflict()
                }

                DialogButton {
                    label: "Manter ambos"
                    onClicked: AppState.submitArchiveConflict("keep-both")
                }

                DialogButton {
                    label: "Mesclar"
                    emphasized: true
                    onClicked: AppState.submitArchiveConflict("merge")
                }

                DialogButton {
                    label: "Substituir"
                    danger: true
                    onClicked: AppState.submitArchiveConflict("overwrite")
                }
            }
        }
    }

    component DialogButton: Rectangle {
        property string label: ""
        property bool emphasized: false
        property bool danger: false
        signal clicked()

        width: Math.max(92, buttonLabel.implicitWidth + 24)
        height: 34
        radius: 8
        color: danger ? Qt.rgba(0.8, 0.24, 0.24, buttonMouse.containsMouse ? 0.35 : 0.22)
                      : emphasized ? (buttonMouse.containsMouse ? Theme.accentSoft : Theme.accentLight)
                      : (buttonMouse.containsMouse ? Theme.hover : Theme.toolbar)

        Text {
            id: buttonLabel
            anchors.centerIn: parent
            width: parent.width - 12
            text: parent.label
            color: Theme.text
            font.pixelSize: 12
            font.weight: parent.emphasized || parent.danger ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    Popup {
        id: networkConnectPopup
        anchors.centerIn: parent
        width: 440
        modal: true
        focus: true
        padding: 0
        closePolicy: AppState.networkConnecting ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)
        visible: AppState.networkConnectVisible

        onVisibleChanged: {
            if (!visible && AppState.networkConnectVisible && !AppState.networkConnecting)
                AppState.hideNetworkConnectDialog()
        }

        background: Rectangle {
            radius: 14
            color: Theme.panel
            border.color: Theme.border
            border.width: 1
        }

        contentItem: Column {
            spacing: 12
            padding: 16

            Text {
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.text.conectar_ao_servidor"]) || "Connect to server")
                color: Theme.text
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: Theme.textSec
                font.pixelSize: 12
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.text.network_address_help"]) || "Use an address like smb://server/share or sftp://user@host/path.")
            }

            TextField {
                id: networkAddressField
                width: parent.width
                text: AppState.networkAddress
                enabled: !AppState.networkConnecting
                color: Theme.text
                placeholderText: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.placeholder.network_address"]) || "smb://server/share")
                placeholderTextColor: Theme.textTer
                selectByMouse: true
                font.pixelSize: 13
                background: Rectangle {
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.color: networkAddressField.activeFocus ? Theme.accent : Theme.border
                    border.width: 1
                }
                onTextChanged: AppState.networkAddress = text
                onAccepted: AppState.connectToNetwork()
                Component.onCompleted: {
                    if (AppState.networkAddress === "")
                        AppState.networkAddress = "smb://"
                }
            }

            Text {
                visible: AppState.networkError !== ""
                width: parent.width
                wrapMode: Text.WordWrap
                color: "#ff9a9a"
                font.pixelSize: 12
                text: AppState.networkError
            }

            Row {
                spacing: 8

                Rectangle {
                    width: 96
                    height: 32
                    radius: 8
                    color: cancelNetworkMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: Theme.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.label.cancelar"]) || "Cancel")
                        color: Theme.text
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: cancelNetworkMouse
                        anchors.fill: parent
                        enabled: !AppState.networkConnecting
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: AppState.hideNetworkConnectDialog()
                    }
                }

                Rectangle {
                    width: 96
                    height: 32
                    radius: 8
                    color: connectNetworkMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: AppState.networkConnecting ? "Conectando..." : "Conectar"
                        color: "white"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: connectNetworkMouse
                        anchors.fill: parent
                        enabled: !AppState.networkConnecting
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: AppState.connectToNetwork()
                    }
                }
            }
        }
    }
}
