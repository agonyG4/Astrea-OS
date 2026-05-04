import Quickshell
import QtQuick
import QtQuick.Layouts
import "AstreaComponents" as Astrea
import "backend" as Backend
import "ui/panels" as Panels

FloatingWindow {
    id: root

    title: "DualSense"
    implicitWidth: 940
    implicitHeight: 680
    minimumSize: Qt.size(860, 560)
    visible: true
    color: "transparent"

    onVisibleChanged: {
        if (!visible)
            Qt.quit()
    }

    Backend.DualSenseBackend {
        id: gamepadBackend
    }

    Rectangle {
        anchors.fill: parent
        color: Astrea.Theme.windowBackground
        radius: 24
        border.width: 1
        border.color: Astrea.Theme.windowBorder

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 18

            // Header Premium (Estilo Weather) usando componentes do Astrea
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                spacing: 20

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "DualSense"
                        color: Astrea.Theme.textPrimary
                        font.family: Astrea.Theme.fontFamily
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: gamepadBackend.ready
                            ? (gamepadBackend.device !== "" ? gamepadBackend.device : "Controle conectado")
                            : (gamepadBackend.installed ? gamepadBackend.message : "dualsensectl não instalado")
                        color: Astrea.Theme.textSecondary
                        font.family: Astrea.Theme.fontFamily
                        font.pixelSize: Astrea.Theme.fontSizeNormal
                    }

                    RowLayout {
                        spacing: 12
                        
                        Rectangle {
                            Layout.preferredHeight: 24
                            Layout.preferredWidth: statusText.implicitWidth + 24
                            radius: 12
                            color: gamepadBackend.ready 
                                ? Qt.rgba(Astrea.Theme.successColor.r, Astrea.Theme.successColor.g, Astrea.Theme.successColor.b, 0.15)
                                : Qt.rgba(Astrea.Theme.warningColor.r, Astrea.Theme.warningColor.g, Astrea.Theme.warningColor.b, 0.15)
                            border.width: 1
                            border.color: gamepadBackend.ready ? Astrea.Theme.successColor : Astrea.Theme.warningColor

                            Text {
                                id: statusText
                                anchors.centerIn: parent
                                text: gamepadBackend.ready ? "Conectado" : "Desconectado"
                                color: parent.border.color
                                font.family: Astrea.Theme.fontFamily
                                font.pixelSize: Astrea.Theme.fontSizeSmall
                                font.weight: Font.Bold
                            }
                        }

                        Text {
                            text: gamepadBackend.battery !== "" ? "• " + gamepadBackend.battery : ""
                            color: Astrea.Theme.textSecondary
                            font.family: Astrea.Theme.monoFontFamily
                            font.pixelSize: Astrea.Theme.fontSizeSmall
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 20

                Flickable {
                    id: primaryFlick
                    Layout.preferredWidth: 380
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentHeight: primaryColumn.implicitHeight

                    ColumnLayout {
                        id: primaryColumn
                        width: primaryFlick.width - 10
                        spacing: 16

                        Panels.DevicePanel {
                            backend: gamepadBackend
                        }

                        Panels.LightbarPanel {
                            backend: gamepadBackend
                        }

                        Panels.LedPanel {
                            backend: gamepadBackend
                        }

                        Panels.MicrophonePanel {
                            backend: gamepadBackend
                        }
                    }
                }

                Flickable {
                    id: advancedFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentHeight: advancedColumn.implicitHeight

                    ColumnLayout {
                        id: advancedColumn
                        width: advancedFlick.width - 10
                        spacing: 16

                        Panels.AdaptiveTriggerPanel {
                            backend: gamepadBackend
                        }

                        Panels.AttenuationPanel {
                            backend: gamepadBackend
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(104, infoText.implicitHeight + 36)
                            radius: 18
                            color: Astrea.Theme.cardBg
                            border.width: 1
                            border.color: Astrea.Theme.cardBorder

                            Text {
                                id: infoText
                                anchors.fill: parent
                                anchors.margins: 18
                                text: gamepadBackend.info !== "" ? gamepadBackend.info : "Conecte um DualSense para ver detalhes de firmware."
                                color: Astrea.Theme.textSecondary
                                font.family: Astrea.Theme.monoFontFamily
                                font.pixelSize: Astrea.Theme.fontSizeSmall
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }

        // Feedback inferior sutil
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 32
            color: "transparent"
            visible: gamepadBackend.applying || gamepadBackend.lastError !== ""

            Text {
                anchors.centerIn: parent
                text: gamepadBackend.applying ? "Aplicando alterações..." : gamepadBackend.lastError
                color: gamepadBackend.lastError !== "" ? Astrea.Theme.errorColor : Astrea.Theme.textSecondary
                font.family: Astrea.Theme.fontFamily
                font.pixelSize: Astrea.Theme.fontSizeSmall
            }
        }
    }
}
