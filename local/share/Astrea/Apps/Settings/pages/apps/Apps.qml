import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../AstreaComponents"

ScrollPage {
    id: root

    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color cardBg: Theme.cardBg
    readonly property color cardBorder: Theme.cardBorder
    readonly property color accent: Theme.accent
    readonly property color popupBg: Theme.popupBg
    readonly property color errorColor: Theme.errorColor

    readonly property string scriptPath: (Quickshell.env("HOME") || "") + "/.local/share/Astrea/Core/bridge/apps/manager.py"

    property bool loading: true
    property string errorMessage: ""
    property string searchText: ""
    property string _appsBuf: ""
    property var appsData: ({ apps: [], total: 0 })

    readonly property var filteredApps: appsData.apps.filter(function(app) {
        const q = root.searchText.trim().toLowerCase()
        if (q === "")
            return true
        const hay = [
            app.name || "",
            app.comment || "",
            app.id || ""
        ].join(" ").toLowerCase()
        return hay.indexOf(q) !== -1
    })

    function reloadApps() {
        if (appsProc.running)
            return
        root.loading = true
        root.errorMessage = ""
        root._appsBuf = ""
        appsProc.running = true
    }

    Component.onCompleted: reloadApps()

    Process {
        id: appsProc
        command: ["python3", root.scriptPath]
        running: false
        stdout: SplitParser {
            onRead: line => root._appsBuf += line
        }
        onExited: code => {
            root.loading = false
            if (code !== 0) {
                root.errorMessage = "Não foi possível ler os apps instalados"
                return
            }

            try {
                root.appsData = JSON.parse(root._appsBuf || "{}")
            } catch (e) {
                root.errorMessage = "Erro lendo lista de apps: " + e
            }
            root._appsBuf = ""
        }
    }

    component AppRow: Item {
        id: rowItem
        required property var modelData
        required property int index
        required property bool isLast

        implicitWidth: parent ? parent.width : 200
        readonly property bool hasComment: !!(modelData.comment && modelData.comment !== "")
        implicitHeight: hasComment ? 68 : 56

        Rectangle {
            anchors {
                fill: parent
                leftMargin: 8
                rightMargin: 8
                topMargin: 6
                bottomMargin: 6
            }
            radius: 12
            color: rowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
            border.width: rowArea.containsMouse ? 1 : 0
            border.color: Qt.rgba(1, 1, 1, 0.04)
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        Item {
            id: rowContent
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 22
                rightMargin: 22
                verticalCenter: parent.verticalCenter
            }
            height: parent.hasComment ? 42 : 36

            Rectangle {
                id: iconBox
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.04)
                clip: true

                Image {
                    id: themedIconImage
                    anchors.fill: parent
                    anchors.margins: 7
                    source: modelData.icon ? "image://icon/" + modelData.icon : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: false
                    cache: true
                    mipmap: true
                    visible: status === Image.Ready
                }

                Image {
                    id: iconImage
                    anchors.fill: parent
                    anchors.margins: 7
                    source: (modelData.icon_path && (modelData.icon_path.startsWith("/") || modelData.icon_path.startsWith("file://")))
                        ? (modelData.icon_path.startsWith("file://") ? modelData.icon_path : "file://" + modelData.icon_path)
                        : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    visible: !themedIconImage.visible && status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    text: (modelData.name || "?").slice(0, 1).toUpperCase()
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    visible: !themedIconImage.visible && !iconImage.visible
                }
            }

            Column {
                anchors {
                    left: iconBox.right
                    leftMargin: 14
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                spacing: rowItem.hasComment ? 2 : 0

                Text {
                    width: parent.width
                    text: modelData.name || modelData.id
                    color: root.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    visible: rowItem.hasComment
                    width: parent.width
                    text: modelData.comment || ""
                    color: root.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            visible: !isLast
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: 22
                rightMargin: 22
            }
            height: 1
            color: root.cardBorder
        }

        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
        }
    }

    Item {
        Layout.alignment: Qt.AlignHCenter
        visible: root.loading
        width: 48
        height: 48
        BusyIndicator {
            anchors.fill: parent
            running: root.loading
        }
    }

    ColumnLayout {
        width: parent.width
        spacing: 0
        visible: !root.loading

        SectionHeader {
            text: "APPS"
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 24
            radius: 12
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder
            implicitHeight: topCol.implicitHeight + 32

            ColumnLayout {
                id: topCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Installed applications"
                        color: root.textPrimary
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: root.filteredApps.length + " apps visíveis de " + appsData.total + " instalados"
                        color: root.textSecondary
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: root.cardBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: "⌕"
                            color: root.textSecondary
                            font.pixelSize: 14
                        }

                        TextField {
                            Layout.fillWidth: true
                            text: root.searchText
                            placeholderText: "Buscar por nome, comentário ou desktop id"
                            color: root.textPrimary
                            placeholderTextColor: root.textSecondary
                            background: Item {}
                            onTextChanged: root.searchText = text
                        }
                    }
                }

                Text {
                    visible: root.errorMessage !== ""
                    text: root.errorMessage
                    color: root.errorColor
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 28
            radius: 12
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder
            implicitHeight: root.filteredApps.length === 0 ? 96 : appsCol.implicitHeight + 10

            Text {
                anchors.centerIn: parent
                visible: root.filteredApps.length === 0
                text: root.searchText.trim() === ""
                    ? "Nenhum app encontrado"
                    : "Nenhum app corresponde à busca"
                color: root.textSecondary
                font.pixelSize: 12
            }

            ColumnLayout {
                id: appsCol
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    topMargin: 4
                    bottom: parent.bottom
                    bottomMargin: 6
                }
                spacing: 0
                visible: root.filteredApps.length > 0

                Repeater {
                    model: root.filteredApps
                    delegate: AppRow {
                        isLast: index === root.filteredApps.length - 1
                    }
                }
            }
        }
    }
}
