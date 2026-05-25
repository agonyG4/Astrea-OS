import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import Quickshell.Io
import "../.."
import "../../QuickshellComponents" as ShellComponents

Item {
    id: root
    anchors.fill: parent
    z: 1200
    visible: openWithWindow.visible

    property string targetPath: ""
    property string targetName: ""
    property string mimeText: ""
    property string errorText: ""
    property bool loading: false
    property bool targetIsDirectory: false
    property string pendingDefaultDesktopFile: ""

    function openAt(x, y, path) {
        openForPath(path)
    }

    function openForPath(path) {
        targetPath = path || ""
        targetName = targetPath.split("/").pop()
        mimeText = ""
        errorText = ""
        targetIsDirectory = false
        pendingDefaultDesktopFile = ""
        appsModel.clear()
        loading = true
        openWithWindow.show()
        openWithWindow.raise()
        openWithWindow.requestActivate()

        appsProc.command = ["python3", AppState.helperPath, "open-with-apps", targetPath]
        appsProc.running = false
        appsProc.running = true
    }

    function closeMenu() {
        openWithWindow.hide()
    }

    function setDefaultForApp(desktopFile) {
        if (!desktopFile || setDefaultProc.running)
            return
        pendingDefaultDesktopFile = desktopFile
        errorText = ""
        setDefaultProc.command = [
            "python3",
            AppState.helperPath,
            "set-default-open-with",
            root.targetPath,
            desktopFile
        ]
        setDefaultProc.running = false
        setDefaultProc.running = true
    }

    ListModel {
        id: appsModel
        dynamicRoles: true
    }

    Window {
        id: openWithWindow
        title: root.targetIsDirectory ? "Abrir pasta" : "Abrir com"
        width: 430
        height: Math.min(720, Math.max(520, 220 + appsList.contentHeight))
        color: Theme.bg
        flags: Qt.Window | Qt.Dialog

        onClosing: function(close) {
            close.accepted = false
            hide()
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            border.width: 1
            border.color: Theme.border

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 52
                        Layout.preferredHeight: 52
                        radius: 10
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        Text {
                            anchors.centerIn: parent
                            text: "↗"
                            color: Theme.accent
                            font.pixelSize: 26
                            font.weight: Font.Medium
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: root.targetIsDirectory ? "Abrir pasta" : "Abrir com"
                            color: Theme.text
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.targetName || root.targetPath
                            color: Theme.textSec
                            font.pixelSize: 13
                            elide: Text.ElideMiddle
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.border
                }

                Text {
                    Layout.fillWidth: true
                    text: root.loading
                        ? "Procurando apps compatíveis..."
                        : root.errorText !== ""
                            ? root.errorText
                            : appsModel.count === 0
                                ? "Nenhum app compatível encontrado para este arquivo."
                                : "Escolha um aplicativo para abrir " + (root.targetName || "este item")
                    color: root.errorText !== "" ? "#ff6b6b" : Theme.textSec
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }

                ListView {
                    id: appsList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: appsModel

                    delegate: Rectangle {
                        width: appsList.width
                        height: model.item_type === "section" ? 28 : 68
                        radius: model.item_type === "section" ? 0 : 8
                        color: model.item_type === "section"
                            ? "transparent"
                            : appMouse.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.09)
                                : model.is_default
                                    ? Qt.rgba(0.25, 0.55, 1.0, 0.12)
                                    : Qt.rgba(1, 1, 1, 0.045)
                        border.width: model.item_type === "section" ? 0 : 1
                        border.color: model.item_type === "section"
                            ? "transparent"
                            : appMouse.containsMouse
                                ? Qt.rgba(0.25, 0.55, 1.0, 0.36)
                                : Qt.rgba(1, 1, 1, 0.075)

                        Behavior on color { ColorAnimation { duration: 80 } }
                        Behavior on border.color { ColorAnimation { duration: 80 } }

                        Text {
                            visible: model.item_type === "section"
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            text: model.title || ""
                            color: Theme.text
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: appMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: model.item_type === "app" && !launchProc.running && !setDefaultProc.running
                            onClicked: {
                                launchProc.command = [
                                    "python3",
                                    AppState.helperPath,
                                    "launch-open-with",
                                    root.targetPath,
                                    model.desktop_file
                                ]
                                launchProc.running = false
                                launchProc.running = true
                                root.closeMenu()
                            }
                        }

                        RowLayout {
                            visible: model.item_type === "app"
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 14
                            spacing: 14

                            Rectangle {
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 44
                                radius: 8
                                color: Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.08)

                                ShellComponents.AppIcon {
                                    anchors.fill: parent
                                    anchors.margins: 7
                                    entry: ({
                                        "name": model.name,
                                        "icon": model.icon,
                                        "desktopId": model.desktop_id
                                    })
                                    fallbackRadius: 6
                                    fallbackColor: "#22FFFFFF"
                                    fallbackTextColor: Theme.text
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: model.name
                                    color: Theme.text
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: model.desktop_id
                                    color: Theme.textTer
                                    font.pixelSize: 11
                                    elide: Text.ElideMiddle
                                }
                            }

                            Rectangle {
                                visible: model.item_type === "app" && !model.is_default
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: setDefaultText.implicitWidth + 22
                                radius: 8
                                color: Qt.rgba(1, 1, 1, 0.06)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.12)

                                Text {
                                    id: setDefaultText
                                    anchors.centerIn: parent
                                    text: "Definir padrão"
                                    color: Theme.textSec
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !setDefaultProc.running
                                    onClicked: root.setDefaultForApp(model.desktop_file)
                                }
                            }

                            Rectangle {
                                visible: model.item_type === "app" && model.is_default
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: defaultText.implicitWidth + 20
                                radius: 8
                                color: Qt.rgba(0.25, 0.55, 1.0, 0.16)
                                border.width: 1
                                border.color: Qt.rgba(0.25, 0.55, 1.0, 0.28)

                                Text {
                                    id: defaultText
                                    anchors.centerIn: parent
                                    text: "padrão"
                                    color: "#9fd0ff"
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 112
                        Layout.preferredHeight: 38
                        radius: 8
                        color: cancelMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        Text {
                            anchors.centerIn: parent
                            text: "Cancelar"
                            color: Theme.text
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: cancelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeMenu()
                        }
                    }
                }
            }
        }
    }

    Process {
        id: appsProc
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                appsModel.clear()
                try {
                    var payload = JSON.parse(text || "{}")
                    if (payload.ok === false) {
                        root.errorText = payload.error || "Nao foi possivel listar apps"
                        return
                    }
                    root.mimeText = payload.mime || ""
                    root.targetIsDirectory = payload.is_directory === true
                    var sections = payload.sections || []
                    var apps = payload.apps || []
                    if (apps.length > 0) {
                        appsModel.append({ "item_type": "section", "title": "Aplicativos recomendados" })
                        for (var i = 0; i < apps.length; i++) {
                            apps[i].item_type = "app"
                            appsModel.append(apps[i])
                        }
                    }
                } catch (error) {
                    root.errorText = "Resposta invalida"
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") root.errorText = text.trim()
        }
        onExited: function(exitCode) {
            root.loading = false
            if (exitCode !== 0 && root.errorText === "")
                root.errorText = "Nao foi possivel listar apps"
        }
    }

    Process {
        id: launchProc
        command: []
        running: false
    }

    Process {
        id: setDefaultProc
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var payload = JSON.parse(text || "{}")
                    if (payload.ok === false) {
                        root.errorText = payload.error || "Nao foi possivel alterar o app padrao"
                        return
                    }
                } catch (error) {
                    root.errorText = "Resposta invalida"
                    return
                }
                root.openForPath(root.targetPath)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") root.errorText = text.trim()
        }
        onExited: function(exitCode) {
            if (exitCode !== 0 && root.errorText === "")
                root.errorText = "Nao foi possivel alterar o app padrao"
        }
    }
}
