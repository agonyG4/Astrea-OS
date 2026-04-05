import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.impl 2.15
import QtQuick.Layouts 1.15
import Quickshell.Io
import "../.."
import "../common" as CommonComponents

Rectangle {
    id: toolbar
    height: 44
    color: Theme.toolbar
    property bool editingPath: false
    property int selectedSuggestionIndex: -1

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
        pathField.deselect()
        pathField.cursorPosition = pathField.text.length
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
        if (pathSuggestions.count === 0)
            return

        if (!suggestionsPopup.visible)
            suggestionsPopup.open()

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

    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        spacing: 6

        // ── Navigation Buttons ──────────────────────────────
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

        // ── Main Location Pill ──────────────────────────────
        Rectangle {
            id: locationPill
            Layout.fillWidth: true
            height: 32
            radius: 16
            color: editingPath ? Theme.panel : Qt.rgba(1, 1, 1, 0.05)
            border.color: editingPath ? Theme.selected : Theme.border
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: if (!toolbar.editingPath) toolbar.startPathEditing(AppState.currentPath)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8
                visible: !toolbar.editingPath

                IconImage {
                    name: "go-home"
                    width: 14; height: 14
                    opacity: 0.8
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: {
                        var p = AppState.currentPath;
                        if (p === "/home/agony") return "Pasta pessoal";
                        if (p === "/") return "Sistema";
                        return p.split("/").pop() || "Raiz";
                    }
                    color: Theme.text
                    font { pixelSize: 13; weight: Font.Medium }
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: "•••"
                    color: Theme.textTer
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignVCenter
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: settingsButton.onClicked()
                    }
                }
            }
            
            TextField {
                id: pathField
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                visible: toolbar.editingPath
                color: Theme.text
                font.pixelSize: 13
                selectByMouse: true
                background: null
                placeholderText: "/home/agony"
                verticalAlignment: TextInput.AlignVCenter

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
                            text = pathSuggestions.get(toolbar.selectedSuggestionIndex).path
                            cursorPosition = text.length
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
        }

        // ── Settings Button (Hidden but functional via pill) ──
        CommonComponents.NavButton {
            id: settingsButton
            visible: false
            onClicked: {
                settingsMenu.x = toolbar.width - settingsMenu.width - 10
                settingsMenu.y = toolbar.height + 4
                settingsMenu.open()
            }
        }
    }

    Popup {
        id: suggestionsPopup
        modal: false
        focus: false
        padding: 6
        width: locationPill.width
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        x: {
            var point = locationPill.mapToItem(toolbar, 0, 0)
            return point.x
        }
        y: toolbar.height + 2
        visible: toolbar.editingPath && pathSuggestions.count > 0

        background: Rectangle {
            radius: 10
            color: Theme.panel
            border.color: Theme.border
            border.width: 1
        }

        contentItem: ListView {
            id: suggestionsList
            implicitHeight: Math.min(contentHeight, 260)
            model: pathSuggestions
            clip: true
            keyNavigationWraps: true

            delegate: Rectangle {
                width: suggestionsList.width
                height: 28
                color: index === toolbar.selectedSuggestionIndex ? Theme.hover : "transparent"
                radius: 6

                Text {
                    anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: model.path
                    color: Theme.text
                    font.pixelSize: 12
                    elide: Text.ElideMiddle
                }

                MouseArea {
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

            Keys.onReturnPressed: {
                if (toolbar.selectedSuggestionIndex >= 0) {
                    pathField.text = pathSuggestions.get(toolbar.selectedSuggestionIndex).path
                    toolbar.commitPathEditing()
                }
            }
            Keys.onEscapePressed: {
                pathField.forceActiveFocus()
                toolbar.stopPathEditing()
            }
        }
    }

    Timer {
        id: focusLossTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (toolbar.editingPath && !pathField.activeFocus)
                toolbar.stopPathEditing()
        }
    }

    Popup {
        id: settingsMenu
        modal: false
        focus: true
        padding: 8
        width: 220
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        background: Rectangle {
            radius: 10
            color: Theme.panel
            border.color: Theme.border
            border.width: 1
        }

        contentItem: Column {
            spacing: 4

            Item {
                width: parent.width
                height: 30

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: viewMouse.containsMouse ? Theme.hover : "transparent"
                }

                Text {
                    anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: AppState.viewMode === "list" ? "View: List" : "View: Icons"
                    color: Theme.text
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: viewMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        AppState.viewMode = AppState.viewMode === "list" ? "icon" : "list"
                        settingsMenu.close()
                    }
                }
            }

            Item {
                width: parent.width
                height: 30

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: previewMouse.containsMouse ? Theme.hover : "transparent"
                }

                Text {
                    anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: (AppState.showPreview ? "✓ " : "") + "Show Preview Panel"
                    color: Theme.text
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: previewMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AppState.showPreview = !AppState.showPreview
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            Repeater {
                model: [
                    { text: "Sort by Name", field: "name" },
                    { text: "Sort by Date Modified", field: "date" },
                    { text: "Sort by Size", field: "size" },
                    { text: "Sort by Type", field: "kind" }
                ]

                delegate: Item {
                    width: settingsMenu.width - settingsMenu.leftPadding - settingsMenu.rightPadding
                    height: 30

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: sortMouse.containsMouse ? Theme.hover : "transparent"
                    }

                    Text {
                        anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: modelData.text + (AppState.sortField === modelData.field ? (AppState.sortAsc ? "  ↑" : "  ↓") : "")
                        color: Theme.text
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: sortMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: toolbar.setSortField(modelData.field)
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            Repeater {
                model: [
                    { text: AppState.sortAsc ? "Order: Ascending" : "Order: Descending", action: function() { AppState.sortAsc = !AppState.sortAsc } },
                    { text: (AppState.showHidden ? "✓ " : "") + "Show Hidden Files", action: function() { AppState.showHidden = !AppState.showHidden } },
                    { text: (AppState.foldersFirst ? "✓ " : "") + "Folders First", action: function() { AppState.foldersFirst = !AppState.foldersFirst } },
                    { text: "Reset Zoom", action: function() { AppState.resetZoom() }, disabled: AppState.zoomLevel === 1.0 }
                ]

                delegate: Item {
                    width: settingsMenu.width - settingsMenu.leftPadding - settingsMenu.rightPadding
                    height: 30
                    enabled: !modelData.disabled

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: actionMouse.containsMouse && parent.enabled ? Theme.hover : "transparent"
                    }

                    Text {
                        anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: modelData.text
                        color: parent.enabled ? Theme.text : Theme.textTer
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        enabled: parent.enabled
                        hoverEnabled: true
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: modelData.action()
                    }
                }
            }
        }
    }

    ListModel {
        id: pathSuggestions
    }

    Process {
        id: suggestionProcess
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                pathSuggestions.clear()
                selectedSuggestionIndex = -1
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var entry = lines[i].trim()
                    if (entry)
                        pathSuggestions.append({ path: entry })
                }
                if (toolbar.editingPath && pathSuggestions.count > 0) {
                    selectedSuggestionIndex = 0
                    suggestionsList.currentIndex = 0
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

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
}
