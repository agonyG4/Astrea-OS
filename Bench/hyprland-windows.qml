import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

ShellRoot {
    id: shellRoot

    property string jsonBuffer: ""

    FloatingWindow {
        id: root
        width: 520
        height: 480
        title: "Janelas do Hyprland"

        color: "#1e1e2e"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Cabeçalho
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Janelas abertas"
                    color: "#cdd6f4"
                    font.pixelSize: 16
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: windowModel.count + " janela(s)"
                    color: "#6c7086"
                    font.pixelSize: 12
                }

                Button {
                    text: "↻"
                    onClicked: {
                        shellRoot.jsonBuffer = ""
                        hyprctlProcess.running = true
                    }
                    ToolTip.text: "Atualizar"
                    ToolTip.visible: hovered

                    contentItem: Text {
                        text: parent.text
                        color: "#cdd6f4"
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 6
                        color: parent.hovered ? "#313244" : "#181825"
                        border.color: "#45475a"
                        border.width: 1
                    }

                    implicitWidth: 32
                    implicitHeight: 28
                }
            }

            // Separador
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#313244"
            }

            // Lista de janelas
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: windowList
                    model: windowModel
                    spacing: 6

                    delegate: Rectangle {
                        width: windowList.width
                        height: 64
                        radius: 8
                        color: mouseArea.containsMouse ? "#313244" : "#181825"
                        border.color: "#45475a"
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 100 } }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            // Ícone / workspace badge
                            Rectangle {
                                width: 36
                                height: 36
                                radius: 6
                                color: "#45475a"

                                Text {
                                    anchors.centerIn: parent
                                    text: model.workspace
                                    color: "#89b4fa"
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }

                            // Info da janela
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: model.title !== "" ? model.title : "(sem título)"
                                    color: "#cdd6f4"
                                    font.pixelSize: 13
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: model.appClass
                                    color: "#89dceb"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            // PID
                            Text {
                                text: "PID " + model.pid
                                color: "#6c7086"
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }

            // Rodapé
            Text {
                text: "via hyprctl clients"
                color: "#45475a"
                font.pixelSize: 10
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // Modelo de janelas
    ListModel {
        id: windowModel
    }

    // Processo que chama hyprctl clients -j
    Process {
        id: hyprctlProcess
        command: ["hyprctl", "clients", "-j"]
        running: true

        stdout: SplitParser {
            onRead: data => shellRoot.jsonBuffer += data
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                shellRoot.parseWindows(shellRoot.jsonBuffer)
            }
            shellRoot.jsonBuffer = ""
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            shellRoot.jsonBuffer = ""
            hyprctlProcess.running = true
        }
    }

    function parseWindows(json) {
        windowModel.clear()
        try {
            const clients = JSON.parse(json)
            for (const c of clients) {
                windowModel.append({
                    title:    c.title     ?? "",
                    appClass: c.class     ?? "?",
                    pid:      c.pid       ?? 0,
                    workspace: c.workspace?.id ?? "?"
                })
            }
        } catch (e) {
            console.error("Erro ao parsear JSON:", e, "\nJSON recebido:", json.substring(0, 200))
        }
    }
}
