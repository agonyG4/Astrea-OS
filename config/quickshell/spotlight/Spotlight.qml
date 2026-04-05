import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../bar"

ShellRoot {
    id: root

    HyprlandFocusGrab {
        id: focusGrab
        active: spotlight.open
        onActiveChanged: if (!active && spotlight.open) spotlight.close()
    }

    GlobalShortcut {
        name: "spotlight_toggle"
        onPressed: spotlight.toggle()
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            WlrLayershell.namespace: "spotlight"

            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true

            color: "transparent"
            visible: spotlight.open && modelData === Quickshell.screens[0]

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            MouseArea {
                anchors.fill: parent
                onClicked: spotlight.close()
            }

            Rectangle {
                id: panel
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.25

                width: 600
                height: searchInput.text.length > 0 ? Math.min(contentCol.implicitHeight + 28, 450) : 58
                radius: 24

                color: '#80343434'
                border.color: "#33FFFFFF"
                border.width: 1
                clip: true

                scale: spotlight.open ? 1.0 : 0.98
                opacity: spotlight.open ? 1.0 : 0.0

                Behavior on height  { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 120 } }

                ColumnLayout {
                    id: contentCol
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        spacing: 12

                        Text {
                            text: "🔍"
                            font.pixelSize: 18
                            opacity: 0.6
                            Layout.leftMargin: 8
                            Layout.alignment: Qt.AlignVCenter
                        }

                        TextField {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter

                            placeholderText: "Spotlight Search"
                            font.family: Theme.fontFamily
                            font.pixelSize: 22
                            font.weight: Font.Light
                            color: "white"
                            placeholderTextColor: "#66FFFFFF"
                            background: null

                            topPadding: 0
                            bottomPadding: 0
                            leftPadding: 0

                            verticalAlignment: TextInput.AlignVCenter

                            onTextChanged: spotlight.updateResults(text)

                            Keys.onEscapePressed: spotlight.close()
                            Keys.onReturnPressed: if (resultList.count > 0) spotlight.launch(resultList.currentIndex)
                            Keys.onDownPressed: if (resultList.count > 0) resultList.currentIndex = (resultList.currentIndex + 1) % resultList.count
                            Keys.onUpPressed: if (resultList.count > 0) resultList.currentIndex = (resultList.currentIndex - 1 + resultList.count) % resultList.count

                            Component.onCompleted: forceActiveFocus()
                            onVisibleChanged: if (visible) { forceActiveFocus(); text = "" }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: searchInput.text.length > 0 && resultList.count > 0
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1; color: "#15FFFFFF"
                            Layout.topMargin: 12; Layout.bottomMargin: 8
                        }

                        ListView {
                            id: resultList
                            Layout.fillWidth: true
                            implicitHeight: Math.min(count, 6) * 50
                            model: spotlight.results
                            currentIndex: 0
                            interactive: false

                            delegate: Rectangle {
                                width: resultList.width
                                height: 50
                                radius: 7
                                color: resultList.currentIndex === index ? "#007AFF" : "transparent"

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                    spacing: 15

                                    Image {
                                        id: appIcon
                                        sourceSize: Qt.size(30, 30)
                                        source: modelData && modelData.icon ? "image://icon/" + modelData.icon : ""
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "#22FFFFFF"; radius: 6
                                            visible: appIcon.status !== Image.Ready
                                        }
                                    }

                                    Text {
                                        text: modelData ? modelData.name : ""
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 17
                                        color: "white"
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: resultList.currentIndex = index
                                    onClicked: spotlight.launch(index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    QtObject {
        id: spotlight
        property bool open: false
        property var results: []

        function toggle() { if (open) close(); else open = true }

        function close() {
            open = false
            results = []
        }

        function updateResults(query) {
            const q = query.trim().toLowerCase()
            if (q === "") { results = []; return }

            let items = []
            if (typeof DesktopEntries !== "undefined") {
                let apps = DesktopEntries.applications.values
                let searchTerms = q.split(/[\s-]+/)
                let seenNames = new Set()

                for (let entry of apps) {
                    if (!entry || entry.noDisplay) continue
                    
                    let searchableName = (entry.name || "").toLowerCase()
                    if (seenNames.has(searchableName)) continue

                    let searchableExec = (entry.exec || entry.execString || "").toLowerCase()

                    let matches = searchTerms.every(term =>
                        searchableName.includes(term) || searchableExec.includes(term)
                    )

                    if (matches) {
                        items.push(entry)
                        seenNames.add(searchableName)
                    }
                    if (items.length >= 6) break
                }
            }
            results = items
        }

        function launch(index) {
            if (index < 0 || index >= results.length) return
            let entry = results[index]

            // Fecha primeiro para liberar o foco do Wayland
            close()

            // entry.execute() é a forma correta — o Quickshell lança o app
            // completamente desacoplado, como um processo independente,
            // sem herdar nada do Quickshell
            Qt.callLater(() => {
                entry.execute()
            })
        }
    }
}