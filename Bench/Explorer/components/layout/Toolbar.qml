import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.impl 2.15
import QtQuick.Layouts 1.15
import Quickshell.Io
import "../.."
import "../common" as CommonComponents

Rectangle {
    id: toolbar
    height: 46
    color: Theme.toolbar
    property bool editingPath: false
    property int selectedSuggestionIndex: -1

    // ── Helpers ──────────────────────────────────────────────────
    function normalizePathInput(text) {
        var value = (text || "").trim()
        if (!value) return ""
        if (value === "~") return "/home/agony"
        if (value.indexOf("~/") === 0) return "/home/agony/" + value.slice(2)
        if (value.charAt(0) !== "/") return (AppState.currentPath || "/home/agony").replace(/\/$/, "") + "/" + value
        return value
    }

    function startPathEditing(initialPath) {
        editingPath = true
        pathField.text = initialPath || AppState.currentPath
        Qt.callLater(function() {
            pathField.forceActiveFocus()
            pathField.selectAll()
        })
        refreshSuggestions()
    }

    function stopPathEditing() {
        focusLossTimer.stop()
        pathField.focus = false
        editingPath = false
        selectedSuggestionIndex = -1
        suggestionsPopup.close()
        pathSuggestions.clear()
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
            basePath = AppState.currentPath || "/home/agony"
        } else if (raw.charAt(raw.length - 1) !== "/") {
            var slashIndex = raw.lastIndexOf("/")
            if (slashIndex >= 0) {
                basePath = slashIndex === 0 ? "/" : raw.slice(0, slashIndex)
                prefix = raw.slice(slashIndex + 1)
            } else {
                basePath = AppState.currentPath || "/home/agony"
                prefix = raw
            }
        }

        suggestionProcess.command = [
            "bash", "-lc",
            "base=\"$1\"; prefix=\"$2\"; " +
            "[ -d \"$base\" ] || exit 0; " +
            "find \"$base\" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | while IFS= read -r entry; do " +
            "name=${entry##*/}; " +
            "case \"$name\" in \"$prefix\"*) printf '%s\\n' \"$entry\" ;; esac; " +
            "done | head -n 12",
            "--", basePath, prefix
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
        Row {
            spacing: 2
            CommonComponents.NavButton {
                text: "‹"; tooltip: "Voltar"
                enabled: AppState.historyIdx > 0
                onClicked: AppState.goBack()
            }
            CommonComponents.NavButton {
                text: "›"; tooltip: "Avançar"
                enabled: AppState.historyIdx < AppState.history.length - 1
                onClicked: AppState.goForward()
            }
        }

        // ── Location Pill ───────────────────────────────────────
        Rectangle {
            id: locationPill
            Layout.fillWidth: true
            height: 32
            radius: 10
            color: editingPath
                ? Qt.rgba(1, 1, 1, 0.07)
                : pillMouse.containsMouse
                    ? Qt.rgba(1, 1, 1, 0.07)
                    : Qt.rgba(1, 1, 1, 0.04)
            border.color: editingPath
                ? Qt.rgba(0.25, 0.55, 1.0, 0.6)
                : Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 100 } }
            Behavior on border.color { ColorAnimation { duration: 100 } }

            // ── Breadcrumb row (display mode) ─────────────────
            Row {
                id: breadcrumbRow
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 12
                    rightMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                spacing: 0
                visible: !toolbar.editingPath
                clip: true

                Repeater {
                    model: AppState.breadcrumbParts

                    Row {
                        spacing: 0

                        Text {
                            visible: index > 0
                            text: " / "
                            color: Theme.textTer
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: {
                                var label = modelData.label
                                if (modelData.path === "/home/agony") return "Início"
                                if (label === "/") return "/"
                                return label
                            }
                            color: index === AppState.breadcrumbParts.length - 1
                                ? Theme.text
                                : Theme.textSec
                            font {
                                pixelSize: 13
                                weight: index === AppState.breadcrumbParts.length - 1
                                    ? Font.DemiBold : Font.Normal
                            }
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (index < AppState.breadcrumbParts.length - 1)
                                        AppState.navigateTo(modelData.path)
                                    else
                                        toolbar.startPathEditing(AppState.currentPath)
                                }
                            }
                        }
                    }
                }
            }

            // ── Edit field ────────────────────────────────────
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                spacing: 4
                visible: toolbar.editingPath

                TextField {
                    id: pathField
                    Layout.fillWidth: true
                    height: parent.height
                    color: Theme.text
                    font.pixelSize: 13
                    selectByMouse: true
                    background: null
                    placeholderText: "/home/agony"
                    placeholderTextColor: Theme.textTer
                    verticalAlignment: TextInput.AlignVCenter
                    leftPadding: 2

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

                // × dismiss button
                Rectangle {
                    width: 20; height: 20; radius: 10
                    color: dismissHover.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    visible: toolbar.editingPath

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: Theme.textSec
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: dismissHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: toolbar.stopPathEditing()
                    }
                }
            }

            // Click on pill to start editing (display mode only)
            MouseArea {
                id: pillMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !toolbar.editingPath
                cursorShape: Qt.IBeamCursor
                onClicked: toolbar.startPathEditing(AppState.currentPath)
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
                    settingsMenu.x = toolbar.width - settingsMenu.width - 10
                    settingsMenu.y = toolbar.height + 2
                    settingsMenu.open()
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
                        font { pixelSize: 12; weight: Font.Medium }

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

    // ── Settings panel popup ──────────────────────────────────────
    Popup {
        id: settingsMenu
        modal: false
        focus: true
        padding: 6
        width: 230
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        background: Rectangle {
            radius: 12
            color: Qt.rgba(0.14, 0.14, 0.16, 0.97)
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1
        }

        contentItem: Column {
            spacing: 2

            // Section label
            Text {
                text: "VISUALIZAÇÃO"
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
                label: "Painel de Preview"
                icon: AppState.showPreview ? "◉" : "○"
                checked: AppState.showPreview
                onTriggered: AppState.showPreview = !AppState.showPreview
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07); topPadding: 2 }

            Text {
                text: "ORDENAÇÃO"
                color: Theme.textTer
                font { pixelSize: 9; weight: Font.DemiBold; letterSpacing: 1.0 }
                leftPadding: 10
                topPadding: 4
                bottomPadding: 2
            }

            Repeater {
                model: [
                    { label: "Por Nome",         field: "name" },
                    { label: "Por Data",          field: "date" },
                    { label: "Por Tamanho",       field: "size" },
                    { label: "Por Tipo",          field: "kind" }
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
                text: "OPÇÕES"
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
                label: "Mostrar Ocultos"
                icon: AppState.showHidden ? "◉" : "○"
                checked: AppState.showHidden
                onTriggered: AppState.showHidden = !AppState.showHidden
            }

            SettingsAction {
                label: "Pastas Primeiro"
                icon: AppState.foldersFirst ? "◉" : "○"
                checked: AppState.foldersFirst
                onTriggered: AppState.foldersFirst = !AppState.foldersFirst
            }

            SettingsAction {
                label: "Resetar Zoom"
                icon: "⊙"
                enabled: AppState.zoomLevel !== 1.0
                onTriggered: AppState.resetZoom()
            }

            Item { height: 4; width: 1 }
        }
    }

    // ── Timer: focus-loss debounce ────────────────────────────────
    Timer {
        id: focusLossTimer
        interval: 100
        repeat: false
        onTriggered: {
            // Only close if the suggestions popup isn't being interacted with
            if (toolbar.editingPath && !pathField.activeFocus && !suggestionsPopup.activeFocus)
                toolbar.stopPathEditing()
        }
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
                pathSuggestions.clear()
                toolbar.selectedSuggestionIndex = -1
                var lines = text.split("\n")
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
        property bool enabled: true
        signal triggered()

        width: settingsMenu.width - settingsMenu.leftPadding - settingsMenu.rightPadding
        height: 30

        Rectangle {
            anchors.fill: parent
            radius: 7
            color: sa_mouse.containsMouse && saRoot.enabled
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
                color: saRoot.enabled ? Theme.text : Theme.textTer
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: sa_mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: saRoot.enabled
            cursorShape: saRoot.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: saRoot.triggered()
        }
    }
}
