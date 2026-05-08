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
    property string _actionBuf: ""
    property string actionMessage: ""
    property bool actionError: false
    property string expandedAppId: ""
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

    function appIdentifier(app) {
        return app ? (app.desktop_file || app.id || "") : ""
    }

    function isProtectedApp(app) {
        if (!app)
            return false
        return app.protected === true || (app.id || "") === "astrea-settings.desktop"
    }

    function toggleExpanded(app) {
        const id = root.appIdentifier(app)
        root.expandedAppId = root.expandedAppId === id ? "" : id
    }

    function runAction(action, app) {
        if (!app || actionProc.running)
            return

        root.actionMessage = ""
        root.actionError = false
        root._actionBuf = ""
        actionProc.currentAction = action
        actionProc.command = ["python3", root.scriptPath, action, root.appIdentifier(app)]
        actionProc.running = true
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

    Process {
        id: actionProc
        property string currentAction: ""
        command: []
        running: false
        stdout: SplitParser {
            onRead: line => root._actionBuf += line
        }
        onExited: code => {
            let payload = ({})
            try {
                payload = JSON.parse(root._actionBuf || "{}")
            } catch (e) {
                payload = ({ message: "Erro lendo resposta da ação: " + e })
            }

            root.actionError = code !== 0 || payload.ok === false
            root.actionMessage = payload.message || (root.actionError ? "Ação falhou" : "Ação concluída")
            root._actionBuf = ""

            if (!root.actionError && (currentAction === "create-shortcut" || currentAction === "uninstall"))
                root.reloadApps()
        }
    }

    component AppRow: Item {
        id: rowItem
        required property var modelData
        required property int index
        required property bool isLast

        implicitWidth: parent ? parent.width : 200
        readonly property bool hasComment: !!(modelData.comment && modelData.comment !== "")
        readonly property bool expanded: root.expandedAppId === root.appIdentifier(modelData)
        readonly property int baseHeight: hasComment ? 68 : 56
        implicitHeight: baseHeight + (expanded ? 124 : 0)

        Rectangle {
            anchors {
                fill: parent
                leftMargin: 8
                rightMargin: 8
                topMargin: 6
                bottomMargin: 6
            }
            radius: 12
            color: rowItem.expanded
                ? Qt.rgba(1, 1, 1, 0.055)
                : (rowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
            border.width: rowItem.expanded || rowArea.containsMouse ? 1 : 0
            border.color: rowItem.expanded ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35) : Qt.rgba(1, 1, 1, 0.04)
            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on border.color { ColorAnimation { duration: 180 } }
        }

        Item {
            id: rowContent
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 22
                rightMargin: 22
                top: parent.top
                topMargin: rowItem.hasComment ? 13 : 10
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
                    rightMargin: 28
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

            Text {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                text: rowItem.expanded ? "⌃" : "⌄"
                color: root.textSecondary
                font.pixelSize: 14
                rotation: rowItem.expanded ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
        }

        ColumnLayout {
            id: actionPanel
            anchors {
                left: parent.left
                right: parent.right
                top: rowContent.bottom
                leftMargin: 22
                rightMargin: 22
                topMargin: 12
            }
            spacing: 8
            visible: rowItem.expanded

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.cardBorder
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ActionChip {
                    Layout.fillWidth: true
                    label: "Criar atalho"
                    enabled: !actionProc.running
                    onTriggered: root.runAction("create-shortcut", rowItem.modelData)
                }

                ActionChip {
                    Layout.fillWidth: true
                    label: "Abrir local"
                    enabled: !actionProc.running
                    onTriggered: root.runAction("open-location", rowItem.modelData)
                }
            }

            ActionChip {
                Layout.fillWidth: true
                label: root.isProtectedApp(rowItem.modelData) ? "Settings protegido" : "Desinstalar"
                destructive: !root.isProtectedApp(rowItem.modelData)
                enabled: !root.isProtectedApp(rowItem.modelData) && !actionProc.running
                onTriggered: root.runAction("uninstall", rowItem.modelData)
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
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: rowItem.baseHeight
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: root.toggleExpanded(rowItem.modelData)
        }
    }

    component ActionChip: Rectangle {
        id: chip
        property string label: ""
        property bool destructive: false
        signal triggered()

        implicitHeight: 34
        radius: 9
        color: chip.enabled
            ? (chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.055))
            : Qt.rgba(1, 1, 1, 0.035)
        border.width: 1
        border.color: chip.enabled && chip.destructive
            ? Qt.rgba(root.errorColor.r, root.errorColor.g, root.errorColor.b, 0.38)
            : root.cardBorder
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            width: parent.width - 20
            text: chip.label
            color: !chip.enabled
                ? root.textSecondary
                : (chip.destructive ? root.errorColor : root.textPrimary)
            opacity: chip.enabled ? 1 : 0.55
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            enabled: chip.enabled
            hoverEnabled: true
            cursorShape: chip.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: chip.triggered()
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

                Text {
                    visible: root.actionMessage !== ""
                    text: root.actionMessage
                    color: root.actionError ? root.errorColor : root.textSecondary
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
