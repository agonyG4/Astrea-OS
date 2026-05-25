import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.impl 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import Quickshell.Io
import "../.."
import "../../AstreaComponents" as UI
import "../../AstreaFiles" as AstreaFiles
import "../../AstreaI18n" as AstreaI18n

Rectangle {
    id: toolbar
    height: 56
    color: Theme.bg
    readonly property Item overlayParent: Window.window && Window.window.contentItem
                                          ? Window.window.contentItem
                                          : toolbar
    readonly property int locationFieldHeight: 38
    readonly property int locationFieldRadius: 12
    property bool editingPath: false
    property int selectedSuggestionIndex: -1
    readonly property bool searching: AppState.searchVisible || AppState.searchActive
    property bool emptyTrashConfirmVisible: false
    property int suggestionRequestId: 0

    // ── Helpers ──────────────────────────────────────────────────
    function normalizePathInput(text) {
        var value = (text || "").trim()
        if (!value) return ""
        if (value === "~") return AppState.homePath
        if (value.indexOf("~/") === 0) return AppState.homePath + "/" + value.slice(2)
        if (value.charAt(0) !== "/") return (AppState.currentPath || AppState.homePath).replace(/\/$/, "") + "/" + value
        return value
    }

    function startPathEditing(initialPath) {
        if (searching)
            return
        editingPath = true
        pathField.text = initialPath || AppState.currentPath
        Qt.callLater(function() {
            pathField.forceActiveFocus()
            pathField.selectAll()
        })
        refreshSuggestions()
    }

    function focusSearchField(selectText) {
        Qt.callLater(function() {
            searchField.forceActiveFocus()
            if (selectText)
                searchField.selectAll()
        })
    }

    function stopPathEditing() {
        focusLossTimer.stop()
        pathField.focus = false
        editingPath = false
        selectedSuggestionIndex = -1
        suggestionsPopup.close()
        pathSuggestions.clear()
    }

    function stopSearchMode() {
        if (AppState.searchActive)
            AppState.clearSearch()
        else
            AppState.hideSearch()
    }

    function commitPathEditing() {
        if (selectedSuggestionIndex >= 0 && selectedSuggestionIndex < pathSuggestions.count)
            pathField.text = pathSuggestions.get(selectedSuggestionIndex).path

        var path = normalizePathInput(pathField.text)
        if (!path) {
            stopPathEditing()
            return
        }

        pathField.text = path
        AppState.navigateTo(path)
        stopPathEditing()
    }

    function refreshSuggestions() {
        var raw = normalizePathInput(pathField.text)
        var basePath = raw
        var prefix = ""

        if (!raw) {
            basePath = AppState.currentPath || AppState.homePath
        } else if (raw.charAt(raw.length - 1) !== "/") {
            var slashIndex = raw.lastIndexOf("/")
            if (slashIndex >= 0) {
                basePath = slashIndex === 0 ? "/" : raw.slice(0, slashIndex)
                prefix = raw.slice(slashIndex + 1)
            } else {
                basePath = AppState.currentPath || AppState.homePath
                prefix = raw
            }
        }

        suggestionRequestId += 1
        suggestionProcess.command = [
            "python3",
            AppState.helperPath,
            "suggest-dirs",
            basePath,
            prefix,
            "--request-id", String(suggestionRequestId)
        ]
        suggestionProcess.running = false
        suggestionProcess.running = true
    }

    function moveSuggestionSelection(step) {
        if (pathSuggestions.count === 0) return
        if (!suggestionsPopup.visible) suggestionsPopup.open()

        var nextIndex = selectedSuggestionIndex
        if (nextIndex < 0)
            nextIndex = step > 0 ? 0 : pathSuggestions.count - 1
        else
            nextIndex = (nextIndex + step + pathSuggestions.count) % pathSuggestions.count

        selectedSuggestionIndex = nextIndex
        suggestionsList.currentIndex = nextIndex
        suggestionsList.positionViewAtIndex(nextIndex, ListView.Contain)
    }

    function setSortField(field) {
        if (AppState.sortField === field) {
            AppState.sortAsc = !AppState.sortAsc
            return
        }
        AppState.sortField = field
        AppState.sortAsc = true
    }

    // ── Layout ───────────────────────────────────────────────────
    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        spacing: 6

        // ── Nav Buttons ─────────────────────────────────────────
        UI.DualButton {
            Layout.preferredWidth: 88
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignVCenter
            controlWidth: 88
            controlHeight: 40
            segmentWidth: 44
            leftIconText: "‹"
            rightIconText: "›"
            iconSize: 25
            leftIconOutline: true
            rightIconOutline: true
            iconOutlineSize: 30
            iconOutlineRadius: 15
            iconOutlineBorderWidth: 0
            iconOutlineFillColor: Qt.rgba(1, 1, 1, 0.13)
            iconOutlinePressedFillColor: Qt.rgba(1, 1, 1, 0.19)
            separatorVisible: true
            separatorInset: 10
            separatorColor: Qt.rgba(1, 1, 1, 0.12)
            leftEnabled: AppState.historyIdx > 0
            rightEnabled: AppState.historyIdx < AppState.history.length - 1
            onLeftClicked: AppState.goBack()
            onRightClicked: AppState.goForward()
        }

        // ── Location Pill ───────────────────────────────────────
        Rectangle {
            id: editPathPill
            Layout.fillWidth: true
            height: toolbar.locationFieldHeight
            visible: toolbar.editingPath && !toolbar.searching
            radius: toolbar.locationFieldRadius
            color: pathField.activeFocus
                ? Qt.rgba(1, 1, 1, 0.07)
                : Qt.rgba(1, 1, 1, 0.05)
            border.color: pathField.activeFocus
                ? Qt.rgba(0.25, 0.55, 1.0, 0.72)
                : Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 100 } }
            Behavior on border.color { ColorAnimation { duration: 100 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                spacing: 4

                TextField {
                    id: pathField
                    Layout.fillWidth: true
                    height: parent.height
                    color: Theme.text
                    font.pixelSize: 13
                    selectByMouse: true
                    placeholderText: AppState.homePath
                    placeholderTextColor: Theme.textTer
                    verticalAlignment: TextInput.AlignVCenter
                    leftPadding: 0
                    rightPadding: 0
                    background: null

                    onTextChanged: toolbar.refreshSuggestions()
                    onAccepted: toolbar.commitPathEditing()
                    onActiveFocusChanged: {
                        if (!activeFocus && toolbar.editingPath)
                            focusLossTimer.restart()
                    }

                    Keys.onPressed: function(event) {
                        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_A) {
                            pathField.selectAll()
                            event.accepted = true
                            return
                        }
                        if (event.key === Qt.Key_Down) {
                            toolbar.moveSuggestionSelection(1)
                            event.accepted = true
                            return
                        }
                        if (event.key === Qt.Key_Up) {
                            toolbar.moveSuggestionSelection(-1)
                            event.accepted = true
                            return
                        }
                        if (event.key === Qt.Key_Tab) {
                            if (toolbar.selectedSuggestionIndex >= 0 && toolbar.selectedSuggestionIndex < pathSuggestions.count) {
                                pathField.text = pathSuggestions.get(toolbar.selectedSuggestionIndex).path + "/"
                                pathField.cursorPosition = pathField.text.length
                                toolbar.selectedSuggestionIndex = -1
                                toolbar.refreshSuggestions()
                                event.accepted = true
                            }
                            return
                        }
                        if (event.key === Qt.Key_Escape) {
                            toolbar.stopPathEditing()
                            event.accepted = true
                        }
                    }
                }

                Rectangle {
                    id: pathDismissBg
                    width: 20
                    height: 20
                    radius: 10
                    color: pathDismissMouse.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.12)
                        : "transparent"

                    Behavior on color { ColorAnimation { duration: 80 } }

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: Theme.textSec
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: pathDismissMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: toolbar.stopPathEditing()
                    }
                }
            }
        }

        Rectangle {
            id: locationPill
            Layout.fillWidth: true
            height: toolbar.locationFieldHeight
            visible: !toolbar.editingPath || toolbar.searching
            opacity: visible ? 1 : 0
            radius: toolbar.locationFieldRadius
            color: toolbar.searching
                ? Qt.rgba(1, 1, 1, 0.07)
                : pillHover.hovered
                    ? Qt.rgba(1, 1, 1, 0.07)
                    : Qt.rgba(1, 1, 1, 0.04)
            border.color: toolbar.searching
                ? Qt.rgba(0.25, 0.55, 1.0, 0.72)
                : Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 100 } }
            Behavior on border.color { ColorAnimation { duration: 100 } }

            MouseArea {
                anchors.fill: parent
                enabled: !toolbar.editingPath && !toolbar.searching
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.IBeamCursor
                onClicked: toolbar.startPathEditing(AppState.currentPath)
            }

            HoverHandler {
                id: pillHover
                enabled: !toolbar.editingPath && !toolbar.searching
            }

            // ── Breadcrumb row (display mode) ─────────────────
            Flickable {
                id: breadcrumbFlick
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 8
                    rightMargin: 8
                    top: parent.top
                    bottom: parent.bottom
                }
                visible: !toolbar.editingPath && !toolbar.searching
                clip: true
                contentWidth: breadcrumbRow.width
                contentHeight: height
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick
                interactive: contentWidth > width

                Row {
                    id: breadcrumbRow
                    height: parent.height
                    spacing: 4

                    Repeater {
                        model: AppState.breadcrumbParts

                        Row {
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                visible: index > 0
                                text: "/"
                                color: Theme.textTer
                                opacity: 0.72
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                height: 24
                                radius: 12
                                color: {
                                    if (crumbMouse.containsMouse)
                                        return index === AppState.breadcrumbParts.length - 1
                                            ? Qt.rgba(1, 1, 1, 0.18)
                                            : Qt.rgba(1, 1, 1, 0.12)
                                    return index === AppState.breadcrumbParts.length - 1
                                        ? Qt.rgba(1, 1, 1, 0.14)
                                        : Qt.rgba(1, 1, 1, 0.07)
                                }
                                border.width: 1
                                border.color: index === AppState.breadcrumbParts.length - 1
                                    ? Qt.rgba(1, 1, 1, 0.16)
                                    : Qt.rgba(1, 1, 1, 0.10)

                                Behavior on color { ColorAnimation { duration: 100 } }
                                Behavior on border.color { ColorAnimation { duration: 100 } }

                                width: crumbLabel.width + 18

                                Text {
                                    id: crumbLabel
                                    anchors.centerIn: parent
                                    text: {
                                        var label = modelData.label
                                        if (label === "/") return "/"
                                        return label
                                    }
                                    color: index === AppState.breadcrumbParts.length - 1
                                        ? Theme.text
                                        : Theme.textSec
                                    font {
                                        pixelSize: 12
                                        weight: index === AppState.breadcrumbParts.length - 1
                                            ? Font.DemiBold : Font.Normal
                                    }
                                }

                                MouseArea {
                                    id: crumbMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: AppState.navigateTo(modelData.path)
                                }
                            }
                        }
                    }
                }

                Component.onCompleted: contentX = Math.max(0, contentWidth - width)
                onContentWidthChanged: contentX = Math.max(0, contentWidth - width)
                onWidthChanged: contentX = Math.max(0, contentWidth - width)
            }

            // ── Search field ──────────────────────────────────
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                spacing: 6
                visible: toolbar.searching

                Text {
                    text: "⌕"
                    color: Theme.textTer
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    Layout.alignment: Qt.AlignVCenter
                }

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    height: parent.height
                    text: AppState.searchQuery
                    color: Theme.text
                    font.pixelSize: 13
                    selectByMouse: true
                    background: null
                    placeholderText: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.toolbar.placeholderText.buscar_na_pasta_atual"]) || "Search current folder")
                    placeholderTextColor: Theme.textTer
                    verticalAlignment: TextInput.AlignVCenter
                    leftPadding: 0
                    rightPadding: 0

                    onTextChanged: AppState.searchQuery = text
                    onAccepted: AppState.submitSearch(text)
                    onActiveFocusChanged: {
                        if (!activeFocus && AppState.searchVisible)
                            searchFocusLossTimer.restart()
                    }

                    Keys.onPressed: function(event) {
                        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_A) {
                            searchField.selectAll()
                            event.accepted = true
                            return
                        }
                        if (event.key === Qt.Key_Escape) {
                            toolbar.stopSearchMode()
                            event.accepted = true
                        }
                    }
                }

                Rectangle {
                    width: 20; height: 20; radius: 10
                    color: searchDismissHover.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    visible: toolbar.searching

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: Theme.textSec
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: searchDismissHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: toolbar.stopSearchMode()
                    }
                }
            }

        }

        Rectangle {
            id: restoreTrashBtn
            visible: AppState.inTrashView
            implicitWidth: restoreTrashLabel.implicitWidth + 20
            height: 32
            radius: 8
            opacity: AppState.selectedFiles.length > 0 ? 1.0 : 0.45
            color: restoreTrashMouse.containsMouse && AppState.selectedFiles.length > 0
                ? Qt.rgba(0.25, 0.62, 0.95, 0.20)
                : Qt.rgba(0.25, 0.62, 0.95, 0.10)

            Behavior on color { ColorAnimation { duration: 80 } }

            Text {
                id: restoreTrashLabel
                anchors.centerIn: parent
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.toolbar.text.restaurar"]) || "Restore")
                color: "#9fd0ff"
                font.pixelSize: 12
                font.weight: Font.Normal
            }

            MouseArea {
                id: restoreTrashMouse
                anchors.fill: parent
                enabled: AppState.selectedFiles.length > 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: AppState.restoreSelected()
            }
        }

        Rectangle {
            id: emptyTrashBtn
            visible: AppState.inTrashView
            implicitWidth: emptyTrashLabel.implicitWidth + 20
            height: 32
            radius: 8
            color: emptyTrashMouse.containsMouse
                ? Qt.rgba(0.82, 0.22, 0.22, 0.18)
                : Qt.rgba(0.82, 0.22, 0.22, 0.10)

            Behavior on color { ColorAnimation { duration: 80 } }

            Text {
                id: emptyTrashLabel
                anchors.centerIn: parent
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.toolbar.text.esvaziar_lixeira"]) || "Empty Trash")
                color: "#ffb3b3"
                font.pixelSize: 12
                font.weight: Font.Normal
            }

            MouseArea {
                id: emptyTrashMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: toolbar.emptyTrashConfirmVisible = true
            }
        }

        // ── Settings / View toggle button ───────────────────────
        Rectangle {
            id: settingsBtn
            width: 32; height: 32
            radius: 8
            color: settingsBtnMouse.containsMouse
                ? Qt.rgba(1, 1, 1, 0.1)
                : "transparent"

            Behavior on color { ColorAnimation { duration: 80 } }

            Text {
                anchors.centerIn: parent
                text: "⋮"
                color: settingsBtnMouse.containsMouse ? Theme.text : Theme.textSec
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: settingsBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const pt = toolbar.mapToItem(settingsMenu,
                                                 toolbar.width - settingsMenu.menuWidth - 10,
                                                 toolbar.height + 2)
                    settingsMenu.openAt(pt.x, pt.y)
                }
            }
        }
    }

    // ── Autocomplete dropdown ─────────────────────────────────────
    Popup {
        id: suggestionsPopup
        modal: false
        focus: false
        padding: 5
        width: locationPill.width
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        x: {
            var point = locationPill.mapToItem(toolbar, 0, 0)
            return point.x
        }
        y: toolbar.height + 4
        visible: toolbar.editingPath && pathSuggestions.count > 0

        background: Rectangle {
            radius: 10
            color: Qt.rgba(0.14, 0.14, 0.16, 0.97)
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1
        }

        contentItem: ListView {
            id: suggestionsList
            implicitHeight: Math.min(contentHeight, 280)
            model: pathSuggestions
            clip: true
            keyNavigationWraps: true
            spacing: 1

            delegate: Rectangle {
                width: suggestionsList.width
                height: 30
                radius: 7
                color: index === toolbar.selectedSuggestionIndex
                    ? Qt.rgba(0.25, 0.55, 1.0, 0.22)
                    : suggItemMouse.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.07)
                        : "transparent"

                Behavior on color { ColorAnimation { duration: 70 } }

                Row {
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: 10
                        rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 8

                    Text {
                        text: "/"
                        color: Theme.textTer
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: model.path.split("/").pop()
                        color: index === toolbar.selectedSuggestionIndex ? Theme.text : Theme.textSec
                        font { pixelSize: 12; weight: Font.Normal }

                        width: parent.width - 20
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: suggItemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        toolbar.selectedSuggestionIndex = index
                        suggestionsList.currentIndex = index
                    }
                    onClicked: {
                        toolbar.selectedSuggestionIndex = index
                        pathField.text = model.path
                        toolbar.commitPathEditing()
                    }
                }
            }
        }
    }

    Popup {
        id: emptyTrashPopup
        anchors.centerIn: Overlay.overlay
        modal: true
        focus: true
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        visible: toolbar.emptyTrashConfirmVisible
        onClosed: toolbar.emptyTrashConfirmVisible = false

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
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.toolbar.text.esvaziar_lixeira_3"]) || "Empty Trash?")
                color: Theme.text
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Text {
                width: 320
                wrapMode: Text.WordWrap
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.toolbar.text.todos_os_itens_da_lixeira_serao_removidos_perman"]) || "All items in the trash will be permanently removed.")
                color: Theme.textSec
                font.pixelSize: 12
            }

            Row {
                spacing: 8

                Rectangle {
                    width: 88
                    height: 34
                    radius: 8
                    color: cancelTrashMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06)

                    Text {
                        anchors.centerIn: parent
                        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.toolbar.text.cancelar"]) || "Cancel")
                        color: Theme.text
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: cancelTrashMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: emptyTrashPopup.close()
                    }
                }

                Rectangle {
                    width: 128
                    height: 34
                    radius: 8
                    color: confirmTrashMouse.containsMouse ? Qt.rgba(0.82, 0.22, 0.22, 0.28) : Qt.rgba(0.82, 0.22, 0.22, 0.20)

                    Text {
                        anchors.centerIn: parent
                        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.toolbar.text.esvaziar"]) || "Empty")
                        color: "#ffd6d6"
                        font.pixelSize: 12
                        font.weight: Font.Normal
                    }

                    MouseArea {
                        id: confirmTrashMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            emptyTrashPopup.close()
                            AppState.emptyTrash()
                        }
                    }
                }
            }
        }
    }

    // ── Settings panel popup ──────────────────────────────────────
    AstreaFiles.FileContextMenu {
        id: settingsMenu
        parent: toolbar.overlayParent
        anchors.fill: parent
        menuWidth: 230

        Column {
            spacing: 2

            // Section label
            Text {
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["explorer.toolbar.view"]) || "VIEW")
                color: Theme.textTer
                font { pixelSize: 9; weight: Font.DemiBold; letterSpacing: 1.0 }
                leftPadding: 10
                topPadding: 4
                bottomPadding: 2
            }

            SettingsAction {
                label: AppState.viewMode === "list" ? "Modo: Lista" : "Modo: Ícones"
                icon: AppState.viewMode === "list" ? "☰" : "⊞"
                onTriggered: {
                    AppState.viewMode = AppState.viewMode === "list" ? "icon" : "list"
                }
            }

            SettingsAction {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.toolbar.label.painel_de_preview"]) || "Preview Panel")
                icon: AppState.showPreview ? "◉" : "○"
                checked: AppState.showPreview
                onTriggered: AppState.showPreview = !AppState.showPreview
            }

            Item { width: parent.width; height: 6 }
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }

            Text {
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["explorer.toolbar.sorting"]) || "SORTING")
                color: Theme.textTer
                font { pixelSize: 9; weight: Font.DemiBold; letterSpacing: 1.0 }
                leftPadding: 10
                topPadding: 4
                bottomPadding: 2
            }

            Repeater {
                model: [
                    { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.toolbar.label.por_nome"]) || "By Name"),         field: "name" },
                    { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.toolbar.label.por_data"]) || "By Date"),          field: "date" },
                    { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.toolbar.label.por_tamanho"]) || "By Size"),       field: "size" },
                    { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.toolbar.label.por_tipo"]) || "By Kind"),          field: "kind" }
                ]
                SettingsAction {
                    label: modelData.label + (AppState.sortField === modelData.field ? (AppState.sortAsc ? "  ↑" : "  ↓") : "")
                    icon: AppState.sortField === modelData.field ? "●" : "○"
                    checked: AppState.sortField === modelData.field
                    onTriggered: toolbar.setSortField(modelData.field)
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }

            Text {
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["explorer.toolbar.options"]) || "OPTIONS")
                color: Theme.textTer
                font { pixelSize: 9; weight: Font.DemiBold; letterSpacing: 1.0 }
                leftPadding: 10
                topPadding: 4
                bottomPadding: 2
            }

            SettingsAction {
                label: AppState.sortAsc ? "Ordem crescente" : "Ordem decrescente"
                icon: AppState.sortAsc ? "↑" : "↓"
                onTriggered: AppState.sortAsc = !AppState.sortAsc
            }

            SettingsAction {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.toolbar.label.mostrar_ocultos"]) || "Show Hidden Files")
                icon: AppState.showHidden ? "◉" : "○"
                checked: AppState.showHidden
                onTriggered: AppState.showHidden = !AppState.showHidden
            }

            SettingsAction {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.toolbar.label.pastas_primeiro"]) || "Folders First")
                icon: AppState.foldersFirst ? "◉" : "○"
                checked: AppState.foldersFirst
                onTriggered: AppState.foldersFirst = !AppState.foldersFirst
            }

            SettingsAction {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["explorer.toolbar.separate_sections"]) || "Separate by sections")
                icon: AppState.groupingEnabled ? "◉" : "○"
                checked: AppState.groupingEnabled
                onTriggered: AppState.groupingEnabled = !AppState.groupingEnabled
            }

            SettingsAction {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.explorer.components.layout.toolbar.label.reset_zoom"]) || "Reset Zoom")
                icon: "⊙"
                isEnabled: AppState.zoomLevel !== 1.0
                onTriggered: AppState.resetZoom()
            }

            Item { height: 4; width: 1 }
        }
    }

    Connections {
        target: AppState
        function onSearchVisibleChanged() {
            searchField.text = AppState.searchQuery
            if (AppState.searchVisible) {
                editingPath = false
                selectedSuggestionIndex = -1
                suggestionsPopup.close()
                pathSuggestions.clear()
                focusSearchField(true)
            }
        }

        function onSearchActiveChanged() {
            searchField.text = AppState.searchQuery
            if (AppState.searchActive)
                focusSearchField(false)
        }

        function onSearchQueryChanged() {
            if (searchField.text !== AppState.searchQuery)
                searchField.text = AppState.searchQuery
        }
    }

    // ── Timer: focus-loss debounce ────────────────────────────────
    Timer {
        id: focusLossTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (toolbar.editingPath && !pathField.activeFocus && !suggestionsPopup.activeFocus)
                toolbar.stopPathEditing()
        }
    }

    Timer {
        id: searchFocusLossTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (AppState.searchVisible && !searchField.activeFocus)
                AppState.hideSearch()
        }
    }

    Component.onCompleted: {
        searchField.text = AppState.searchQuery
        if (toolbar.searching)
            focusSearchField(!AppState.searchActive)
    }

    onEditingPathChanged: {
        if (!editingPath) {
            selectedSuggestionIndex = -1
            suggestionsPopup.close()
            pathSuggestions.clear()
        }
    }

    onSearchingChanged: {
        if (searching) {
            editingPath = false
            selectedSuggestionIndex = -1
            suggestionsPopup.close()
            pathSuggestions.clear()
            focusSearchField(!AppState.searchActive)
        }
    }

    onVisibleChanged: {
        if (!visible)
            suggestionsPopup.close()
    }

    // ── Bottom border ─────────────────────────────────────────────
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }

    // ── Data / Process ────────────────────────────────────────────
    ListModel { id: pathSuggestions }

    Process {
        id: suggestionProcess
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n")
                var token = ""
                if (lines.length > 0 && lines[0].indexOf("__request_id__:") === 0)
                    token = lines.shift().slice("__request_id__:".length)
                if (token !== "" && Number(token) !== toolbar.suggestionRequestId)
                    return
                pathSuggestions.clear()
                toolbar.selectedSuggestionIndex = -1
                for (var i = 0; i < lines.length; i++) {
                    var entry = lines[i].trim()
                    if (entry)
                        pathSuggestions.append({ path: entry })
                }
                if (toolbar.editingPath && pathSuggestions.count > 0) {
                    suggestionsPopup.open()
                } else {
                    suggestionsPopup.close()
                }
            }
        }
        onExited: function() {
            if (!toolbar.editingPath)
                suggestionsPopup.close()
        }
    }

    // ── SettingsAction component ──────────────────────────────────
    component SettingsAction: Item {
        id: saRoot
        property string label: ""
        property string icon: ""
        property bool checked: false
        property bool isEnabled: true
        signal triggered()

        width: settingsMenu.menuWidth - 12
        height: 30

        Rectangle {
            anchors.fill: parent
            radius: 7
            color: sa_mouse.containsMouse && saRoot.isEnabled
                ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: 70 } }
        }

        Row {
            anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 8

            Text {
                text: saRoot.icon
                color: saRoot.checked ? Theme.accent : Theme.textSec
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: saRoot.label
                color: saRoot.isEnabled ? Theme.text : Theme.textTer
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: sa_mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: saRoot.isEnabled
            cursorShape: saRoot.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: saRoot.triggered()
        }
    }
}
